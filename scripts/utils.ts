import { ethers, run } from "hardhat";
const constants = require("./constants");
const fs = require("fs");

// // Specify need before deploying contract
export function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

export function loadJsonFile() {
  const filePath = constants.stakingContractsFile;
  const data = fs.readFileSync(filePath);
  let jsonObject = JSON.parse(data);
  return jsonObject;
}

export async function deploy(args: string [], contractName: string) {
  const factory = await ethers.getContractFactory(contractName);
  const contract = await factory.deploy(...args);
  await contract.deployed();
  return contract.address;
}

export async function verify(contractAddress: string, args: string []) {
  try {
    await run("verify:verify", {
      address: contractAddress,
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