import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

// Deploys a copy of all the contracts
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { admin } = await getNamedAccounts();

  const baseDeployArgs = {
    from: admin,
    log: true,
    autoMine: hre.network.tags.test,
    // deterministicDeployment: !hre.network.tags.test,
    deterministicDeployment: false,
  };

  const usdc = await deploy("USDC", {
    ...baseDeployArgs,
    args: [],
  });

  const woo = await deploy("TestingWoo", {
    ...baseDeployArgs,
    args: [],
  });

  const esWoo = await deploy("EsWoo", {
    ...baseDeployArgs,
    args: [],
  });

  const bnWoo = await deploy("BnWoo", {
    ...baseDeployArgs,
    args: [],
  });

  const sWooRT = await deploy("SWooRewardTracker", {
    ...baseDeployArgs,
    args: ["Staked Woo", "sWoo"],
  });

  const sbWooRT = await deploy("SbWooRewardTracker", {
    ...baseDeployArgs,
    args: ["Staked + Bonus Woo", "sbWoo"],
  });

  const sbfWooRT = await deploy("SbfWooRewardTracker", {
    ...baseDeployArgs,
    args: ["Staked + Bonus + Fee Woo", "sbfWoo"],
  });

  const sWooDistributor = await deploy("SWooRewardDistributor", {
    ...baseDeployArgs,
    args: [esWoo.address, sWooRT.address],
  });

  const sbWooDistributor = await deploy("SbWooBonusDistributor", {
    ...baseDeployArgs,
    args: [bnWoo.address, sbWooRT.address],
  });

  const sbfWooDistributor = await deploy("SbfWooRewardDistributor", {
    ...baseDeployArgs,
    args: [usdc.address, sbfWooRT.address],
  });

  const rewardRouter = await deploy("RewardRouter", {
    ...baseDeployArgs,
    args: [],
  });

  const wooStakingManager = await deploy("WooStakingManager", {
    ...baseDeployArgs,
    args: [sbWooRT.address],
  });

  const uranusNFT = await deploy("UranusNFT", {
    ...baseDeployArgs,
    args: [wooStakingManager.address],
  });

  const neptuneNFT = await deploy("NeptuneNFT", {
    ...baseDeployArgs,
    args: [wooStakingManager.address],
  });

  const plutoNFT = await deploy("PlutoNFT", {
    ...baseDeployArgs,
    args: [wooStakingManager.address],
  });

  console.log("USDC:", usdc.address);
  console.log("Woo:", woo.address);
  console.log("EsWoo:", esWoo.address);
  console.log("BnWoo:", bnWoo.address);
  console.log("sWoo:", sWooRT.address);
  console.log("sbWoo:", sbWooRT.address);
  console.log("sbfWoo:", sbfWooRT.address);
  console.log("sWooDist:", sWooDistributor.address);
  console.log("sbWooDist:", sbWooDistributor.address);
  console.log("sbfWooDist:", sbfWooDistributor.address);
  console.log("RewardRouter:", rewardRouter.address);
  console.log("wooStakingManager:", wooStakingManager.address);
  console.log("UranusNFT:", uranusNFT.address);
  console.log("NeptuneNFT:", neptuneNFT.address);
  console.log("PlutoNFT:", plutoNFT.address);

  console.log("Finished running 001-deploy-contracts");

  return true;
};
func.id = "001-deploy-contracts";
export default func;
