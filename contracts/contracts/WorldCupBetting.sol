// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IReputationSystem {
    function updateReputation(address user, bool correct) external;
    function getReputation(address user) external view returns (uint256);
}

/**
 * @title WorldCupBetting
 * @notice Assessment entrypoint: replace stub bodies with a full prediction market until
 *         `test/WorldCupBetting.assessment.test.ts` passes. Out-of-the-box, every call reverts so
 *         the assessment suite is red until you implement behavior.
 * @dev Optional behavioral reference in-repo: `PredictionMarket.sol` (do not modify that file
 *      unless your interview allows it). Instructors can run tests against the reference by
 *      setting `WORLD_CUP_ASSESSMENT_SOLUTION=1` when executing Hardhat (see `assessment/instructions.md`).
 */
contract WorldCupBetting is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    enum MarketStatus {
        Open,
        Closed,
        Resolved,
        Cancelled
    }

    uint256 private constant PLATFORM_FEE_BPS = 200;
    uint256 private constant BPS_DENOMINATOR = 10_000;
    uint256 private constant PRICE_PRECISION = 1e18;

    struct Market {
        uint256 id;
        string title;
        string description;
        string[] outcomes;
        uint256 resolutionTime;
        address arbitrator;
        address tokenAddress;
        MarketStatus status;
        uint256 winningOutcome;
        address creator;
        uint256 totalPool;
        mapping(uint256 => uint256) outcomePool;
    }

    struct Bet {
        uint256 id;
        uint256 marketId;
        address bettor;
        uint256 outcome;
        uint256 amount;
        uint256 shares;
        bool claimed;
        bool listed;
        uint256 listPrice;
    }

    IReputationSystem public reputationSystem;
    uint256 public marketCount;
    uint256 public betCount;

    mapping(uint256 => Market) private markets;
    mapping(uint256 => Bet) public bets;
    mapping(address => uint256[]) private userBets;
    mapping(uint256 => uint256[]) private marketBets;
    mapping(address => uint256) private availableFees;

    event MarketCreated(
        uint256 indexed marketId,
        string title,
        uint256 resolutionTime,
        address indexed arbitrator,
        address indexed tokenAddress
    );
    event BetPlaced(
        uint256 indexed betId,
        uint256 indexed marketId,
        address indexed bettor,
        uint256 outcome,
        uint256 amount,
        uint256 shares
    );
    event MarketResolved(uint256 indexed marketId, uint256 winningOutcome);
    event WinningsClaimed(
        uint256 indexed betId,
        address indexed bettor,
        bool correct,
        uint256 payout,
        uint256 fee
    );
    event PositionListed(uint256 indexed betId, address indexed seller, uint256 price);
    event ListingCancelled(uint256 indexed betId, address indexed seller);
    event PositionBought(uint256 indexed betId, address indexed seller, address indexed buyer, uint256 price);
    event FeesWithdrawn(address indexed tokenAddress, address indexed recipient, uint256 amount);

    constructor(address _reputationSystem) Ownable(msg.sender) {
        reputationSystem = IReputationSystem(_reputationSystem);
    }

    function createMarket(
        string memory _title,
        string memory _description,
        string[] memory _outcomes,
        uint256 _resolutionTime,
        address _arbitrator,
        address _tokenAddress
    ) external returns (uint256) {
        require(_outcomes.length >= 2, "Need outcomes");
        require(_resolutionTime > block.timestamp, "Bad resolution");
        require(_arbitrator != address(0), "Bad arbitrator");

        marketCount++;
        Market storage market = markets[marketCount];
        market.id = marketCount;
        market.title = _title;
        market.description = _description;
        market.resolutionTime = _resolutionTime;
        market.arbitrator = _arbitrator;
        market.tokenAddress = _tokenAddress;
        market.status = MarketStatus.Open;
        market.creator = msg.sender;

        for (uint256 i = 0; i < _outcomes.length; i++) {
            market.outcomes.push(_outcomes[i]);
        }

        emit MarketCreated(marketCount, _title, _resolutionTime, _arbitrator, _tokenAddress);

        return marketCount;
    }

    function placeBet(uint256 _marketId, uint256 _outcome, uint256 _amount, uint256 _minShares)
        external
        payable
        returns (uint256)
    {
        Market storage market = markets[_marketId];
        require(market.id != 0, "Invalid market");
        require(market.status == MarketStatus.Open && block.timestamp < market.resolutionTime, "Market closed");
        require(_outcome < market.outcomes.length, "Invalid outcome");
        require(_amount > 0, "Amount zero");

        uint256 shares = calculateShares(_marketId, _outcome, _amount);
        require(shares >= _minShares, "Slippage exceeded");

        if (market.tokenAddress == address(0)) {
            require(msg.value == _amount, "Bad ETH amount");
        } else {
            require(msg.value == 0, "No ETH");
            IERC20(market.tokenAddress).safeTransferFrom(msg.sender, address(this), _amount);
        }

        betCount++;
        bets[betCount] = Bet({
            id: betCount,
            marketId: _marketId,
            bettor: msg.sender,
            outcome: _outcome,
            amount: _amount,
            shares: shares,
            claimed: false,
            listed: false,
            listPrice: 0
        });

        market.totalPool += _amount;
        market.outcomePool[_outcome] += shares;
        userBets[msg.sender].push(betCount);
        marketBets[_marketId].push(betCount);

        emit BetPlaced(betCount, _marketId, msg.sender, _outcome, _amount, shares);

        return betCount;
    }

    function resolveMarket(uint256 _marketId, uint256 _winningOutcome) external {
        Market storage market = markets[_marketId];
        require(market.id != 0, "Invalid market");
        require(msg.sender == market.arbitrator, "Only arbitrator");
        require(block.timestamp >= market.resolutionTime, "Too early");
        require(market.status == MarketStatus.Open, "Market closed");
        require(_winningOutcome < market.outcomes.length, "Invalid outcome");

        market.winningOutcome = _winningOutcome;
        market.status = MarketStatus.Resolved;

        emit MarketResolved(_marketId, _winningOutcome);
    }

    function claimWinnings(uint256 _betId) external nonReentrant {
        Bet storage bet = bets[_betId];
        require(bet.id != 0, "Invalid bet");
        require(msg.sender == bet.bettor, "Only bettor");
        require(!bet.claimed, "Already claimed");

        Market storage market = markets[bet.marketId];
        require(market.status == MarketStatus.Resolved, "Not resolved");

        bet.claimed = true;
        bet.listed = false;

        bool correct = bet.outcome == market.winningOutcome;
        reputationSystem.updateReputation(bet.bettor, correct);

        if (!correct) {
            emit WinningsClaimed(_betId, bet.bettor, false, 0, 0);
            return;
        }

        uint256 winningPool = market.outcomePool[market.winningOutcome];
        if (winningPool == 0) {
            emit WinningsClaimed(_betId, bet.bettor, true, 0, 0);
            return;
        }

        uint256 grossPayout = (bet.shares * market.totalPool) / winningPool;
        uint256 fee = (grossPayout * PLATFORM_FEE_BPS) / BPS_DENOMINATOR;
        uint256 netPayout = grossPayout - fee;

        availableFees[market.tokenAddress] += fee;

        if (market.tokenAddress == address(0)) {
            (bool sent,) = bet.bettor.call{value: netPayout}("");
            require(sent, "ETH transfer failed");
        } else {
            IERC20(market.tokenAddress).safeTransfer(bet.bettor, netPayout);
        }

        emit WinningsClaimed(_betId, bet.bettor, true, netPayout, fee);
    }

    function listPosition(uint256 _betId, uint256 _price) external {
        Bet storage bet = bets[_betId];
        require(bet.id != 0, "Invalid bet");
        require(msg.sender == bet.bettor, "Only bettor");
        require(!bet.claimed, "Already claimed");
        require(_price > 0, "Price zero");

        bet.listed = true;
        bet.listPrice = _price;

        emit PositionListed(_betId, msg.sender, _price);
    }

    function cancelListing(uint256 _betId) external {
        Bet storage bet = bets[_betId];
        require(bet.id != 0, "Invalid bet");
        require(msg.sender == bet.bettor, "Only bettor");
        require(bet.listed, "Not listed");

        bet.listed = false;
        bet.listPrice = 0;

        emit ListingCancelled(_betId, msg.sender);
    }

    function buyPosition(uint256 _betId) external payable nonReentrant {
        Bet storage bet = bets[_betId];
        require(bet.id != 0, "Invalid bet");
        require(bet.listed, "Not listed");
        require(!bet.claimed, "Already claimed");
        require(msg.sender != bet.bettor, "Already owner");

        Market storage market = markets[bet.marketId];
        address seller = bet.bettor;
        uint256 price = bet.listPrice;

        bet.bettor = msg.sender;
        bet.listed = false;
        bet.listPrice = 0;

        _removeUserBet(seller, _betId);
        userBets[msg.sender].push(_betId);

        if (market.tokenAddress == address(0)) {
            require(msg.value == price, "Bad ETH amount");
            (bool sent,) = seller.call{value: price}("");
            require(sent, "ETH transfer failed");
        } else {
            require(msg.value == 0, "No ETH");
            IERC20(market.tokenAddress).safeTransferFrom(msg.sender, seller, price);
        }

        emit PositionBought(_betId, seller, msg.sender, price);
    }

    function withdrawFees(address _tokenAddress) external onlyOwner nonReentrant {
        uint256 amount = availableFees[_tokenAddress];
        require(amount > 0, "No fees");

        availableFees[_tokenAddress] = 0;

        if (_tokenAddress == address(0)) {
            (bool sent,) = owner().call{value: amount}("");
            require(sent, "ETH transfer failed");
        } else {
            IERC20(_tokenAddress).safeTransfer(owner(), amount);
        }

        emit FeesWithdrawn(_tokenAddress, owner(), amount);
    }

    function getAvailableFees(address _tokenAddress) external view returns (uint256) {
        return availableFees[_tokenAddress];
    }

    function calculateShares(uint256 _marketId, uint256 _outcome, uint256 _amount) public view returns (uint256) {
        Market storage market = markets[_marketId];
        require(market.id != 0, "Invalid market");
        require(_outcome < market.outcomes.length, "Invalid outcome");
        return _amount;
    }

    function getPrice(uint256 _marketId, uint256 _outcome) public view returns (uint256) {
        Market storage market = markets[_marketId];
        require(market.id != 0, "Invalid market");
        require(_outcome < market.outcomes.length, "Invalid outcome");

        if (market.totalPool == 0) {
            return PRICE_PRECISION / market.outcomes.length;
        }

        return (market.outcomePool[_outcome] * PRICE_PRECISION) / market.totalPool;
    }

    function getTotalPool(uint256 _marketId) public view returns (uint256) {
        Market storage market = markets[_marketId];
        require(market.id != 0, "Invalid market");
        return market.totalPool;
    }

    function getUserBets(address _user) external view returns (uint256[] memory) {
        return userBets[_user];
    }

    function getMarketBets(uint256 _marketId) external view returns (uint256[] memory) {
        require(markets[_marketId].id != 0, "Invalid market");
        return marketBets[_marketId];
    }

    function getMarket(uint256 _marketId)
        external
        view
        returns (
            uint256 id,
            string memory title,
            string memory description,
            string[] memory outcomes,
            uint256 resolutionTime,
            address arbitrator,
            address tokenAddress,
            MarketStatus status,
            uint256 winningOutcome,
            address creator
        )
    {
        Market storage market = markets[_marketId];
        require(market.id != 0, "Invalid market");

        return (
            market.id,
            market.title,
            market.description,
            market.outcomes,
            market.resolutionTime,
            market.arbitrator,
            market.tokenAddress,
            market.status,
            market.winningOutcome,
            market.creator
        );
    }

    function _removeUserBet(address _user, uint256 _betId) internal {
        uint256[] storage ids = userBets[_user];
        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] == _betId) {
                ids[i] = ids[ids.length - 1];
                ids.pop();
                return;
            }
        }
    }
}
