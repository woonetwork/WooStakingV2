const constants = require("./constants");
import {loadJsonFile, deploy, verify, sleep} from "./utils"
import { ethers, run } from "hardhat";

async function deployContracts() {
  let stakingManager = "0x297ad025479bb63E48928B4aB2Bd3696FD24D25B";
  let adminUserAddress = constants.user2;
  let contractName = "SimpleRewarder";
  let args = [constants.depAddressList["usdc"], stakingManager];
  const usdcRewarder = await deploy(args, contractName);
  console.log(`usdc rewarder deployed to: ${usdcRewarder}`);
  await sleep(constants.sleepSeconds);
  await verify(usdcRewarder, args);

  const usdcRewarderContract = await ethers.getContractAt(
    "SimpleRewarder", usdcRewarder);
  const stakingManagerContract = await ethers.getContractAt(
    "WooStakingManager", stakingManager);

    let rewardPerBlock = 1;
    await usdcRewarderContract.setRewardPerBlock(rewardPerBlock);
    await sleep(constants.sleepSeconds);
    console.log("usdcRewarder setRewardPerBlock: %s", rewardPerBlock);

    await usdcRewarderContract.setAdmin(adminUserAddress, true);
    await sleep(constants.sleepSeconds);
    console.log("usdcRewarder setAdmin: %s", adminUserAddress);

    await stakingManagerContract.addRewarder(usdcRewarder);
    await sleep(constants.sleepSeconds);
    console.log("add usdc rewarder: %s", usdcRewarder);
}

async function deployArbRewarder() {
  let stakingManager = "0xa9E245C1FA7E17263Cc7C896488A3da8072924Fb";
  let adminUserAddress = constants.user2;
  let contractName = "SimpleRewarder";
  let args = [constants.depAddressList["arb"], stakingManager];
  const arbRewarder = await deploy(args, contractName);
  console.log(`arb rewarder deployed to: ${arbRewarder}`);
  await sleep(constants.sleepSeconds);
  await verify(arbRewarder, args);

  const arbRewarderContract = await ethers.getContractAt(
    "SimpleRewarder", arbRewarder);
  // const stakingManagerContract = await ethers.getContractAt(
  //   "WooStakingManager", stakingManager);

    let rewardPerBlock = 1e8;
    await arbRewarderContract.setRewardPerBlock(rewardPerBlock);
    await sleep(constants.sleepSeconds);
    console.log("arbRewarder setRewardPerBlock: %s", rewardPerBlock);

    // await arbRewarderContract.setAdmin(adminUserAddress, true);
    // await sleep(constants.sleepSeconds);
    // console.log("arbRewarder setAdmin: %s", adminUserAddress);

    // await stakingManagerContract.addRewarder(arbRewarder);
    // await sleep(constants.sleepSeconds);
    // console.log("add arb rewarder: %s", arbRewarder);
}

async function main() {

  // await deployContracts();
  await deployArbRewarder();

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});