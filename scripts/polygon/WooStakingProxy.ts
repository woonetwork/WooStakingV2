// eslint-disable-next-line node/no-unpublished-import
import { ethers, run } from "hardhat";

// eslint-disable-next-line prefer-const
let contractName = "WooStakingProxy";

// Specify need before deploying contract

const endpoint = "0x3c2269811836af69497E5F486A85D7316753cf62";
const controller = "0x747f99D619D5612399010Ec5706F13e3345c4a9E";
const want = "0x1B815d120B3eF02039Ee11dC2d33DE7aA4a8C603";

async function main() {
  const args = [endpoint, controller, want];
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
