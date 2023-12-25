// eslint-disable-next-line node/no-unpublished-import
import { ethers, run } from "hardhat";
const fs = require("fs");
const constants = require("./constants");

function loadJsonFile() {
  const filePath = constants.stakingContractsFile;
  const data = fs.readFileSync(filePath);
  let jsonObject = JSON.parse(data);
  return jsonObject;
}


function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function getContracts() {
  const addressList = loadJsonFile();
  const stakingManager = await ethers.getContractAt(
    "WooStakingManager", addressList["WooStakingManager"]);
  const mpRewarder = await ethers.getContractAt(
    "MpRewarder", addressList["MpRewarder"]);
  const usdcRewarder = await ethers.getContractAt(
      "SimpleRewarder", addressList["UsdcRewarder"]);
  const arbRewarder = await ethers.getContractAt(
    "SimpleRewarder", addressList["ArbRewarder"]);

  const booster = await ethers.getContractAt(
    "RewardBooster", addressList["RewardBooster"]);
  const wooStakingCompounder = await ethers.getContractAt(
    "WooStakingCompounder", addressList["WooStakingCompounder"]);
  const wooStakingController = await ethers.getContractAt(
      "WooStakingController", addressList["WooStakingController"]);
  const wooStakingProxy = await ethers.getContractAt(
        "WooStakingProxy", addressList["WooStakingProxy"]);
  const wooStakingLocal = await ethers.getContractAt(
    "WooStakingLocal", addressList["WooStakingLocal"]);
  return [
    stakingManager,
    mpRewarder,
    usdcRewarder,
    arbRewarder,
    booster,
    wooStakingCompounder,
    wooStakingController,
    wooStakingProxy,
    wooStakingLocal,
  ]
}

async function setUserAdmin(userAddress: string) {
  const [
    stakingManager,
    mpRewarder,
    usdcRewarder,
    arbRewarder,
    booster,
    wooStakingCompounder,
    wooStakingController,
    wooStakingProxy,
    wooStakingLocal,
  ] = await getContracts();

  await stakingManager.setAdmin(userAddress, true);
  await sleep(constants.sleepSeconds);
  console.log("stakingManager setAdmin: %s", userAddress);
  
  await mpRewarder.setAdmin(userAddress, true);
  await sleep(constants.sleepSeconds);
  console.log("mpRewarder setAdmin: %s", userAddress);
  
  await usdcRewarder.setAdmin(userAddress, true);
  await sleep(constants.sleepSeconds);
  console.log("usdcRewarder setAdmin: %s", userAddress);

  await arbRewarder.setAdmin(userAddress, true);
  await sleep(constants.sleepSeconds);
  console.log("arbRewarder setAdmin: %s", userAddress);

  await booster.setAdmin(userAddress, true);
  await sleep(constants.sleepSeconds);
  console.log("booster setAdmin: %s", userAddress);

  await wooStakingController.setAdmin(userAddress, true);
  await sleep(constants.sleepSeconds);
  console.log("wooStakingController setAdmin: %s", userAddress);

  await wooStakingCompounder.setAdmin(userAddress, true);
  await sleep(constants.sleepSeconds);
  console.log("wooStakingCompounder setAdmin: %s", userAddress);

  await wooStakingProxy.setAdmin(userAddress, true);
  await sleep(constants.sleepSeconds);
  console.log("wooStakingProxy setAdmin: %s", userAddress);

  await wooStakingLocal.setAdmin(userAddress, true);
  await sleep(constants.sleepSeconds);
  console.log("wooStakingLocal setAdmin: %s", userAddress);
}

async function setupContracts() {
  const [
    stakingManager,
    mpRewarder,
    usdcRewarder,
    arbRewarder,
    booster,
    wooStakingCompounder,
    wooStakingController,
    wooStakingProxy,
    wooStakingLocal,
  ] = await getContracts();

  await wooStakingProxy.setTrustedRemoteAddress(
    constants.lz_chainid, wooStakingController.address,
  );
  await sleep(constants.sleepSeconds);
  console.log("wooStakingProxy.setTrustedRemoteAddress: %s", wooStakingController.address);


  await wooStakingController.setTrustedRemoteAddress(
    constants.lz_chainid, wooStakingProxy.address,
  );
  await sleep(constants.sleepSeconds);
  console.log("wooStakingController.setTrustedRemoteAddress: %s", wooStakingProxy.address);

  await stakingManager.setWooPP(constants.depAddressList["wooPP"]);
  await sleep(constants.sleepSeconds);
  console.log("setWooPP: %s", constants.depAddressList["wooPP"]);

  await stakingManager.setStakingLocal(wooStakingLocal.address);
  await sleep(constants.sleepSeconds);
  console.log("setStakingLocal: %s", wooStakingLocal.address);

  await stakingManager.setMPRewarder(mpRewarder.address);
  await sleep(constants.sleepSeconds);
  console.log("setMPRewarder: %s", mpRewarder.address);

  await stakingManager.setCompounder(wooStakingCompounder.address);
  await sleep(constants.sleepSeconds);
  console.log("setCompounder: %s", wooStakingCompounder.address);

  await stakingManager.addRewarder(usdcRewarder.address);
  await sleep(constants.sleepSeconds);
  console.log("add usdc rewarder: %s", usdcRewarder.address);

  await stakingManager.addRewarder(arbRewarder.address);
  await sleep(constants.sleepSeconds);
  console.log("add arb rewarder: %s", arbRewarder.address);

  await stakingManager.setAdmin(wooStakingController.address, true);
  await sleep(constants.sleepSeconds);
  console.log("staking manager setAdmin: %s", wooStakingController.address);

  await stakingManager.setAdmin(wooStakingCompounder.address, true);
  await sleep(constants.sleepSeconds);
  console.log("staking manager setAdmin: %s", wooStakingCompounder.address);

  await wooStakingCompounder.setAdmin(stakingManager.address, true);
  await sleep(constants.sleepSeconds);
  console.log("wooStakingCompounder setAdmin: %s", stakingManager.address);

  await mpRewarder.setBooster(booster.address);
  await sleep(constants.sleepSeconds);
  console.log("mprewarder setBooster: %s", booster.address);

  await booster.setMPRewarder(mpRewarder.address);
  await sleep(constants.sleepSeconds);
  console.log("booster setMPRewarder: %s", mpRewarder.address);

  await booster.setAutoCompounder(wooStakingCompounder.address);
  await sleep(constants.sleepSeconds);
  console.log("booster setAutoCompounder: %s", wooStakingCompounder.address);

  await wooStakingLocal.setAdmin(stakingManager.address, true);
  await sleep(constants.sleepSeconds);
  console.log("wooStakingLocal setAdmin: %s", stakingManager.address);

}

async function setupRewarders() {
  const [
    stakingManager,
    mpRewarder,
    usdcRewarder,
    arbRewarder,
    booster,
    wooStakingCompounder,
    wooStakingController,
    wooStakingProxy,
    wooStakingLocal,
  ] = await getContracts();

  let rewardPerBlock = 1;
  await usdcRewarder.setRewardPerBlock(rewardPerBlock);
  await sleep(constants.sleepSeconds);
  console.log("usdcRewarder setRewardPerBlock: %s", rewardPerBlock);

  rewardPerBlock = 1;
  await arbRewarder.setRewardPerBlock(rewardPerBlock);
  await sleep(constants.sleepSeconds);
  console.log("arbRewarder setRewardPerBlock: %s", rewardPerBlock);

  let rewardRate = 87600000;
  await mpRewarder.setRewardRate(rewardRate);
  await sleep(constants.sleepSeconds);
  console.log("mpRewarder setRewardRate: %s", rewardRate);

}

async function tempSetUserRatios() {
  const [
    stakingManager,
    mpRewarder,
    usdcRewarder,
    arbRewarder,
    booster,
    wooStakingCompounder,
    wooStakingController,
    wooStakingProxy,
    wooStakingLocal,
  ] = await getContracts();
  await booster.setUserRatios([constants.user2], [false], [false]);
  await sleep(constants.sleepSeconds);
  console.log("booster setUserRatios for user: %s", constants.user2);
}

async function main() {
  await setupContracts();
  await setupRewarders();
  // await setUserAdmin(constants.user1);
  await setUserAdmin(constants.user2);
  // await setUserAdmin(constants.user3);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});



