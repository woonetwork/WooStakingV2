import { ethers, run } from "hardhat";
import {loadJsonFile, deploy, verify, sleep} from "./utils"
const constants = require("./constants");
const fs = require("fs");

async function deployProxyContract(endpoint: string, wooAddress: string) {
  // write all contract address to a local file
  const contracts = loadJsonFile();

  let stakingController = contracts["WooStakingController"];

  let contractName = "WooStakingProxy";
  let args = [
    endpoint,
    constants.lz_arbitrum_chainid,
    stakingController,
    wooAddress,
  ];
  const stakingProxy = await deploy(args, contractName);
  console.log(`${contractName} deployed to: ${stakingProxy}`);
  await sleep(constants.sleepSeconds);
  await verify(stakingProxy, args);

  const wooStakingProxy = await ethers.getContractAt(
    "WooStakingProxy", stakingProxy);
  
  let userAddress = constants.user2;
  await wooStakingProxy.setAdmin(userAddress, true);
  await sleep(constants.sleepSeconds);
  console.log("wooStakingProxy setAdmin: %s", userAddress);

  await wooStakingProxy.setTrustedRemoteAddress(
    constants.lz_arbitrum_chainid, stakingController,
  );
  await sleep(constants.sleepSeconds);
  console.log("wooStakingProxy.setTrustedRemoteAddress: %s", stakingController);
}

async function deployFantomProxy() {
  await deployProxyContract(constants.lz_fantom_endpoint, constants.fantomDepAddressList["woo"]);
}

async function deployBSCProxy() {
  await deployProxyContract(constants.lz_bsc_endpoint, constants.bscDepAddressList["woo"]);
}

async function deployAvalancheProxy() {
  await deployProxyContract(constants.lz_avalanche_endpoint, constants.avalancheDepAddressList["woo"]);
}

async function deployPolygonProxy() {
  await deployProxyContract(constants.lz_polygon_endpoint, constants.polygonDepAddressList["woo"]);
}

async function deployOPProxy() {
  await deployProxyContract(constants.lz_op_endpoint, constants.opDepAddressList["woo"]);
}

async function controllerAddProxy() {

  const contracts = loadJsonFile();
  let stakingController = contracts["WooStakingController"];
  const wooStakingController = await ethers.getContractAt(
    "WooStakingController", stakingController);
  
  const fantomProxy = contracts["FantomWooStakingProxy"];
  
  await wooStakingController.setTrustedRemoteAddress(
    constants.lz_fantom_chainid, fantomProxy,
  );
  await sleep(constants.sleepSeconds);
  console.log("fantom wooStakingController.setTrustedRemoteAddress: %s", fantomProxy);

  const bscProxy = contracts["BSCWooStakingProxy"];
  await wooStakingController.setTrustedRemoteAddress(
    constants.lz_bsc_chainid, bscProxy,
  );
  await sleep(constants.sleepSeconds);
  console.log("bsc wooStakingController.setTrustedRemoteAddress: %s", bscProxy);

  const avalancheProxy = contracts["AvalancheWooStakingProxy"];
  await wooStakingController.setTrustedRemoteAddress(
    constants.lz_avalanche_chainid, avalancheProxy,
  );
  await sleep(constants.sleepSeconds);
  console.log("avalanche wooStakingController.setTrustedRemoteAddress: %s", avalancheProxy);

  const polygonProxy = contracts["PolygonWooStakingProxy"];
  await wooStakingController.setTrustedRemoteAddress(
    constants.lz_polygon_chainid, polygonProxy,
  );
  await sleep(constants.sleepSeconds);
  console.log("ploygon wooStakingController.setTrustedRemoteAddress: %s", polygonProxy);

  const opProxy = contracts["OPWooStakingProxy"];
  await wooStakingController.setTrustedRemoteAddress(
    constants.lz_op_chainid, opProxy,
  );
  await sleep(constants.sleepSeconds);
  console.log("op wooStakingController.setTrustedRemoteAddress: %s", opProxy);
}

async function main() {
  // NOTE: mannually run this func.
  // await deployFantomProxy();

  // await deployBSCProxy();
  // await deployAvalancheProxy();
  // await deployPolygonProxy();
  // await deployOPProxy();

  await controllerAddProxy();

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});