import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

let dotenv = require('dotenv')
dotenv.config()

const apiKey = process.env.ETHERSCAN_API_KEY

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.19',
    settings: {
      optimizer: {
        enabled: true,
      },
    },
  },
  mocha: {
    timeout: 100000000
  },
  networks: {
    sepolia: {
      // url: "https://api.zan.top/node/v1/eth/sepolia/public",
      url: "https://eth-sepolia.public.blastapi.io"	,
      // url: "https://rpc.sepolia.org",
      chainId: 11155111,
      accounts: [process.env.KEY_SEPOLIA!],
    }
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.ETHERSCAN_API_KEY!
    }
  }
};

export default config;
