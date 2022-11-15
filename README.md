# Setup

```bash
npm install
```

#### Hardhat

This repo uses [hardhat](https://hardhat.org/).

Exploits are implemented as hardhat tests in [`/test`](./test).

Every exploit forks the mainnet at a specific block. Use [Alchemy](https://alchemyapi.io/) to get access to an archive node for free.

See `test/templedao_attack.test.ts` for a quick example.

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

#### Credits

- Stole the `forkFrom()` function from [cmichel](https://cmichel.io/).