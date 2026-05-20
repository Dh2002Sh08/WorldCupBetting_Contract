# WorldCupBetting Contracts

Hardhat project for the World Cup on-chain betting assessment.

## What To Submit

Submit the contract project/code unless the reviewer specifically asks for a deployed contract address.

If they ask for a deployed address, use:

- Network: `OP Sepolia`
- Chain ID: `11155420`
- WorldCupBetting: `0x2A7981398a9Afa94F999d8e8E817b31Ef724BA63`
- Explorer: `https://testnet-explorer.optimism.io/address/0x2A7981398a9Afa94F999d8e8E817b31Ef724BA63`
- ReputationSystem: `0x4DAC1A51ef037DE8d894dc5C6614DfC9c98a339F`

The same public deployment details are saved in:

- `deployments/opSepolia.json`
- `deployments/OP_SEPOLIA.md`

Do not submit `.env`, private keys, seed phrases, or wallet screenshots.

## Setup

From the project folder:

```bash
cd contracts
npm install --legacy-peer-deps
```

## Run Checks

Run these before submission:

```bash
npm run typecheck
npm run compile
npm run test:assessment
```

Expected test result:

```text
9 passing
```

## Local Deployment

This deploys to Hardhat's temporary in-memory network. It is useful for checking that the deploy script works, but the addresses reset each run.

```bash
npm run deploy
```

The script deploys and links:

1. `ReputationSystem`
2. `WorldCupBetting`

## Existing OP Sepolia Deployment

The current public deployment is on OP Sepolia:

```text
WorldCupBetting: 0x2A7981398a9Afa94F999d8e8E817b31Ef724BA63
ReputationSystem: 0x4DAC1A51ef037DE8d894dc5C6614DfC9c98a339F
```

Explorer links:

- WorldCupBetting: https://testnet-explorer.optimism.io/address/0x2A7981398a9Afa94F999d8e8E817b31Ef724BA63
- ReputationSystem: https://testnet-explorer.optimism.io/address/0x4DAC1A51ef037DE8d894dc5C6614DfC9c98a339F

You can find the saved deployment files here:

```text
contracts/deployments/opSepolia.json
contracts/deployments/OP_SEPOLIA.md
```

## Sepolia Deployment

Only use this if you want to deploy to Ethereum Sepolia.

Create `.env` in the repo root or inside `contracts`, then set:

```bash
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
PRIVATE_KEY=0xYOUR_DEPLOYER_PRIVATE_KEY
```

Then run:

```bash
npm run deploy:sepolia
```

## OP Sepolia Deployment

Only use this if you want to deploy a fresh copy to OP Sepolia.

Create `.env` in the repo root or inside `contracts`, then set:

```bash
OP_SEPOLIA_RPC_URL=https://your-op-sepolia-rpc
PRIVATE_KEY=0xYOUR_DEPLOYER_PRIVATE_KEY
```

The deployer wallet needs OP Sepolia ETH for gas. Then run:

```bash
npm run deploy:op-sepolia
```

Never commit a real private key.

## Main Files

- `contracts/WorldCupBetting.sol`: main assessment contract
- `contracts/ReputationSystem.sol`: simple reputation contract used by tests and deployment
- `contracts/MockERC20.sol`: mock token used by the ERC20 assessment test
- `test/WorldCupBetting.assessment.test.ts`: assessment scenario tests
- `scripts/deploy.ts`: deploy script
- `deployments/`: public deployed addresses only

## Contract Notes

- Native ETH markets use `tokenAddress == address(0)`.
- ERC20 markets use `transferFrom` for stakes and secondary purchases.
- Winning claims receive a proportional pool payout minus a 2% platform fee.
- Fees are tracked by collateral token and withdrawn by the contract owner.
- Listed positions transfer claim ownership to the buyer.
- Both winning and losing claims update reputation.
