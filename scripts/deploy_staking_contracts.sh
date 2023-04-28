#!/bin/bash

# 1. deploy and verify contracts
# 2. setup contracts and set admin for contracts

# NOTE: need run this script on folder WooStakingV2.

# npx hardhat run --network fantom_mainnet scripts/deploy_contracts.ts
# npx hardhat run --network fantom_mainnet scripts/setup_contracts.ts

npx hardhat run --network arbitrum_mainnet scripts/deploy_contracts.ts
npx hardhat run --network arbitrum_mainnet scripts/setup_contracts.ts


