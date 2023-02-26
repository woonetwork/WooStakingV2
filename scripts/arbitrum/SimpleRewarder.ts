// eslint-disable-next-line node/no-unpublished-import
import { ethers, run } from "hardhat";

// eslint-disable-next-line prefer-const
let contractName = "SimpleRewarder";

// Specify need before deploying contract

const stakingManager = "0xba91ffD8a2B9F68231eCA6aF51623B3433A89b13";
const tokenAddr = "0x04068DA6C83AFCFA0e13ba15A6696662335D5B75"; // USDC
// const tokenAddr = "0x74b23882a30290451A17c44f4F05243b6b58C76d"; // WETH

async function main() {
  const args = [tokenAddr, stakingManager];
  const factory = await ethers.getContractFactory(contractName);
  const contract = await factory.deploy(...args);
  await contract.deployed();
  console.log(`${contractName} deployed to: ${contract.address}`);

  await new Promise((resolve) => setTimeout(resolve, 10000));
  try {
    await run("verify:verify", {
      address: contract.address,
      constructorArguments: args,
    });
  } catch (e) {
    if (typeof e === "string") {
      console.log(e.toUpperCase()); // works, `e` narrowed to string
    } else if (e instanceof Error) {
      console.log(e.message); // works, `e` narrowed to Error
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
