# WorldCupBetting

Solidity/Hardhat project for the World Cup on-chain betting assessment.

The contract implementation is in:

```text
contracts/contracts/WorldCupBetting.sol
```

## Quick Start

Run all commands from the `contracts` folder:

```bash
cd contracts
npm install --legacy-peer-deps
npm run typecheck
npm run compile
npm test
```

Expected result:

```text
11 passing
```

The official assessment tests can also be run directly:

```bash
npm run test:assessment
```

Expected result:

```text
9 passing
```

## Deployed Contract

The latest public deployment is on OP Sepolia.

```text
Network: OP Sepolia
Chain ID: 11155420
WorldCupBetting: 0x2A7981398a9Afa94F999d8e8E817b31Ef724BA63
ReputationSystem: 0x4DAC1A51ef037DE8d894dc5C6614DfC9c98a339F
```

Explorer:

```text
https://testnet-explorer.optimism.io/address/0x2A7981398a9Afa94F999d8e8E817b31Ef724BA63
```

Deployment details are also saved in:

```text
contracts/deployments/opSepolia.json
contracts/deployments/OP_SEPOLIA.md
```

## Local Deploy

To test the deploy script on Hardhat's local in-memory network:

```bash
cd contracts
npm run deploy
```

## OP Sepolia Deploy

Create a local `.env` file with:

```bash
OP_SEPOLIA_RPC_URL=https://your-op-sepolia-rpc
PRIVATE_KEY=0xYOUR_DEPLOYER_PRIVATE_KEY
```

Then run:

```bash
cd contracts
npm run deploy:op-sepolia
```

Never commit `.env`, private keys, seed phrases, or wallet screenshots.
