This document just tracks my notes when attempting to recreate this attack.

# Step 1 - Reverse engineer the transaction

[The transaction](https://snowtrace.io/tx/0x0ab12913f9232b27b0664cd2d50e482ad6aa896aeb811b53081712f42d54c026) has 70 logs. Each log is an emitted event, but there is no call stack.

It's a little hard to parse the event logs, because events are emitted only during certain functions. Lots of reading is required to figure out how this happens. I won't list the events from first to last, instead I'll note the most important ones in the way that makes sense.

### Events 2 and 71

In Event 1, [this proxy contract](https://snowtrace.io/address/0x625e7708f30ca75bfd92586e17077590c60eb4cd) ([implementation contract here](https://snowtrace.io/address/0xdf9e4abdbd94107932265319479643d3b05809dc)) transfers 51,000,000 USDC to the attacker. 

In order to figure out why, we look at the very last event, 71, which is a `flashLoan` event emitted by [this contract](https://snowtrace.io/address/0x794a61358d6845594f94dc1db02a252b5b4814ad) ([implementation here](https://snowtrace.io/address/0xdf9e4abdbd94107932265319479643d3b05809dc#code)) through the `_handleFlashLoanRepayment()` method inside `FlashLoanLogic.sol` in the implementation contract above. This function is called by `executeFlashLoanSimple()`, which is called by `flashLoanSimple()` inside `Pool.sol`.

This tells us that the majority of the attack happens in the flash loan callback, as the very last event is the repayment of the flash loan, while the first event is the transfer of the tokens from the call to `transferUnderlyingTo()` inside `executeFlashLoanSimple()`.

### Events 3 to 9

In all of these events, the attacker contract is approving other contracts to spend each token on the attacker's behalf. These tokens (and corresponding spenders) are:

1. USDC - [Trader Joe Router](https://snowtrace.io/address/0x60ae616a2155ee3d9a68541ba4544862310933d4)
2. USDC.e - [Curve.fi Factory Plain Pool: USD Coin](https://snowtrace.io/address/0x3a43a5851a3e3e0e25a3c1089670269786be1577)
3. USDC.e - [Trader Joe Router](https://snowtrace.io/address/0x60ae616a2155ee3d9a68541ba4544862310933d4)
4. WAVAX - [Trader Joe Router](https://snowtrace.io/address/0x60ae616a2155ee3d9a68541ba4544862310933d4)
5. JLP - [DegenBox contract](https://snowtrace.io/address/0x0b1f9c2211f77ec3fa2719671c5646cf6e59b775)
6. NXUSD - [Trader Joe Router](https://snowtrace.io/address/0x60ae616a2155ee3d9a68541ba4544862310933d4)
7. NXUSD - [A Curve.fi contract](https://snowtrace.io/address/0x001e3ba199b4ff4b5b6e97acd96dafc0e2e4156e). Unsure what this contract does exactly just yet

### Event 10

The attacker contract now calls the DegenBox contract's `setMasterContractApproval()` to approve [this CauldronV2.sol](https://snowtrace.io/address/0xe767c6c3bf42f550a5a258a379713322b6c4c060) contract to access the attacker contract's funds.

DegenBox seems to be another version of SushiSwap's BentoBox, which you can find documentation for [here](https://docs.sushi.com/docs/Developers/Bentobox/Overview). No idea what `CauldronV2.sol` does at this point.

### Events 11 to 14

In order to understand whats going on here, we have to work backwards. The reasoning is because in event 11, the attacker sends 280,000 USDC to the [JLP Token Contract](https://snowtrace.io/address/0xf4003f4efbe8691b60249e6afbd307abe7758adb), and in event 12, the JLP Token Contract sends back 14735.962350184152 WAVAX, and we have no idea why this contract would do that unless we look at the next two events.

Event 13 and 14 are a Sync and a Swap in order, both being emitted from the JLP Token Contract. Looking at the code, the `swap()` function will call `_update()` at the end before emitting the Swap event, and the `_update()` function emits a `Sync` event. We can also see that `token0` and `token1` are WAVAX and USDC respectively.

We can now infer that the attacker swapped USDC for WAVAX in these events.

### Events 15 to 20

Let's see what happens:

15 - Attacker transfers 260,000 USDC to the JLP Token Contract
16 - Attacker transfers 13401.980954596283 WAVAX to the JLP Token Contract
17 - JLP Token Contract transfers 0.000012652872819651 JLP tokens to this [MoneyMaker contract](https://snowtrace.io/address/0x63c0cf90ae12190b388f9914531369ac1e4e4e47)
18 - JLP Token Contract transfers 0.04533097793130507 JLP tokens to the attacker
19 - JLP Token Contract syncs its reserves
20 - JLP Token Contract mints 260,000 USDC and 13401.980954596283 WAVAX to the [Trader Joe Router](https://snowtrace.io/address/0x60ae616a2155ee3d9a68541ba4544862310933d4)

So, what exactly happened here? Well, let's find why JLP Token Contract would mint anything at all to the Trader Joe Router.

In the `mint()` function, the `Mint` event is emitted at the end, and the `msg.sender` in this case is the Trader Joe Router.

Looking at the [Trader Joe Router code](https://snowtrace.io/address/0x60ae616a2155ee3d9a68541ba4544862310933d4#code), a JLP Pair token's `mint()` function is called in `addLiquidity()` and `addLiquidityAVAX()`. 

The attacker does not call `addLiquidityAVAX()` because, just by following the code, we can tell that this function will emit a `Deposit` event which we don't see.

On the flip side, `addLiquidity()` emits two `Transfer` events to the JLP Pair token before calling `mint()`. This is exactly what we see: The attacker transfers USDC and WAVAX to the pair token.

Where does this MoneyMaker contract come in (event 17)? Well, looking at the `mint()` function in the JLP Pair token, it calls `_mintFee()`, which gets the [JoeFactory contract](https://snowtrace.io/address/0x9ad6c38be94206ca50bb0d90783181662f0cfa10)'s `feeTo` storage variable, and then sends 0.05% of the LP tokens that it's about to mint. This `feeTo` variable happens to point at the MoneyMaker contract.

Finally, the `Mint` event is emitted. Note these tokens aren't actually sent to the Trader Joe Router, it's just the event's sender is the router itself.

So, based on all of this, we know the attacker added liquidity to this pair by calling the router's `addLiquidity()` function.

### Events 21 to 24

Looks familiar. The attacker swaps 50,460,000 USDC for 505213.7502091872 WAVAX tokens.

### Events 25 to 30

This one was actually a very difficult one to figure out. First thing to know is that each log has a topic, and the topic is a 32 byte word that describes an event. 

This 32 byte word is the keccak256 hash of the event itself.

For example, for the `LogBorrow` event inside the [CauldronV2 contract](0xc0a7a7f141b6a5bce3ec1b81823c8afa456b6930) where event 25 is coming from, it's defined as:

```
event LogBorrow(address indexed from, address indexed to, uint256 amount, uint256 part, address collateral);
```

Therefore, the topic for this event would be:

```
keccak256("LogBorrow(address,address,uint256,uint256,address)")
=
0xa7a43160f40531d706d40a466a7d0e9ab2b6725f705d28ac6f4dd6280b940d25
```

Why is this important? Well, events 25, 26, and 28 have no name! I don't know why, but we can tell that they're coming from the the aforementioned [Cauldron contract](https://snowtrace.io/address/0xc0a7a7f141b6a5bce3ec1b81823c8afa456b6930). Looking at the events in it and doing hashing each one, we know the following:

25 - `LogExchangeRate`
26 - `LogAccrue`
27 - `LogTransfer` from the [DegenBox contract](https://snowtrace.io/address/0x0b1f9c2211f77ec3fa2719671c5646cf6e59b775)
28 - `LogBorrow`
29 - `Transfer`
30 - `LogWithdraw` from the [DegenBox contract](https://snowtrace.io/address/0x0b1f9c2211f77ec3fa2719671c5646cf6e59b775)

Ok, so whats happening? `LogExchangeRate` comes from a call to `updateExchangeRate()`, which uses an oracle to update the exchange rate between the collateral and the asset. In this case, the collateral is the WAVAX/USDC JLP Token pair, easily confirmed by attempting to read the `collateral` storage variable.

Checking the exchange rate before and after experimentally, we have 88793190826 vs 32701350550 (in wei). Now, calculating how much the attacker can borrow with the 0.04533097793130507 WAVAX/USDC LP tokens they have, we get:

1. Before - 0.04533097793130507 / (88793190826 / 1e18) = 510523.132569209 NXUSD
2. After - 0.04533097793130507 / (32701350550 / 1e18) = 1386211.186048555 NXUSD

So.. The attacker put in ~520,000 worth of USDC into the liquidity pool to get this much LP tokens. Now they can use the same amount of LP tokens as collateral to borrow ~1.38m dollars worth of NXUSD tokens!

Now, obviously collateral is used to borrow something else, so what are we borrowing? Well, the `LogAccrue` event comes from the `accrue()` function, and the `LogBorrow` event comes from the `_borrow()` internal function. Looking at the external `borrow()` function:

```
function borrow(address to, uint256 amount) public solvent virtual returns (uint256 part, uint256 share) {
    accrue();
    (part, share) = _borrow(to, amount);
}
```

Pretty convenient, this must be where events 26-28 are coming from.

`accrue()` is used to update some storage variables to account for interest on all tokens that have been currently borrowed from this contract, namely the `totalBorrow` storage variable.

`borrow()` is now called. The `LogTransfer` event in this function doesn't actually mean the tokens were transferred to the attacker yet. It only logs that the attacker "borrowed" the tokens, but until we see a `Transfer` event to the attacker's account, we can assume the attacker doesn't have the tokens yet. This `LogTransfer` event is followed by a `LogBorrow` event.

One quick quirk here is that when the `borrow()` function calls the DegenBox contract's `transfer()` function, there is a modifier on the function that checks of the `from` address matches `msg.sender`. This would only be the case if the CauldronV2 contract is calling on behalf of us (or if someone is being phished I guess). In this case, it checks if the CauldronV2's master contract has approval to do things on our behalf. That's why the attacker had to make that master contract approval at the beginning.

Why couldn't the attacker use the master CauldronV2? Well, because the master CauldronV2 doesn't have an oracle set! The slave one does though, so that allows the attacker to `updateExchangeRate()` after pumping the price.

After all of that, we see a `Transfer` followed by a `LogWithdraw`. This comes from the `withdraw()` function in the DegenBox contract. This time the attacker calls the function directly without going through the CauldronV2 contract. The function just transfers the user the NXUSD tokens (all 998,000 of them).. Why? I have no idea

### Events 31 to 34

The attacker deposits their entire balance of WAVAX/USDC JLP Pair tokens by calling the `deposit()` function on the DegenBox contract.

Then, a `LogTransfer` followed by another unnamed event comes from the CauldronV2 contract. This time, it's the `LogAddCollateral` event. The `addCollateral()` function is called 

These two steps essentially:

1. Transfer the JLP Pair tokens to the DegenBox contract.
2. Tracks them as collateral that the attacker has provided to the CauldronV2 contract.

### Events 35 to 38

The attacker swaps 506,547.7316047751 WAVAX for 50,426,896.250037 USDC

Right now, the attacker has 998,000 NXUSD + 50,426,896 USDC. Assuming both are equal, the attacker now has 51,424,896 USDC, when they started off with a flash loan of 51 million. The premium in this case is 25,500, so the attacker can get away with almost 400,000 USDC profit here.

### Past event 39

Past this point, it was pretty hard to figure out what the attacker was doing.

Looking at the transaction itself (not the logs), I decided to find a similar transaction in the same contract the attacker transfers his NXUSD into, and I found a very similar looking transaction where the output is avUSDC, just like in the attacker's transaction (the attacker later on goes on to convert the avUSDC to USDC.e, but we'll look at that later).

That transaction in question is [this one](https://snowtrace.io/tx/0x662311af76a1212026adae483211beca317242d1aa8f4529f0c188f8d904191e). You can see the similarities between the attacker's transaction and this one.

The function being called here is `exchange_underlying()`, with the pool being [this pool](https://snowtrace.io/address/0x6bf6fc7eaf84174bb7e1610efd865f0ebd2aa96d)

Following this function, it calls the pool's `exchange_underlying()` function, which emits `TokenExchangeUnderlying` event. Looking for this event in the logs, we see it in event 50. With this, we can verify that the attacker called this function with `i = 0` (NXUSD token index), and `j = 2` (which ends up being the avUsdc token, because they access the `j-1` index inside the `underlying_coins[]` array).

The avUsdc token is wrapped into USDC.e, and then sent back to the attacker. From here, the attacker can just use the Trader Joe Router to swap USDC.e for USDC, and the exploit is complete.