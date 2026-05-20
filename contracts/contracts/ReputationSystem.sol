// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/Ownable.sol";

contract ReputationSystem is Ownable {
    address public predictionMarket;

    mapping(address => uint256) private reputation;

    constructor() Ownable(msg.sender) {}

    function setPredictionMarket(address _predictionMarket) external onlyOwner {
        require(_predictionMarket != address(0), "Bad market");
        predictionMarket = _predictionMarket;
    }

    function updateReputation(address user, bool correct) external {
        require(msg.sender == predictionMarket, "Only prediction market");
        if (correct) {
            reputation[user] += 1;
        }
    }

    function getReputation(address user) external view returns (uint256) {
        return reputation[user];
    }
}
