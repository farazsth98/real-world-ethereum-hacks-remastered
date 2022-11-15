import dotenv from 'dotenv';
import { task, HardhatUserConfig } from 'hardhat/config';
import '@nomiclabs/hardhat-waffle';
import '@nomiclabs/hardhat-ethers';
import '@tenderly/hardhat-tenderly';
import './tasks/index';

dotenv.config();
const { ARCHIVE_URL } = process.env;

if (!ARCHIVE_URL)
  throw new Error(`ARCHIVE_URL env var not set. Copy .env.example to .env and set the env var`);

// Go to https://hardhat.org/config/ to learn more
const config: HardhatUserConfig = {
  networks: {
    hardhat: {
      loggingEnabled: false,
      forking: {
        url: ARCHIVE_URL, // https://eth-mainnet.alchemyapi.io/v2/SECRET`,
        blockNumber: 11800000, // we will set this in each test
      },
    },
  },
};

export default config;
