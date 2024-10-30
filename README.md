# Wrapped M Token - Smart Wrapper contract

## Overview

Non-rebasing M token alternative with an additional possibility to preserve and forward yield to earners.

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

### CI

The following Github Actions workflow are setup to run on push and pull requests:

- [.github/workflows/coverage.yml](.github/workflows/coverage.yml)
- [.github/workflows/test-gas.yml](.github/workflows/test-gas.yml)

It will build the contracts and run the test coverage, as well as a gas report.

The coverage report will be displayed in the PR by [github-actions-report-lcov](https://github.com/zgosalvez/github-actions-report-lcov) and the gas report by [foundry-gas-diff](https://github.com/Rubilmax/foundry-gas-diff).

For the workflows to work, you will need to setup the `MNEMONIC_FOR_TESTS` and `MAINNET_RPC_URL` repository secrets in the settings of your Github repository.

Some additional workflows are available if you wish to add fuzz, integration and invariant tests:

- [.github/workflows/test-fuzz.yml](.github/workflows/test-fuzz.yml)
- [.github/workflows/test-integration.yml](.github/workflows/test-integration.yml)
- [.github/workflows/test-invariant.yml](.github/workflows/test-invariant.yml)

You will need to uncomment them to activate them.

### Documentation

Forge is used to generate the documentation. Run it with:

```bash
npm run doc
```
