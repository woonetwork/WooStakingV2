<p align="center"><img src="https://files.gitbook.com/v0/b/gitbook-x-prod.appspot.com/o/spaces%2F-McghiWP3H5y-b9oQ6H6-887967055%2Fuploads%2FMaPxIQMWO8RcUv6vMK1n%2Flogo2.png?alt=media&token=e51ef4bd-664e-4356-9e38-fdfa12baf27d" width="320" /></p>
<div align="center">
  <a href="https://github.com/woonetwork/WooStakingV2/actions/workflows/checks.yaml" style="text-decoration:none;">
    <img src="https://github.com/woonetwork/WooStakingV2/actions/workflows/checks.yaml/badge.svg" alt='Build & Build' />
  </a>
  <a href='https://github.com/woonetwork/WooStakingV2/actions/workflows/tests.yaml' style="text-decoration:none;">
    <img src='https://github.com/woonetwork/WooStakingV2/actions/workflows/tests.yaml/badge.svg' alt='Unit Tests' />
  </a>
</div>

## WOOFi Woo Staking V2.0

This repository contains the smart contracts and solidity library for the WOOFi staking:
- Supports the $woo token staking, and provide benefits for long term user
- Escrowed Woo (esWOO) can be staked for rewards similar to regular WOO tokens; or vested to become actual WOO tokens over a period of time
- Stake and consume the specific NFTs to boost the vesting benefits


## Security

#### Bug Bounty

Bug bounty for the smart contracts: [Bug Bounty](https://learn.woo.org/woofi/woofi-swap/bug-bounty).

#### Security Audit

3rd party security audit: [Audit Report](https://learn.woo.org/woofi/woofi-swap/audits).

### Code Structure

It is a hybrid [Hardhat](https://hardhat.org/) repo that also requires [Foundry](https://book.getfoundry.sh/index.html) to run Solidity tests powered by the [ds-test library](https://github.com/dapphub/ds-test/).

> To install Foundry, please follow the instructions [here](https://book.getfoundry.sh/getting-started/installation.html).

### Run tests

- TypeScript tests are included in the `typescript` folder in the `test` folder at the root of the repo.
- Solidity tests are included in the `foundry` folder in the `test` folder at the root of the repo.

### Example of Foundry/Forge commands

```shell
forge build
forge test
forge test -vv
forge tree
```

### Example of Hardhat commands

```shell
npx hardhat accounts
npx hardhat compile
npx hardhat clean
npx hardhat test
npx hardhat node
npx hardhat help
REPORT_GAS=true npx hardhat test
npx hardhat coverage
npx hardhat run scripts/deploy.ts
TS_NODE_FILES=true npx ts-node scripts/deploy.ts
npx eslint '**/*.{js,ts}'
npx eslint '**/*.{js,ts}' --fix
npx prettier '**/*.{json,sol,md}' --check
npx prettier '**/*.{json,sol,md}' --write
npx solhint 'contracts/**/*.sol'
npx solhint 'contracts/**/*.sol' --fix
```
