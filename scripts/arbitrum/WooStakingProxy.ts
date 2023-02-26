// eslint-disable-next-line node/no-unpublished-import
import { ethers, run } from "hardhat";

// eslint-disable-next-line prefer-const
let contractName = "WooStakingProxy";

// Specify need before deploying contract

const endpoint = "0xb6319cC6c8c27A8F5dAF0dD3DF91EA35C4720dd7";
const chainid = 112;
const controller = "0x3784A47D47593542903E3A319332e4719B8F95Da";
const want = "0x6626c47c00F1D87902fc13EECfaC3ed06D5E8D8a";


async function main() {
  const args = [endpoint, chainid, controller, want];
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
