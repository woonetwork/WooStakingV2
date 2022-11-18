import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import * as dotenv from "dotenv";
import "hardhat-deploy";
import "hardhat-gas-reporter";
import { HardhatUserConfig, task } from "hardhat/config";
import "solidity-coverage";

dotenv.config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

function envVarSet(_str: string | undefined): _str is string {
  return _str !== undefined && _str !== "";
}

const accounts =
  process.env.PRIVATE_KEY !== undefined
    ? [process.env.PRIVATE_KEY]
    : [process.env.ADMIN_PRIVATE_KEY];

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  namedAccounts: {
    admin: {
      default: 0,
    },
    user: {
      default: 1,
    },
  },
  networks: {
    hardhat: {
      chainId: 1337, // https://hardhat.org/metamask-issue.html
      tags: ["test"],
    },
    ...(envVarSet(process.env.GOERLI_URL)
      ? {
          goerli: {
            url: process.env.GOERLI_URL,
            accounts,
          },
        }
      : {}),
    ...(envVarSet(process.env.GOERLI_URL)
      ? {
          arbitrum: {
            url: process.env.ARBITRUM_URL,
            accounts,
          },
        }
      : {}),
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
