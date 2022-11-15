import hre from 'hardhat';

// Stolen from cmichel's repository
// https://github.com/MrToph/replaying-ethereum-hacks/
export const forkFrom = async (blockNumber: number) => {
  if (!hre.config.networks.hardhat.forking) {
    throw new Error(`Must set up forking in hardhat.config.ts. See: `);
  }

  await hre.network.provider.request({
    method: 'hardhat_reset',
    params: [
      {
        forking: {
          jsonRpcUrl: hre.config.networks.hardhat.forking.url,
          blockNumber: blockNumber,
        },
      },
    ],
  });
};
