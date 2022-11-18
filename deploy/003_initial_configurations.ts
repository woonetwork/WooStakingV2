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
  RewardRouter,
  SWooRewardDistributor,
  SbWooBonusDistributor,
  SbfWooRewardDistributor,
} from "../typechain";

// Deploys a copy of all the contracts
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { ethers } = hre;
  const admin = await ethers.getNamedSigner("admin");
  const adminAddr = admin.address;

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
  const rewardRouter = await ethers.getContract<RewardRouter>("RewardRouter");

  await usdc.transfer(
    sbfWooDistributor.address,
    ethers.utils.parseEther("1000000")
  );
  await woo.setMinter(adminAddr, true);
  await bnWoo.setMinter(adminAddr, true);
  await bnWoo.setMinter(rewardRouter.address, true);
  await bnWoo.mint(adminAddr, ethers.utils.parseEther("1000"));
  await bnWoo.transfer(
    sbWooDistributor.address,
    ethers.utils.parseEther("1000")
  );
  await esWoo.setMinter(adminAddr, true);

  await woo.setHandler(sWooRT.address, true);
  await woo.setHandler(rewardRouter.address, true);
  await bnWoo.setHandler(sbfWooRT.address, true);
  await sWooRT.setHandler(adminAddr, true);
  await sWooRT.setHandler(rewardRouter.address, true);
  await sWooRT.setHandler(sbWooRT.address, true); // This can by-pass checking allowance
  await sWooRT.setInPrivateTransferMode(true);
  await sWooRT.setInPrivateStakingMode(true);
  await sbWooRT.setHandler(adminAddr, true);
  await sbWooRT.setHandler(rewardRouter.address, true);
  await sbWooRT.setHandler(sbfWooRT.address, true);
  await sbWooRT.setInPrivateClaimingMode(true);
  await sbWooRT.setInPrivateTransferMode(true);
  await sbWooRT.setInPrivateStakingMode(true);
  await sbfWooRT.setHandler(adminAddr, true);
  await sbfWooRT.setHandler(rewardRouter.address, true);
  await sbfWooRT.setInPrivateTransferMode(true);
  await sbfWooRT.setInPrivateTransferMode(true);
  await sbfWooRT.setInPrivateStakingMode(true);

  await sWooDistributor.setAdmin(adminAddr);
  await sbWooDistributor.setAdmin(adminAddr);
  await sbfWooDistributor.setAdmin(adminAddr);
  await sWooDistributor.updateLastDistributionTime();
  await sWooDistributor.setTokensPerInterval("0");
  await sbWooDistributor.updateLastDistributionTime();
  await sbWooDistributor.setBonusMultiplier(10000);
  await sbfWooDistributor.updateLastDistributionTime();
  await sbfWooDistributor.setTokensPerInterval("550595238095238");

  console.log("Finished running 003-initial-configurations");

  return true;
};
func.id = "003-initial-configurations";
export default func;
