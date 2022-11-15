# Setup

```bash
npm install
```

#### Hardhat

This repo uses [hardhat](https://hardhat.org/).
Hacks are implemented as hardhat tests in [`/test`](./test).

The tests run on a local hardnet network but it needs to be forked from mainnet.
To fork the Ethereum mainnet, you need access to an archive node like the free ones from [Alchemy](https://alchemyapi.io/).

#### Environment variables

Add your URL to your node to the `.env` file. I use Alchemy.

```bash
cp .env.template .env
# fill out
ARCHIVE_URL=https://eth-mainnet.alchemyapi.io/v2/...
```

#### Downloading verified contracts from etherscan

A helper python script called `get_contracts.py` is provided in the root of this project.

To get usage information, try running `python3 get_contracts.py`.

#### Getting contract ABIs

I generally just copy paste the ABI directly into a `.txt` file, and then read it with the `getAbi()` helper function that I wrote.

See `test/templedao_attack.test.ts` for an example.

#### Replaying exploits

The exploits are implemented as hardhat tests. `package.json` contains a script to run each one. You can do either of the following:

```bash
npx hardhat test test/<name>.ts # or yarn <script_name>
yarn <script_name>
```

For example:

```bash
npx hardhat test test/templedao_attack.test.ts # or yarn templedao
```
