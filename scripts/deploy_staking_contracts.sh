#!/bin/bash

# 1. deploy and verify contracts
# 2. setup contracts and set admin for contracts

# NOTE: need run this script on folder WooStakingV2.

# npx hardhat run --network fantom_mainnet scripts/deploy_contracts.ts
# npx hardhat run --network fantom_mainnet scripts/setup_contracts.ts

# npx hardhat run --network arbitrum_mainnet scripts/deploy_contracts.ts
# npx hardhat run --network arbitrum_mainnet scripts/setup_contracts.ts


# NOTE: deploy proxy contracts
# npx hardhat run --network fantom_mainnet scripts/deploy_proxy_contracts.ts
# npx hardhat run --network bsc_mainnet scripts/deploy_proxy_contracts.ts
# npx hardhat run --network avalanche_mainnet scripts/deploy_proxy_contracts.ts
# npx hardhat run --network polygon_mainnet scripts/deploy_proxy_contracts.ts
# npx hardhat run --network optimism_mainnet scripts/deploy_proxy_contracts.ts


# NOTE: controller add proxy contracts
# npx hardhat run --network arbitrum_mainnet scripts/deploy_proxy_contracts.ts

npx hardhat run --network arbitrum_mainnet scripts/arbitrum/RewardNFT.ts


