/*
░██╗░░░░░░░██╗░█████╗░░█████╗░░░░░░░███████╗██╗
░██║░░██╗░░██║██╔══██╗██╔══██╗░░░░░░██╔════╝██║
░╚██╗████╗██╔╝██║░░██║██║░░██║█████╗█████╗░░██║
░░████╔═████║░██║░░██║██║░░██║╚════╝██╔══╝░░██║
░░╚██╔╝░╚██╔╝░╚█████╔╝╚█████╔╝░░░░░░██║░░░░░██║
░░░╚═╝░░░╚═╝░░░╚════╝░░╚════╝░░░░░░░╚═╝░░░░░╚═╝
*
* MIT License
* ===========
*
* Copyright (c) 2020 WooTrade
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import { expect } from "chai";
import { BigNumber, Contract, utils, Wallet } from 'ethers'
import { ethers } from "hardhat";
import { deployContract, deployMockContract } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
const { mine, time, mineUpTo } = require("@nomicfoundation/hardhat-network-helpers");

import { MpRewarder, RewardBooster, SimpleRewarder, TestWooPP, WooStakingCompounder, WooStakingManager } from "../../typechain";
import SimpleRewarderArtifact from "../../artifacts/contracts/rewarders/SimpleRewarder.sol/SimpleRewarder.json";
import MpRewarderArtifact from "../../artifacts/contracts/rewarders/MpRewarder.sol/MpRewarder.json";
import WooStakingManagerArtifact from "../../artifacts/contracts/WooStakingManager.sol/WooStakingManager.json";
import TestTokenArtifact from "../../artifacts/contracts/test/TestToken.sol/TestToken.json";
import WooStakingLocalArtifact from "../../artifacts/contracts/WooStakingLocal.sol/WooStakingLocal.json";
import IWooPPV2Artifact from "../../artifacts/contracts/interfaces/IWooPPV2.sol/IWooPPV2.json";
import RewardBoosterArtifact from "../../artifacts/contracts/rewarders/RewardBooster.sol/RewardBooster.json";
import TestWooPPArtifact from "../../artifacts/contracts/test/TestWooPP.sol/TestWooPP.json";
import WooStakingCompounderArtifact from "../../artifacts/contracts/WooStakingCompounder.sol/WooStakingCompounder.json";
import IWooStakingCompounder from "../../artifacts/contracts/interfaces/IWooStakingCompounder.sol/IWooStakingCompounder.json";

const ZERO_ADDR = '0x0000000000000000000000000000000000000000'

describe("WooStakingManager tests", () => {

    let owner: SignerWithAddress;

    let booster: RewardBooster;
    let mpRewarder: MpRewarder;
    let rewarder1: SimpleRewarder;
    let rewarder2: SimpleRewarder;
    let stakingManager: WooStakingManager;
    let testWooPP: TestWooPP;
    let stakingCompounder: WooStakingCompounder;

    let wooPPv2: Contract;
    let local: Contract;
    let compounder: Contract;

    let user: SignerWithAddress;
    let user1: SignerWithAddress;
    let user2: SignerWithAddress;

    let wooToken: Contract;
    let usdcToken: Contract;
    let wethToken: Contract;

    before(async () => {
        [owner] = await ethers.getSigners();
        wooToken = await deployContract(owner, TestTokenArtifact, []);
        usdcToken = await deployContract(owner, TestTokenArtifact, []);
        wethToken = await deployContract(owner, TestTokenArtifact, []);

        wooPPv2 = await deployMockContract(owner, IWooPPV2Artifact.abi);
        await wooPPv2.mock.swap.returns(10000);

        compounder = await deployMockContract(owner, IWooStakingCompounder.abi);
        await compounder.mock.contains.returns(true);

        testWooPP = (await deployContract(owner, TestWooPPArtifact, [])) as TestWooPP;
        await testWooPP.setPrice(usdcToken.address, utils.parseEther("1"));
        await testWooPP.setPrice(wethToken.address, utils.parseEther("1700"));
        await testWooPP.setPrice(wooToken.address, utils.parseEther("0.2"));
        await wooToken.mint(testWooPP.address, utils.parseEther("100000"));
        await usdcToken.mint(testWooPP.address, utils.parseEther("100000"));
        await wethToken.mint(testWooPP.address, utils.parseEther("1000"));

        local = await deployMockContract(owner, WooStakingLocalArtifact.abi);
        await local.mock.stake.returns();
    });

    beforeEach(async () => {
        [user, user1, user2] = await ethers.getSigners();

        stakingManager = (await deployContract(owner, WooStakingManagerArtifact, [wooToken.address])) as WooStakingManager;

        await stakingManager.setWooPP(wooPPv2.address);
        await stakingManager.setStakingLocal(local.address);

        rewarder1 = (await deployContract(owner, SimpleRewarderArtifact, [usdcToken.address, stakingManager.address])) as SimpleRewarder;
        await usdcToken.mint(rewarder1.address, utils.parseEther("1000000"));
        await stakingManager.addRewarder(rewarder1.address);
        await rewarder1.setAdmin(stakingManager.address, true);

        rewarder2 = (await deployContract(owner, SimpleRewarderArtifact, [wethToken.address, stakingManager.address])) as SimpleRewarder;
        await wethToken.mint(rewarder2.address, utils.parseEther("3000"));
        await stakingManager.addRewarder(rewarder2.address);
        await rewarder2.setAdmin(stakingManager.address, true);

        mpRewarder = (await deployContract(owner, MpRewarderArtifact, [wooToken.address, stakingManager.address])) as MpRewarder;
        await mpRewarder.setAdmin(stakingManager.address, true);

        booster = (await deployContract(owner, RewardBoosterArtifact, [mpRewarder.address, compounder.address])) as RewardBooster;
        await mpRewarder.setBooster(booster.address);

        await stakingManager.setMPRewarder(mpRewarder.address);

        stakingCompounder = (await deployContract(owner, WooStakingCompounderArtifact, [stakingManager.address])) as WooStakingCompounder;
        await stakingManager.setCompounder(stakingCompounder.address);
    });

    it("Init Tests", async () => {
        expect(await stakingManager.woo()).to.be.eq(wooToken.address);
        expect(await stakingManager.wooPP()).to.be.eq(wooPPv2.address);
        expect(await stakingManager.stakingLocal()).to.be.eq(local.address);
        expect(await stakingManager.owner()).to.be.eq(owner.address);
        expect(await stakingManager.mpRewarder()).to.be.eq(mpRewarder.address);
    });

    it("Permission Tests", async () => {
        await stakingManager.setWooPP(ZERO_ADDR); // owner has the permission

         // permission failed: !owner
        await expect(stakingManager.connect(user1).setWooPP(ZERO_ADDR)).to.be.revertedWith("Ownable: caller is not the owner");
        await expect(stakingManager.connect(user1).setStakingLocal(ZERO_ADDR)).to.be.revertedWith("Ownable: caller is not the owner");

        // permission failed: !admin
        await expect(stakingManager.connect(user1).setMPRewarder(ZERO_ADDR)).to.be.revertedWith("BaseAdminOperation: !admin");
        await expect(stakingManager.connect(user1).addRewarder(ZERO_ADDR)).to.be.revertedWith("BaseAdminOperation: !admin");
        await expect(stakingManager.connect(user1).removeRewarder(ZERO_ADDR)).to.be.revertedWith("BaseAdminOperation: !admin");
        await expect(stakingManager.connect(user1).stakeWoo(user2.address, 100)).to.be.revertedWith("BaseAdminOperation: !admin");
        await expect(stakingManager.connect(user1).unstakeWoo(owner.address, 100)).to.be.revertedWith("BaseAdminOperation: !admin");
        await expect(stakingManager.connect(user1)["claimRewards(address)"](user1.address)).to.be.revertedWith("BaseAdminOperation: !admin");

        await expect(stakingManager.connect(user1).compoundAll(owner.address)).to.be.revertedWith("BaseAdminOperation: !admin");
        await expect(stakingManager.connect(user1).compoundMP(owner.address)).to.be.revertedWith("BaseAdminOperation: !admin");
        await expect(stakingManager.connect(user1).compoundRewards(owner.address)).to.be.revertedWith("BaseAdminOperation: !admin");

        await stakingManager.connect(user1)["claimRewards()"](); // open permission
    });

    it("Stake Tests", async () => {
        await rewarder1.setRewardPerBlock(utils.parseEther("20"));      // usdc 20
        await rewarder2.setRewardPerBlock(utils.parseEther("1"));       // weth 1
        await mpRewarder.setRewardRate(31536000 * 100);                 // 1% per second

        expect(await stakingManager.wooTotalBalance()).to.be.eq(0);
        expect(await stakingManager.mpTotalBalance()).to.be.eq(0);

        await stakingManager.stakeWoo(user1.address, utils.parseEther("10"));
        await stakingManager.stakeWoo(user2.address, utils.parseEther("20"));

        expect(await stakingManager.wooTotalBalance()).to.be.eq(utils.parseEther("30"));
        expect(await stakingManager.mpTotalBalance()).to.be.eq(0);

        await stakingManager.stakeWoo(user1.address, utils.parseEther("30"));

        expect(await stakingManager.wooTotalBalance()).to.be.eq(utils.parseEther("60"));
        expect(await stakingManager.mpTotalBalance()).to.be.gt(0);  // NOTE: mp auto compounds

        expect(await stakingManager.wooBalance(user1.address)).to.be.eq(utils.parseEther("40"));
        expect(await stakingManager.wooBalance(user2.address)).to.be.eq(utils.parseEther("20"));
    });

    it("Unstake Tests", async () => {
        await rewarder1.setRewardPerBlock(utils.parseEther("20"));  // usdc 20
        await rewarder2.setRewardPerBlock(utils.parseEther("1"));   // weth 1
        await mpRewarder.setRewardRate(31536000 * 100);             // 1% per second

        expect(await stakingManager.wooTotalBalance()).to.be.eq(0);
        expect(await stakingManager.mpTotalBalance()).to.be.eq(0);

        await stakingManager.stakeWoo(user1.address, utils.parseEther("10"));
        await stakingManager.stakeWoo(user2.address, utils.parseEther("20"));
        await stakingManager.stakeWoo(user1.address, utils.parseEther("30"));

        expect(await stakingManager.wooBalance(user1.address)).to.be.eq(utils.parseEther("40"));
        expect(await stakingManager.wooBalance(user2.address)).to.be.eq(utils.parseEther("20"));

        await stakingManager.unstakeWoo(user1.address, utils.parseEther("10"));
        await stakingManager.unstakeWoo(user2.address, utils.parseEther("20"));

        expect(await stakingManager.wooBalance(user1.address)).to.be.eq(utils.parseEther("30"));
        expect(await stakingManager.wooBalance(user2.address)).to.be.eq(utils.parseEther("0"));

        expect(await stakingManager.wooTotalBalance()).to.be.eq(utils.parseEther("30"));
        expect(await stakingManager.mpTotalBalance()).to.be.gt(0);  // mp auto compounds

        await expect(stakingManager.unstakeWoo(user1.address, utils.parseEther("40"))).to.be.reverted;
        await expect(stakingManager.unstakeWoo(user2.address, 1)).to.be.reverted;
    });

    it("pendingRewards Tests", async () => {

        await _logUserPending();

        await rewarder1.setRewardPerBlock(utils.parseEther("20"));      // usdc 20
        await rewarder2.setRewardPerBlock(utils.parseEther("1"));       // weth 1
        await mpRewarder.setRewardRate(31536000 * 100);   // 1% per second

        await stakingManager.stakeWoo(user1.address, utils.parseEther("10"));
        await stakingManager.stakeWoo(user2.address, utils.parseEther("20"));

        await _logUserPending();

        await stakingManager.stakeWoo(user1.address, utils.parseEther("10"));

        await _logUserPending();

        console.log(" accTokenPerShare: ", utils.formatEther(await rewarder1.accTokenPerShare()) + "\n\n");

        await mine(1); // mine 1 blocks, new usdc = 20, eth = 1, mp = 100

        await _logUserPending();    // block 28

        await stakingManager.compoundAll(user1.address);

        await _logUserPending();    // block 29

        await stakingManager.compoundAll(user2.address);

        await _logUserPending();    // block 30

        await mine(10);

        await _logUserPending();    // block 40


        console.log("\n --- Claim --- \n");
        await _logUserBals();
        expect(await usdcToken.balanceOf(user1.address)).to.be.eq(0);
        expect(await wethToken.balanceOf(user1.address)).to.be.eq(0);
        expect(await usdcToken.balanceOf(user2.address)).to.be.eq(0);
        expect(await wethToken.balanceOf(user2.address)).to.be.eq(0);
        await stakingManager["claimRewards(address)"](user1.address);
        await stakingManager["claimRewards(address)"](user2.address); // one block reward purely for user2
        await _logUserBals();
        expect(await wethToken.balanceOf(user1.address)).to.be.gt(0);
        expect(await usdcToken.balanceOf(user1.address)).to.be.gt(0);
        expect(await wethToken.balanceOf(user2.address)).to.be.gt(0);
        expect(await usdcToken.balanceOf(user2.address)).to.be.gt(0);
    });

    it("CompundRewards Tests", async () => {
        console.log("woo: %s usdc: %s weth: %s ",
            wooToken.address, usdcToken.address, wethToken.address);
        let user1Bal = await usdcToken.balanceOf(user1.address);
        let user2Bal = await usdcToken.balanceOf(user2.address);

        await stakingManager.setWooPP(testWooPP.address);
        let swapAmount = await testWooPP.getSwapAmount(
            usdcToken.address, wooToken.address,
            utils.parseEther("100"));
        expect(swapAmount).to.be.eq(utils.parseEther("500"));

        await rewarder1.setRewardPerBlock(utils.parseEther("20"));      // usdc 20
        await rewarder2.setRewardPerBlock(utils.parseEther("1"));       // weth 1
        await mpRewarder.setRewardRate(0);

        await _logUserPending();
        await stakingManager.stakeWoo(user1.address, utils.parseEther("20"));
        await stakingManager.stakeWoo(user2.address, utils.parseEther("10"));
        await mine(2);
        await _logUserPending();
        await stakingManager.compoundRewards(user1.address);

        console.log("Compound user1 woo");
        await _logUserBals();
        await _logUserWoo();

        expect(await usdcToken.balanceOf(user1.address)).to.be.eq(user1Bal);

        await stakingManager.compoundRewards(user2.address);
        console.log("Compound user2 woo");
        await _logUserBals();
        await _logUserWoo();

        await _logUserPending();
        expect(await usdcToken.balanceOf(user2.address)).to.be.eq(user2Bal);
    });

    it("CoolDown Tests", async () => {
        await rewarder1.setRewardPerBlock(utils.parseEther("20"));      // usdc 20
        await rewarder2.setRewardPerBlock(utils.parseEther("1"));       // weth 1
        await mpRewarder.setRewardRate(31536000 * 100);   // 1% per second
        await stakingManager.stakeWoo(owner.address, utils.parseEther("20"));
        await mine(5);
        await _logPending(owner.address, "owner");
        await stakingManager["claimRewards()"]();
        await mine(5);
        await _logPending(owner.address, "owner");
        await stakingCompounder.addUser();
        await expect(stakingManager["claimRewards()"]()).to.be.revertedWith(
            "WooStakingManager: !COMPOUND"
        );
        await mine(10);
        await stakingCompounder.setCooldownDuration(2);
        await stakingCompounder.removeUser();
        await _logPending(owner.address, "owner");
        await stakingManager["claimRewards()"]();
    });

    it("CompoundMP Tests", async () => {
        await rewarder1.setRewardPerBlock(utils.parseEther("20"));      // usdc 20
        await rewarder2.setRewardPerBlock(utils.parseEther("1"));       // weth 1
        await mpRewarder.setRewardRate(31536000 * 100);   // 1% per second
        await stakingManager.stakeWoo(user1.address, utils.parseEther("20"));
        await stakingManager.stakeWoo(user2.address, utils.parseEther("10"));

        await mine(5);

        await _logUserPending();

        const amount1 = await rewarder1.pendingReward(user1.address);
        const amount2 = await rewarder1.pendingReward(user2.address);
        await stakingManager.compoundMP(user1.address);
        console.log("After compoundMP")

        const amount3 = await rewarder1.pendingReward(user1.address);
        const amount4 = await rewarder1.pendingReward(user2.address);
        const newReward1 = amount3.sub(amount1);
        const newReward2 = amount4.sub(amount2);
        console.log(
            "New usdc reward user1, user2: ",
            utils.formatEther(newReward1), utils.formatEther(newReward2));
        expect(newReward1).to.be.eq(newReward2.mul(2));

        await _logUserPending();

        await mine(5);
        await _logUserPending();
    });

    async function _logUserWoo() {
        let woo1 = utils.formatEther(await stakingManager.wooBalance(user1.address));
        let woo2 = utils.formatEther(await stakingManager.wooBalance(user2.address));
        console.log("Woo (user1, user2): ", woo1, woo2);
        console.log(" --- \n");
    }

    async function _logUserBals() {
        await _logUserBal(user1.address, "user1");
        await _logUserBal(user2.address, "user2");
    }

    async function _logUserBal(user:String, name:String) {
        console.log("usdc, weth for ", name, ": ",
            utils.formatEther(await usdcToken.balanceOf(user)),
            utils.formatEther(await wethToken.balanceOf(user)));
    }

    async function _logPrs(mpReward, tokens, amounts) {
        console.log("   -  MP ", utils.formatEther(mpReward));
        for (let i = 0; i < tokens.length; ++i) {
            console.log("   - ", _name(tokens[i]), utils.formatEther(amounts[i]));
        }
    }

    async function _logUserPending() {
        const latestBlock = await ethers.provider.getBlock("latest");
        console.log(" block: ", latestBlock.number);
        console.log(" MpRewarder total weight", utils.formatEther(await mpRewarder.totalWeight()));
        console.log(" SimpleRewarder total weight", utils.formatEther(await rewarder1.totalWeight()));
        const [mp1, m1] = await _logPending(user1.address, "user1");
        const [mp2, m2] = await _logPending(user2.address, "user2");
        console.log(" Sum (usdc, weth, mp): ",
            utils.formatEther(m1[0].add(m2[0])),
            utils.formatEther(m1[1].add(m2[1])),
            utils.formatEther(mp1.add(mp2)));
        console.log(" --- \n");
    }

    async function _logPending(user: String, name: String) {
        const [mpReward1, tokens1, amounts1] = await stakingManager.pendingRewards(user);
        console.log(name, " : woo ", utils.formatEther(await stakingManager.wooBalance(user)), " weight", utils.formatEther(await rewarder1.weight(user)));
        await _logPrs(mpReward1, tokens1, amounts1);
        return [mpReward1, amounts1];
    }

    function _name(addr:String) {
        if (addr == usdcToken.address) {
            return "usdc";
        } else if (addr == wethToken.address) {
            return "weth";
        } else {
            return "unknown";
        }
    }

    async function _logPendingReward() {
        console.log("\n-----------------");
        console.log('block number: ', (await ethers.provider.getBlock("latest")).number);
        // console.log('accTokenPerShare: ', utils.formatEther(await rewarder.accTokenPerShare()));
        // console.log("user pending: ", utils.formatEther(await rewarder.pendingReward(user.address)));
        // console.log("user1 pending: ", utils.formatEther(await rewarder.pendingReward(user1.address)));
        // console.log("user2 pending: ", utils.formatEther(await rewarder.pendingReward(user2.address)));
        console.log("-----------------\n");
    }

});
