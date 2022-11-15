import { Contract, Signer } from 'ethers';
import { ethers } from 'hardhat';
import { beforeEach, describe } from 'mocha';
import { forkFrom } from './utils/fork';
import dotenv from 'dotenv';
import { getAbi } from './utils/abi';

describe('TempleDAO Exploit', async () => {
  dotenv.config();

  let attacker: Signer;
  let stakingContract: Contract;
  const STAKING_CONTRACT_ADDRESS = '0xd2869042e12a3506100af1d192b5b04d65137941';
  const { API_KEY } = process.env;

  before(async () => {
    // Block number from October 8, 3 days before the attack
    await forkFrom(15700000);

    // Get an attacker EOA that we can use
    [attacker] = await ethers.getSigners();

    // Get the contract ABI
    const contract_abi = await getAbi('contracts/StaxLPStakingExploit/StaxLPStakingABI.txt');
    stakingContract = await ethers.getContractAt(
      contract_abi,
      '0xd2869042e12a3506100af1d192b5b04d65137941',
    );
  });

  it('Exploits successfully', async () => {
    console.log(stakingContract);
  });
});
