import { expect } from "chai";
import { Signer } from "ethers";
import { deployments, ethers, getNamedAccounts } from "hardhat";
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
import { fastForward, getTokenAmount, latestTime } from "./utils";

let admin: Signer;
let user: Signer;

let adminAddr: string;
let userAddr: string;

let usdc: USDC;
let woo: TestingWoo;
let esWoo: EsWoo;
let bnWoo: BnWoo;
let sWooRT: SWooRewardTracker;
let sbWooRT: SbWooRewardTracker;
let sbfWooRT: SbfWooRewardTracker;
let sWooRD: SWooRewardDistributor;
let sbWooRD: SbWooBonusDistributor;
let sbfWooRD: SbfWooRewardDistributor;
let rewardRouter: RewardRouter;
let wooSM: WooStakingManager;
let uranus: UranusNFT;
let neptune: NeptuneNFT;
let pluto: PlutoNFT;

let usdcAddr: string;
let wooAddr: string;
let esWooAddr: string;
let bnWooAddr: string;
let sWooRTAddr: string;
let sbWooRTAddr: string;
let sbfWooRTAddr: string;
let sWooRDAddr: string;
let sbWooRDAddr: string;
let sbfWooRDAddr: string;
let rewardRouterAddr: string;
let wooSMAddr: string;
let uranusAddr: string;
let neptuneAddr: string;
let plutoAddr: string;

const TOKEN_1000 = getTokenAmount("1000");
const ONE_ETHER = ethers.constants.WeiPerEther;
const MINTING_COST = ethers.constants.WeiPerEther.div(100);

beforeEach("load deployment fixture", async function () {
  ({ admin, user } = await ethers.getNamedSigners());
  ({ admin: adminAddr, user: userAddr } = await getNamedAccounts());

  await deployments.fixture();

  usdc = await ethers.getContract("USDC");
  woo = await ethers.getContract("TestingWoo");
  esWoo = await ethers.getContract("EsWoo");
  bnWoo = await ethers.getContract("BnWoo");
  sWooRT = await ethers.getContract("SWooRewardTracker");
  sbWooRT = await ethers.getContract("SbWooRewardTracker");
  sbfWooRT = await ethers.getContract("SbfWooRewardTracker");
  sWooRD = await ethers.getContract("SWooRewardDistributor");
  sbWooRD = await ethers.getContract("SbWooBonusDistributor");
  sbfWooRD = await ethers.getContract("SbfWooRewardDistributor");
  rewardRouter = await ethers.getContract("RewardRouter");
  wooSM = await ethers.getContract("WooStakingManager");
  uranus = await ethers.getContract("UranusNFT");
  neptune = await ethers.getContract("NeptuneNFT");
  pluto = await ethers.getContract("PlutoNFT");

  usdcAddr = usdc.address;
  wooAddr = woo.address;
  esWooAddr = esWoo.address;
  bnWooAddr = bnWoo.address;
  sWooRTAddr = sWooRT.address;
  sbWooRTAddr = sbWooRT.address;
  sbfWooRTAddr = sbfWooRT.address;
  sWooRDAddr = sWooRD.address;
  sbWooRDAddr = sbWooRD.address;
  sbfWooRDAddr = sbfWooRD.address;
  rewardRouterAddr = rewardRouter.address;
  wooSMAddr = wooSM.address;
  uranusAddr = uranus.address;
  neptuneAddr = neptune.address;
  plutoAddr = pluto.address;
});

describe("Woo", function () {
  beforeEach(async () => {
    await woo.mint(adminAddr, TOKEN_1000);
  });

  describe("deployment", () => {
    it("Should set the right parameters", async function () {
      expect(await woo.name()).to.equal("Testing Woo");
      expect(await woo.symbol()).to.equal("tWoo");
      expect(await woo.id()).to.equal("tWoo");
      expect(await woo.balanceOf(adminAddr)).to.equal(TOKEN_1000);
      expect(await woo.totalSupply()).to.equal(TOKEN_1000);
    });
  });
});

describe("esWoo", function () {
  describe("deployment", () => {
    it("Should set the right parameters", async function () {
      expect(await esWoo.name()).to.equal("Escrowed Woo");
      expect(await esWoo.symbol()).to.equal("esWoo");
      expect(await esWoo.id()).to.equal("esWoo");
      expect(await esWoo.balanceOf(adminAddr)).to.equal(0);
      expect(await esWoo.totalSupply()).to.equal(0);
    });
  });
});

describe("bnWoo", function () {
  describe("deployment", () => {
    it("Should set the right parameters", async function () {
      expect(await bnWoo.name()).to.equal("Bonus Woo");
      expect(await bnWoo.symbol()).to.equal("bnWoo");
      expect(await bnWoo.id()).to.equal("bnWoo");
      expect(await bnWoo.balanceOf(adminAddr)).to.equal(0);
      expect(await bnWoo.totalSupply()).to.equal(TOKEN_1000);
    });
  });
});

describe("sWooRewardTracker", function () {
  describe("deployment", () => {
    it("Should set the right parameters", async function () {
      expect(await sWooRT.name()).to.equal("Staked Woo");
      expect(await sWooRT.symbol()).to.equal("sWoo");
      expect(await sWooRT.totalSupply()).to.equal(0);
      expect(await sWooRT.cumulativeRewardPerToken()).to.equal(0);
      expect(await sWooRT.decimals()).to.equal(18);
      expect(await sWooRT.distributor()).to.equal(sWooRDAddr);
      expect(await sWooRT.isDepositToken(wooAddr)).to.equal(true);
      expect(await sWooRT.isDepositToken(esWooAddr)).to.equal(true);
      expect(await sWooRT.isHandler(sbWooRTAddr)).to.equal(true);
      expect(await sWooRT.isHandler(rewardRouterAddr)).to.equal(true);
      const states = await sWooRT.boolStates();
      expect(states.isInitialized).to.equal(true);
      expect(states.inPrivateTransferMode).to.equal(true);
      expect(states.inPrivateStakingMode).to.equal(true);
      expect(states.inPrivateClaimingMode).to.equal(false);
      expect(states.inExternalRewardingMode).to.equal(false);
    });
  });
});

describe("sbWooRewardTracker", function () {
  describe("deployment", () => {
    it("Should set the right parameters", async function () {
      expect(await sbWooRT.name()).to.equal("Staked + Bonus Woo");
      expect(await sbWooRT.symbol()).to.equal("sbWoo");
      expect(await sbWooRT.totalSupply()).to.equal(0);
      expect(await sbWooRT.decimals()).to.equal(18);
    });
  });
});

describe("sbWooRewardDistributor", function () {
  describe("deployment", () => {
    it("Should set the right parameters", async function () {
      expect(await sbWooRD.BASIS_POINTS_DIVISOR()).to.equal(10000);
      expect(await sbWooRD.BONUS_DURATION()).to.equal(365 * 24 * 3600);
      expect(await sbWooRD.tokensPerInterval()).to.equal(0);
      expect(await sbWooRD.bonusMultiplierBasisPoints()).to.equal(10000);
      expect(await bnWoo.balanceOf(sbWooRDAddr)).to.equal(TOKEN_1000);
    });
  });
});

describe("sbfWooRewardTracker", function () {
  describe("deployment", () => {
    it("Should set the right parameters", async function () {
      expect(await sbfWooRT.name()).to.equal("Staked + Bonus + Fee Woo");
      expect(await sbfWooRT.symbol()).to.equal("sbfWoo");
      expect(await sbfWooRT.totalSupply()).to.equal(0);
      expect(await sbfWooRT.decimals()).to.equal(18);
    });
  });
});

describe("sbfWooRewardDistributor", function () {
  describe("deployment", () => {
    it("Should set the right parameters", async function () {
      expect(await sbfWooRD.rewardToken()).to.equal(usdcAddr);
      expect(await sbfWooRD.tokensPerInterval()).to.equal(550595238095238);
      expect(await usdc.balanceOf(sbfWooRDAddr)).to.equal(
        getTokenAmount("1000000")
      );
    });
  });
});

describe("WooStakingNFT", function () {
  describe("deployment", () => {
    it("Should set the right parameters", async function () {
      expect(await uranus.name()).to.equal("WooFi UranusNFT");
      expect(await uranus.symbol()).to.equal("WU-NFT");
      expect(await uranus.MAX_SUPPLY()).to.equal(10000);
      expect(await uranus.MINTING_FEE()).to.equal(MINTING_COST);
      expect(await uranus.stakingManager()).to.equal(wooSMAddr);
      expect(await uranus.totalSupply()).to.equal(0);
      expect(await neptune.name()).to.equal("WooFi NeptuneNFT");
      expect(await neptune.symbol()).to.equal("WN-NFT");
      expect(await neptune.MAX_SUPPLY()).to.equal(10000);
      expect(await neptune.MINTING_FEE()).to.equal(MINTING_COST);
      expect(await neptune.stakingManager()).to.equal(wooSMAddr);
      expect(await neptune.totalSupply()).to.equal(0);
      expect(await pluto.name()).to.equal("WooFi PlutoNFT");
      expect(await pluto.symbol()).to.equal("WP-NFT");
      expect(await pluto.MAX_SUPPLY()).to.equal(10000);
      expect(await pluto.MINTING_FEE()).to.equal(MINTING_COST);
      expect(await pluto.stakingManager()).to.equal(wooSMAddr);
      expect(await pluto.totalSupply()).to.equal(0);
    });
  });
  describe("Mint NFTs", () => {
    it("Should set the right parameters", async function () {
      await uranus.connect(user).safeMint({ value: MINTING_COST });
      expect(await uranus.totalSupply()).to.equal(1);
      expect(await uranus.balanceOf(userAddr)).to.equal(1);
      const [amount, duration] = await uranus.callStatic.getEffect(0);
      expect(amount).to.equal(1200000);
      expect(duration).to.equal(7257600);
      expect(await uranus.balanceOf(userAddr)).to.equal(1);
      await expect(uranus.consume(0)).to.be.revertedWith("Only manager");
    });
  });
});

describe("RewardRouter", function () {
  beforeEach(async () => {
    await woo.mint(adminAddr, TOKEN_1000);
    await woo.mint(userAddr, TOKEN_1000);
    await woo.connect(user).approve(sWooRTAddr, TOKEN_1000);
    await sWooRT.connect(user).approve(sbWooRTAddr, TOKEN_1000);
    await sbWooRT.connect(user).approve(sbfWooRTAddr, TOKEN_1000);
    await pluto.connect(admin).safeMint({ value: MINTING_COST });
    await pluto.connect(user).safeMint({ value: MINTING_COST });
  });
  describe("deployment", () => {
    it("Should set the right parameters", async function () {
      const sWooBalance = await sWooRT.balanceOf(userAddr);
      const sbWooBalance = await sbWooRT.balanceOf(userAddr);
      const sbfWooBalance = await sbfWooRT.balanceOf(userAddr);
      const esWooBalance = await esWoo.balanceOf(userAddr);
      const bnWooBalance = await bnWoo.balanceOf(userAddr);
      expect(await pluto.totalSupply()).to.equal(2);
      expect(sWooBalance).to.equal(0);
      expect(sbWooBalance).to.equal(0);
      expect(sbfWooBalance).to.equal(0);
      expect(esWooBalance).to.equal(0);
      expect(bnWooBalance).to.equal(0);
    });
  });

  describe("Stake Woo tokens", () => {
    it("Should get the right amounts after staking", async function () {
      expect(await sWooRT.isHandler(rewardRouterAddr)).to.equal(true);
      expect(await sbWooRT.isHandler(rewardRouterAddr)).to.equal(true);
      expect(await sbfWooRT.isHandler(rewardRouterAddr)).to.equal(true);
      await rewardRouter.connect(user).stakeToken(TOKEN_1000);
      const sWooBalance = await sWooRT.balanceOf(userAddr);
      const sWooInsbWooBalance = await sWooRT.balanceOf(sbWooRT.address);
      expect(sWooBalance).to.equal(0); // sWoo tokens are moved to sbWoo.
      expect(sWooInsbWooBalance).to.equal(TOKEN_1000);
      const sWooStakedAmount = await sWooRT.stakedAmounts(userAddr);
      expect(sWooStakedAmount).to.equal(TOKEN_1000);
      const sbWooBalance = await sbWooRT.balanceOf(userAddr);
      expect(sbWooBalance).to.equal(0); // sbWoo tokens are moved to sbfWoo.
      const sbWooInsbfWooBalance = await sbWooRT.balanceOf(sbfWooRT.address);
      expect(sbWooInsbfWooBalance).to.equal(TOKEN_1000);
      const sbWooStakedAmount = await sbWooRT.stakedAmounts(userAddr);
      expect(sbWooStakedAmount).to.equal(TOKEN_1000);
      const sbfWooBalance = await sbfWooRT.balanceOf(userAddr);
      expect(sbfWooBalance).to.equal(TOKEN_1000);
      const sbfWooStakedAmount = await sbfWooRT.stakedAmounts(userAddr);
      expect(sbfWooStakedAmount).to.equal(TOKEN_1000);
      const esWooBalance = await esWoo.balanceOf(userAddr);
      expect(esWooBalance).to.equal(0);
      const bnWooBalance = await bnWoo.balanceOf(userAddr);
      expect(bnWooBalance).to.equal(0);
    });

    it("Happy path without any boosting effects", async function () {
      await rewardRouter.connect(user).stakeToken(TOKEN_1000);
      await sbWooRT.connect(admin).setInExternalRewardingMode(true);
      expect(await sbWooRT.claimable(userAddr)).to.not.equal(0);
      expect(await sbWooRT.claimableReward(userAddr)).to.equal(0);
      expect(await sbWooRT.claimable(userAddr)).to.not.equal(0);
      expect(await sbWooRT.claimableReward(userAddr)).to.equal(0);
      const sWooBalance = await sWooRT.balanceOf(userAddr);
      const sWooStakedAmount = await sWooRT.stakedAmounts(userAddr);
      expect(sWooStakedAmount).to.equal(TOKEN_1000);
      const sbWooBalance = await sbWooRT.balanceOf(userAddr);
      const sbWooStakedAmount = await sbWooRT.stakedAmounts(userAddr);
      expect(sbWooStakedAmount).to.equal(TOKEN_1000);
      const sbfWooBalance = await sbfWooRT.balanceOf(userAddr);
      const sbfWooStakedAmount = await sbfWooRT.stakedAmounts(userAddr);
      expect(sbfWooStakedAmount).to.equal(TOKEN_1000);
      const esWooBalance = await esWoo.balanceOf(userAddr);
      const bnWooBalance = await bnWoo.balanceOf(userAddr);

      expect(sWooBalance).to.equal(0);
      expect(sbWooBalance).to.equal(0);
      expect(sbfWooBalance).to.equal(TOKEN_1000);
      expect(esWooBalance).to.equal(0);
      expect(bnWooBalance).to.equal(0);
    });

    it("Should boost staking effects after consuming NFTs", async function () {
      await rewardRouter.connect(admin).stakeToken(TOKEN_1000);
      await rewardRouter.connect(user).stakeToken(TOKEN_1000);
      await sbWooRT.connect(admin).setInExternalRewardingMode(true);
      const [amount, expiry] = await pluto.getEffect(1);
      expect(amount).to.equal(1500000);
      expect(expiry).to.equal(2419200);
      await wooSM.connect(user).consumeNFTAndBoost(1, plutoAddr);
      const lastTime = await latestTime();
      const boosterInfo = await sbWooRT.boosterInfo(userAddr);
      expect(boosterInfo.multiplier).to.equal(1500000);
      expect(boosterInfo.expiry).to.equal(expiry.add(lastTime));

      const MPPriorUser = await sbWooRT.claimable(userAddr);
      const MPPriorAdmin = await sbWooRT.claimable(adminAddr);

      await fastForward(3600 * 24 * 20);
      const MPAfterUser = await sbWooRT.claimable(userAddr);
      const MPAfterAdmin = await sbWooRT.claimable(adminAddr);

      const MPDiffWithBoosting = MPAfterUser.sub(MPPriorUser);
      const MPDiffWithoutBoosting = MPAfterAdmin.sub(MPPriorAdmin);

      expect(MPDiffWithBoosting).to.equal(MPDiffWithoutBoosting.mul(3).div(2)); // 150% boosting
    });
  });
});
