import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();
dotenv.config({ path: "../.env" });

const sepoliaRpcUrl = process.env.SEPOLIA_RPC_URL;
const opSepoliaRpcUrl = process.env.OP_SEPOLIA_RPC_URL ?? process.env.SEPOLIA_RPC_URL;
const privateKey = process.env.PRIVATE_KEY;

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.30",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    ...(sepoliaRpcUrl && privateKey
      ? {
          sepolia: {
            url: sepoliaRpcUrl,
            accounts: [privateKey],
            chainId: 11155111,
          },
        }
      : {}),
    ...(opSepoliaRpcUrl && privateKey
      ? {
          opSepolia: {
            url: opSepoliaRpcUrl,
            accounts: [privateKey],
            chainId: 11155420,
          },
        }
      : {}),
  },
};

export default config;
