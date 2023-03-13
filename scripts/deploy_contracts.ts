// eslint-disable-next-line node/no-unpublished-import
import { ethers, run } from "hardhat";
const constants = require("./constants");
const fs = require("fs");

// // Specify need before deploying contract
function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function writeJsonFile(contracts: Map<string, string>) {
  let jsonObject = {};
  contracts.forEach((value, key) => {
    jsonObject[key] = value;
  });
  const filePath = constants.stakingContractsFile;
  fs.writeFileSync(filePath, JSON.stringify(jsonObject));
}

async function deploy(args: string [], contractName: string) {
  const factory = await ethers.getContractFactory(contractName);
  const contract = await factory.deploy(...args);
  await contract.deployed();
  return contract.address;
}

async function verify(contractAddress: string, args: string []) {
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

async function deployContracts() {
  // write all contract address to a local file

  let contracts = new Map<string, string>();
  // deprecated contract, but need set this param.
  // Need setStakingProxy later.
  const nonContract = "0x0000000000000000000000000000000000000001";
  const depAddressList = constants.depAddressList;
  let args = [depAddressList["woo"], depAddressList["wooPP"], nonContract];
  let contractName = "WooStakingManager";
  const stakingManager = await deploy(args, contractName);
  console.log(`${contractName} deployed to: ${stakingManager}`);
  contracts.set(contractName, stakingManager);
  await sleep(constants.sleepSeconds);
  await verify(stakingManager, args);

  contractName = "WooStakingController";
  args = [constants.depAddressList["lz_fantom_endpoint"], stakingManager];
  const stakingController = await deploy(args, contractName);
  console.log(`${contractName} deployed to: ${stakingController}`);
  contracts.set(contractName, stakingController);
  await sleep(constants.sleepSeconds);
  await verify(stakingController, args);

  contractName = "WooStakingProxy";
  args = [
    constants.depAddressList["lz_fantom_endpoint"],
    constants.lz_fantom_chainid,
    stakingController,
    constants.depAddressList["woo"],
  ];
  const stakingProxy = await deploy(args, contractName);
  console.log(`${contractName} deployed to: ${stakingProxy}`);
  contracts.set(contractName, stakingProxy);
  await sleep(constants.sleepSeconds);
  await verify(stakingProxy, args);

  contractName = "MpRewarder";
  args = [constants.depAddressList["woo"], stakingManager];
  const mpRewarder = await deploy(args, contractName);
  console.log(`${contractName} deployed to: ${mpRewarder}`);
  contracts.set(contractName, mpRewarder);
  await sleep(constants.sleepSeconds);
  await verify(mpRewarder, args);

  contractName = "SimpleRewarder";
  args = [constants.depAddressList["usdc"], stakingManager];
  const usdcRewarder = await deploy(args, contractName);
  console.log(`usdc rewarder deployed to: ${usdcRewarder}`);
  contracts.set("UsdcRewarder", usdcRewarder);
  await sleep(constants.sleepSeconds);
  await verify(usdcRewarder, args);

  args = [constants.depAddressList["weth"], stakingManager];
  const wethRewarder = await deploy(args, contractName);
  console.log(`weth rewarder deployed to: ${wethRewarder}`);
  contracts.set("WethRewarder", wethRewarder);
  await sleep(constants.sleepSeconds);
  await verify(wethRewarder, args);

  contractName = "WooStakingCompounder";
  args = [stakingManager];
  const compounder = await deploy(args, contractName);
  console.log(`${contractName} deployed to: ${compounder}`);
  contracts.set(contractName, compounder);
  await sleep(constants.sleepSeconds);
  await verify(compounder, args);

  contractName = "RewardBooster";
  args = [mpRewarder, compounder];
  const booster = await deploy(args, contractName);
  console.log(`${contractName} deployed to: ${booster}`);
  contracts.set(contractName, booster);
  await sleep(constants.sleepSeconds);
  await verify(booster, args);

  writeJsonFile(contracts);

}

async function main() {
  // let contracts = new Map<string, string>;
  // contracts.set("stakingManager", "0x00");
  // writeJsonFile(contracts);

  await deployContracts();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});



