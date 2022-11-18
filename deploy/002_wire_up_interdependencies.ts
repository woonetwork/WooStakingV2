import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import {
  USDC,
  TestingWoo,
  EsWoo,
  BnWoo,
  SWooRewardTracker,
  SbWooRewardTracker,
  SbfWooRewardTracker,
  SWooRewardDistributor,
  SbWooBonusDistributor,
  SbfWooRewardDistributor,
  RewardRouter,
  WooStakingManager,
  UranusNFT,
  NeptuneNFT,
  PlutoNFT,
} from "../typechain";

// Deploys a copy of all the contracts
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { ethers } = hre;
  const admin = await ethers.getNamedSigner("admin");

  const usdc = await ethers.getContract<USDC>("USDC");
  const woo = await ethers.getContract<TestingWoo>("TestingWoo");
  const esWoo = await ethers.getContract<EsWoo>("EsWoo");
  const bnWoo = await ethers.getContract<BnWoo>("BnWoo");
  const sWooRT = await ethers.getContract<SWooRewardTracker>(
    "SWooRewardTracker"
  );
  const sbWooRT = await ethers.getContract<SbWooRewardTracker>(
    "SbWooRewardTracker"
  );
  const sbfWooRT = await ethers.getContract<SbfWooRewardTracker>(
    "SbfWooRewardTracker"
  );
  const sWooDistributor = await ethers.getContract<SWooRewardDistributor>(
    "SWooRewardDistributor"
  );
  const sbWooDistributor = await ethers.getContract<SbWooBonusDistributor>(
    "SbWooBonusDistributor"
  );
  const sbfWooDistributor = await ethers.getContract<SbfWooRewardDistributor>(
    "SbfWooRewardDistributor"
  );
  const wooStakingManager = await ethers.getContract<WooStakingManager>(
    "WooStakingManager"
  );
  const uranusNFT = await ethers.getContract<UranusNFT>("UranusNFT");
  const neptuneNFT = await ethers.getContract<NeptuneNFT>("NeptuneNFT");
  const plutoNFT = await ethers.getContract<PlutoNFT>("PlutoNFT");

  const rewardRouter = await ethers.getContract<RewardRouter>("RewardRouter");
  await rewardRouter.initialize(
    usdc.address,
    woo.address,
    esWoo.address,
    bnWoo.address,
    sWooRT.address,
    sbWooRT.address,
    sbfWooRT.address
  );

  await sWooRT.initialize(
    [woo.address, esWoo.address],
    sWooDistributor.address
  );

  await sbWooRT.initialize(
    [sWooRT.address],
    sbWooDistributor.address,
    wooStakingManager.address
  );

  await sbfWooRT.initialize(
    [sbWooRT.address, bnWoo.address],
    sbfWooDistributor.address
  );

  await wooStakingManager.addNFTContract(uranusNFT.address);
  await wooStakingManager.addNFTContract(neptuneNFT.address);
  await wooStakingManager.addNFTContract(plutoNFT.address);

  console.log("Finished running 002-wire-up-interdependencies");

  return true;
};
func.id = "002-wire-up-interdependencies";
export default func;
