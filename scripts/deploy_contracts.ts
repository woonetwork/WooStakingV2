// eslint-disable-next-line node/no-unpublished-import
const constants = require("./constants");
import {loadJsonFile, deploy, verify, sleep} from "./utils"
const fs = require("fs");

function writeJsonFile(contracts: Map<string, string>) {
  let jsonObject = {};
  contracts.forEach((value, key) => {
    jsonObject[key] = value;
  });
  const filePath = constants.stakingContractsFile;
  fs.writeFileSync(filePath, JSON.stringify(jsonObject));
}

async function deployContracts() {
  // write all contract address to a local file

  let contracts = new Map<string, string>();
  const depAddressList = constants.depAddressList;
  let args = [depAddressList["woo"]];
  let contractName = "WooStakingManager";
  const stakingManager = await deploy(args, contractName);
  console.log(`${contractName} deployed to: ${stakingManager}`);
  contracts.set(contractName, stakingManager);
  await sleep(constants.sleepSeconds);
  await verify(stakingManager, args);

  contractName = "WooStakingLocal";
  args = [depAddressList["woo"], stakingManager];
  const stakingLocal = await deploy(args, contractName);
  console.log(`${contractName} deployed to: ${stakingLocal}`);
  contracts.set(contractName, stakingLocal);
  await sleep(constants.sleepSeconds);
  await verify(stakingLocal, args);

  contractName = "WooStakingController";
  args = [constants.lz_endpoint, stakingManager];
  const stakingController = await deploy(args, contractName);
  console.log(`${contractName} deployed to: ${stakingController}`);
  contracts.set(contractName, stakingController);
  await sleep(constants.sleepSeconds);
  await verify(stakingController, args);

  contractName = "WooStakingProxy";
  args = [
    constants.lz_endpoint,
    constants.lz_chainid,
    stakingController,
    constants.depAddressList["woo"],
  ];
  const stakingProxy = await deploy(args, contractName);
  console.log(`${contractName} deployed to: ${stakingProxy}`);
  contracts.set(contractName, stakingProxy);
  await sleep(constants.sleepSeconds);
  await verify(stakingProxy, args);

  contractName = "MpRewarder";
  args = [stakingManager];
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

  // args = [constants.depAddressList["weth"], stakingManager];
  // const wethRewarder = await deploy(args, contractName);
  // console.log(`weth rewarder deployed to: ${wethRewarder}`);
  // contracts.set("WethRewarder", wethRewarder);
  // await sleep(constants.sleepSeconds);
  // await verify(wethRewarder, args);

  args = [constants.depAddressList["arb"], stakingManager];
  const arbRewarder = await deploy(args, contractName);
  console.log(`arb rewarder deployed to: ${arbRewarder}`);
  contracts.set("ArbRewarder", arbRewarder);
  await sleep(constants.sleepSeconds);
  await verify(arbRewarder, args);

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

// NOTE: Sometimes verify contracts failed.
// Need run this func mannually.
async function verifyContracts() {
  const contracts = loadJsonFile();
  
  const depAddressList = constants.depAddressList;


  let args = [depAddressList["woo"]];
  let contractName = "WooStakingManager";
  let stakingManager = contracts[contractName];
  await verify(contracts[contractName], args);

  contractName = "WooStakingLocal";
  args = [depAddressList["woo"], contracts["WooStakingManager"]];
  await verify(contracts[contractName], args);

  contractName = "WooStakingController";
  args = [constants.lz_endpoint, contracts["WooStakingManager"]];
  await verify(contracts[contractName], args);

  contractName = "WooStakingProxy";
  args = [
    constants.lz_endpoint,
    constants.lz_chainid,
    contracts["WooStakingController"],
    constants.depAddressList["woo"],
  ];
  await verify(contracts[contractName], args);

  contractName = "MpRewarder";
  args = [contracts["WooStakingManager"]];
  await verify(contracts[contractName], args);

  args = [constants.depAddressList["usdc"], contracts["WooStakingManager"]];
  await verify(contracts["UsdcRewarder"], args);

  args = [constants.depAddressList["weth"], stakingManager];
  await verify(contracts["WethRewarder"], args);

  contractName = "WooStakingCompounder";
  args = [stakingManager];
  await verify(contracts[contractName], args);

  contractName = "RewardBooster";
  args = [contracts["MpRewarder"], contracts["WooStakingCompounder"]];
  await verify(contracts[contractName], args);
}

async function main() {
  // let contracts = new Map<string, string>;
  // contracts.set("stakingManager", "0x00");
  // writeJsonFile(contracts);

  await deployContracts();

  // await verifyContracts();

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});



