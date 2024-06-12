import {deploy, verify, sleep} from "../utils";
import { ethers, run } from "hardhat";
const constants = require("../constants");


async function deployRewardNFT() {
  // let rewardNft = "0x06c7E4cdd71A9fd637b92CA23f57aB6f924E336B";
  // let args = [rewardNft];
  // let contractName = "NftBoosterV2";
  // const nftBoosterV2 = await deploy(args, contractName);
  // console.log(`${contractName} deployed to: ${nftBoosterV2}`);
  // await sleep(constants.sleepSeconds);
  // await verify(nftBoosterV2, args);

  let stakingManager = "0x297ad025479bb63E48928B4aB2Bd3696FD24D25B";

  let contractName = "RewardNFT";
  const rewardNFT = await deploy(["BoosterTest"], contractName);
  console.log(`${contractName} deployed to: ${rewardNFT}`);
  await sleep(constants.sleepSeconds);
  await verify(rewardNFT, []);
}

async function deployRewardBooster() {
  // mpRewarder 需要设置reward booster
  let contractName = "RewardBooster";
  let mpRewarder = "0xD0e03Dd57A5486387D5f625440619535aB503fE3";
  let compounder = "0x573bE4c3C8863cd966C2Ed916E629DE7a9F6EaA5";
  let nftBooster = "0xB42A4E437cf407056a5e7998dA5Da1d280B2Adf1";
  let args = [mpRewarder, compounder, nftBooster];
  const rewardBooster = await deploy(args, contractName);
  console.log(`${contractName} deployed to: ${rewardBooster}`);
  await sleep(constants.sleepSeconds);
  await verify(rewardBooster, args);
}

async function deployRewardBoosterV2() {
  let stakingManager = "0x297ad025479bb63E48928B4aB2Bd3696FD24D25B";

  let contractName = "RewardNFT";
  const rewardNFT = await deploy([], contractName);
  console.log(`${contractName} deployed to: ${rewardNFT}`);
  await sleep(constants.sleepSeconds);
  await verify(rewardNFT, []);

  contractName = "NFTBoosterV2";
  let args = [rewardNFT, stakingManager];
  const nftBoosterV2 = await deploy(args, contractName);
  console.log(`${contractName} deployed to: ${nftBoosterV2}`);
  await sleep(constants.sleepSeconds);
  await verify(nftBoosterV2, args);

  contractName = "RewardBooster";
  let mpRewarder = "0xD0e03Dd57A5486387D5f625440619535aB503fE3";
  let compounder = "0x573bE4c3C8863cd966C2Ed916E629DE7a9F6EaA5";
  args = [mpRewarder, compounder, nftBoosterV2];
  const rewardBooster = await deploy(args, contractName);
  console.log(`${contractName} deployed to: ${rewardBooster}`);
  await sleep(constants.sleepSeconds);
  await verify(rewardBooster, args);

  // MPRewarder需要设置rewardBooster
  // RewardCampaignManager需要设置rewardNFT

}

async function deployRewardCampaignManager() {
  let contractName = "RewardCampaignManager";
  let rewardNFT = "0xC410C1e255e76b89E746Ea83219D42E335Eab62B";
  let args = [rewardNFT];
  const rewardCampaignManager = await deploy(args, contractName);
  console.log(`${contractName} deployed to: ${rewardCampaignManager}`);
  await sleep(constants.sleepSeconds);
  await verify(rewardCampaignManager, args);
}

async function main() {
  await debugTokenIds();
  // let stakingManager = "0x297ad025479bb63E48928B4aB2Bd3696FD24D25B";

  // let rewardNFT = "0xC410C1e255e76b89E746Ea83219D42E335Eab62B";
  // await verify(rewardNFT, []);

  // let nftBoosterV2 = "0xB42A4E437cf407056a5e7998dA5Da1d280B2Adf1";
  // await verify(nftBoosterV2, [rewardNFT, stakingManager]);

  // let mpRewarder = "0xD0e03Dd57A5486387D5f625440619535aB503fE3";
  // let compounder = "0x573bE4c3C8863cd966C2Ed916E629DE7a9F6EaA5";
  // let args = [mpRewarder, compounder, nftBoosterV2];

  // let rewardBooster = "0x2839D28B115E14a38962981d88a8eafF7C626C4a";
  // await verify(rewardBooster, args);
}

async function debugTokenIds() {
  let rewardBooster = "0x2839D28B115E14a38962981d88a8eafF7C626C4a";
  const rewardBoosterContract = await ethers.getContractAt(
    "RewardBooster", rewardBooster);

  let result = await rewardBoosterContract.userBoostRatioDetail("0x47fc45CEBFc47Cef07a09A98405B6EBAeF00ef75");
  console.log(result);
}


  
// main().catch((error) => {
//   console.error(error);
//   process.exitCode = 1;
// });

deployRewardNFT().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});