import { expect } from 'chai';
import { Contract, Signer } from 'ethers';
import { ethers } from 'hardhat';
import { getAbi } from '../utils/abi';
import { forkFrom } from '../utils/fork';

describe('SportsDAO Exploit', async () => {
  let attacker: Signer;
  let attackerContract: Contract;
  let busdContract: Contract;

  const BUSD_ADDRESS = '0x55d398326f99059fF775485246999027B3197955';

  before(async () => {
    // One block before the attack occurred.
    // Txn: https://bscscan.com/tx/0xb3ac111d294ea9dedfd99349304a9606df0b572d05da8cedf47ba169d10791ed
    await forkFrom(23241440);

    // Get an attacker EOA that we can use
    [attacker] = await ethers.getSigners();

    // Deploy the attacker script
    attackerContract = await (
      await ethers.getContractFactory('SportsDAOAttack', attacker)
    ).deploy();

    // NOTE: The code below is used for testing purposes so our flash loan
    // always gets repaid when testing the unfinished exploit.
    //
    // Mint a bunch of BUSD to ourselves
    const busd_abi = await getAbi('abis/BSC-USDABI.txt');
    busdContract = await ethers.getContractAt(busd_abi, BUSD_ADDRESS);

    /*const impersonated = await ethers.getImpersonatedSigner(
      '0xf68a4b64162906eff0ff6ae34e2bb1cd42fef62d',
    );

    await busdContract.connect(impersonated).transferOwnership(attacker.getAddress());

    await busdContract.connect(attacker).mint(ethers.utils.parseEther('500'));

    await busdContract
      .connect(attacker)
      .transfer(attackerContract.address, ethers.utils.parseEther('500'));*/
  });

  it('Exploits successfully', async () => {
    // Run our exploit
    await attackerContract.exploit();

    // We should expect to have more than 0 BUSD
    expect(await busdContract.balanceOf(attacker.getAddress())).to.be.gt('0');
  });
});
