import dotenv from 'dotenv';
import { task, HardhatUserConfig } from 'hardhat/config';
import '@nomiclabs/hardhat-waffle';
import '@nomiclabs/hardhat-ethers';
import '@tenderly/hardhat-tenderly';
import './tasks/index';

dotenv.config();
const { ETH_ARCHIVE_URL, AV_ARCHIVE_URL } = process.env;

// Just a sanity check, at least one archive URL should be set
if (!ETH_ARCHIVE_URL || !AV_ARCHIVE_URL)
  throw new Error(
    `An archive URL has not been set in .env. Copy .env.example to .env and set the appropriate env var`,
  );

// Go to https://hardhat.org/config/ to learn more
const config: HardhatUserConfig = {
  networks: {
    hardhat: {
      loggingEnabled: false,
      forking: {
        url: AV_ARCHIVE_URL, // Set archive URL here
        blockNumber: 15700000, // we will set this in each test
      },
    },
  },

  solidity: {
    version: '0.8.7',
  },
};

export default config;
