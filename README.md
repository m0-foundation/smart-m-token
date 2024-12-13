# World Dollar - M Wrapper contract

## Overview

Non-rebasing World Dollar prototype enabling only verified World IDs to earn and claim yield. Backed by a Mock M Token
with an admin that can mint, enable earning, and set the earner rate. In practice, the World Dollar would be backed by
the M Token on the same chain, or on Ethereum Mainnet.

## Deployments

- Mock M Token: [0x310a3b737b87f8120137cc9b1ee65b4afaaf3736](https://worldchain-sepolia.explorer.alchemy.com/address/0x310a3b737b87f8120137cc9b1ee65b4afaaf3736)
- World Dollar Proxy: [0x14082347B46A58A95175e3cb91906762782bdc29](https://worldchain-sepolia.explorer.alchemy.com/address/0x14082347b46a58a95175e3cb91906762782bdc29)
- World Dollar Implementation: [0x2807ffc350A15D360275b0D2526EB6376efCC62B](https://worldchain-sepolia.explorer.alchemy.com/address/0x2807ffc350a15d360275b0d2526eb6376efcc62b)

## Development

### Installation

You may have to install the following tools to use this repository:

- [foundry](https://github.com/foundry-rs/foundry) to compile and test contracts
- [lcov](https://github.com/linux-test-project/lcov) to generate the code coverage report
- [yarn](https://classic.yarnpkg.com/lang/en/docs/install/) to manage node dependencies
- [slither](https://github.com/crytic/slither) to static analyze contracts

Install dependencies:

```bash
npm install
forge install
```

### Env

Copy `.env` and write down the env variables needed to run this project.

```bash
cp .env.example .env
```

### Compile

Run the following command to compile the contracts:

```bash
npm run build
```

or

```bash
make build
```

### Coverage

Forge is used for coverage, run it with:

```bash
npm run coverage
```

or

```bash
make coverage
```

You can then consult the report by opening `coverage/index.html`:

```bash
open coverage/index.html
```

### Test

To run all tests:

```bash
make tests
```

Test a specific test case:

```bash
./test.sh -v -t <test-case-name>
```

To run slither:

```bash
npm run slither
```

### Code quality

[Prettier](https://prettier.io) is used to format Solidity code. Use it by running:

```bash
npm run prettier
```

[Solhint](https://protofire.github.io/solhint/) is used to lint Solidity files. Run it with:

```bash
npm run solhint
```

Or to autofix some issues:

```bash
npm run solhint-fix
```

### Documentation

Forge is used to generate the documentation. Run it with:

```bash
npm run doc
```
