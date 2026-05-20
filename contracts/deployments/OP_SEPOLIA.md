# OP Sepolia Deployment

These are public deployment details only. This file does not contain private keys, seed phrases, RPC secrets, or wallet credentials.

## Network

```text
Network: OP Sepolia
Chain ID: 11155420
```

## Contracts

```text
WorldCupBetting: 0x2A7981398a9Afa94F999d8e8E817b31Ef724BA63
ReputationSystem: 0x4DAC1A51ef037DE8d894dc5C6614DfC9c98a339F
```

## Explorer Links

- WorldCupBetting: https://testnet-explorer.optimism.io/address/0x2A7981398a9Afa94F999d8e8E817b31Ef724BA63
- ReputationSystem: https://testnet-explorer.optimism.io/address/0x4DAC1A51ef037DE8d894dc5C6614DfC9c98a339F

## What To Share

If the reviewer asks for a deployed contract address, share the `WorldCupBetting` address and say it is deployed on OP Sepolia.

```text
OP Sepolia WorldCupBetting:
0x2A7981398a9Afa94F999d8e8E817b31Ef724BA63
Explorer:
https://testnet-explorer.optimism.io/address/0x2A7981398a9Afa94F999d8e8E817b31Ef724BA63
```

The `ReputationSystem` address is included because `WorldCupBetting` was deployed with it in the constructor and uses it during claims.
