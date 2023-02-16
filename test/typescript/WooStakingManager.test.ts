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

import { IWooPPV2, IWooStakingProxy, MpRewarder, RewardBooster,
    SimpleRewarder, WooStakingManager, TestWooPP } from "../../typechain";
import SimpleRewarderArtifact from "../../artifacts/contracts/rewarders/SimpleRewarder.sol/SimpleRewarder.json";
import MpRewarderArtifact from "../../artifacts/contracts/rewarders/MpRewarder.sol/MpRewarder.json";
import WooStakingManagerArtifact from "../../artifacts/contracts/WooStakingManager.sol/WooStakingManager.json";
import TestTokenArtifact from "../../artifacts/contracts/test/TestToken.sol/TestToken.json";
import WooStakingProxyArtifact from "../../artifacts/contracts/WooStakingProxy.sol/WooStakingProxy.json";
import IWooPPV2Artifact from "../../artifacts/contracts/interfaces/IWooPPV2.sol/IWooPPV2.json";
import WooStakingProxyArtifact from "../../artifacts/contracts/rewarders/MpRewarder.sol/MpRewarder.json";
import RewardBoosterArtifact from "../../artifacts/contracts/rewarders/RewardBooster.sol/RewardBooster.json";
import TestWooPPArtifact from "../../artifacts/contracts/test/TestWooPP.sol/TestWooPP.json";


describe("WooStakingManager tests", () => {

    let owner: SignerWithAddress;

    let booster: RewardBooster;
    let mpRewarder: MpRewarder;
    let rewarder1: SimpleRewarder;
    let rewarder2: SimpleRewarder;
    let stakingManager: WooStakingManager;

    // let wooPPv2: Contract;
    let wooPPv2: TestWooPP;
    let proxy: Contract;

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

        // wooPPv2 = await deployMockContract(owner, IWooPPV2Artifact.abi);
        // await wooPPv2.mock.swap.returns(10000);
        wooPPv2 = (await deployContract(owner, TestWooPPArtifact, [])) as TestWooPP;
        await wooPPv2.setPrice(usdcToken.address, utils.parseEther("1"));
        await wooPPv2.setPrice(wethToken.address, utils.parseEther("50"));
        await wooPPv2.setPrice(wooToken.address, utils.parseEther("0.2"));
        await wooToken.mint(wooPPv2.address, utils.parseEther("100000"));
        await usdcToken.mint(wooPPv2.address, utils.parseEther("100000"));
        await wethToken.mint(wooPPv2.address, utils.parseEther("1000"));



        proxy = await deployMockContract(owner, WooStakingProxyArtifact.abi);
        await proxy.mock.stake.returns();
    });

    beforeEach(async () => {
        [user, user1, user2] = await ethers.getSigners();

        stakingManager = (await deployContract(owner, WooStakingManagerArtifact, [wooToken.address, wooPPv2.address, proxy.address])) as WooStakingManager;

        rewarder1 = (await deployContract(owner, SimpleRewarderArtifact, [usdcToken.address, stakingManager.address])) as SimpleRewarder;
        await rewarder1.setRewardPerBlock(utils.parseEther("10"));
        await usdcToken.mint(rewarder1.address, utils.parseEther("100000"));
        await stakingManager.addRewarder(rewarder1.address);

        rewarder2 = (await deployContract(owner, SimpleRewarderArtifact, [wethToken.address, stakingManager.address])) as SimpleRewarder;
        await rewarder2.setRewardPerBlock(utils.parseEther("2"));
        await wethToken.mint(rewarder2.address, utils.parseEther("300"));
        await stakingManager.addRewarder(rewarder2.address);

        mpRewarder = (await deployContract(owner, MpRewarderArtifact, [wethToken.address, stakingManager.address])) as MpRewarder;
        await mpRewarder.setRewardPerBlock(utils.parseEther("2"));
        await wethToken.mint(mpRewarder.address, utils.parseEther("300"));

        booster = (await deployContract(owner, RewardBoosterArtifact, [mpRewarder.address])) as RewardBooster;
        await mpRewarder.setBooster(booster.address);

        await stakingManager.setMPRewarder(mpRewarder.address);
    });

    it("Init Tests", async () => {
        expect(await stakingManager.woo()).to.be.eq(wooToken.address);
        expect(await stakingManager.wooPP()).to.be.eq(wooPPv2.address);
        expect(await stakingManager.stakingProxy()).to.be.eq(proxy.address);
        expect(await stakingManager.owner()).to.be.eq(owner.address);
        expect(await stakingManager.mpRewarder()).to.be.eq(mpRewarder.address);
    });


    it("Stake Tests", async () => {
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
        // console.log("wooToken addr: ", wooToken.address);
        // console.log("usdcToken addr: ", usdcToken.address);
        // console.log("wethToken addr: ", wethToken.address);

        let beforeBlock = (await ethers.provider.getBlock("latest")).number;
        await stakingManager.stakeWoo(user1.address, utils.parseEther("40"));
        await stakingManager.stakeWoo(user2.address, utils.parseEther("20"));
        let afterBlock = (await ethers.provider.getBlock("latest")).number;
        // console.log("beforeBlock: " + beforeBlock + ", afterBlock: " + afterBlock);
        // await stakingManager.stakeWoo(user1.address, utils.parseEther("30"));

        await mine(10); // mine 10 blocks

        const allPendingReward1 = await rewarder1.allPendingReward();
        // console.log("reward1 all pending reward: ", utils.formatEther(allPendingReward1));
        const allPendingReward2 = await rewarder2.allPendingReward();
        // console.log("reward2 all pending reward: ", utils.formatEther(allPendingReward2));
        expect(allPendingReward1).to.be.eq(utils.parseEther("100"));
        expect(allPendingReward2).to.be.eq(utils.parseEther("20"));

        let poolWeight = await stakingManager["totalBalance()"]();
        let weight1 = await stakingManager["totalBalance(address)"](user1.address);
        let weight2 = await stakingManager["totalBalance(address)"](user2.address);
        // console.log("poolWeight: " + utils.formatEther(poolWeight) +
        //     ", weight1: " + utils.formatEther(weight1)
        //     + ", weight2: " + utils.formatEther(weight2));
        expect(weight1).to.be.eq(utils.parseEther("40"));
        expect(weight2).to.be.eq(utils.parseEther("20"));

        const [mpReward1, rewardTokens1, amounts1] = await stakingManager.pendingRewards(user1.address);
        // console.log("mpReward1: ", utils.formatEther(mpReward1));
        // for(let i=0;i<rewardTokens1.length;i++) {
        //     console.log("Reward token: ", rewardTokens1[i]);
        //     console.log("Amount: ", utils.formatEther(amounts1[i]));
        // }

        const [mpReward2, rewardTokens2, amounts2] = await stakingManager.pendingRewards(user2.address);
        // console.log("mpReward2: ", utils.formatEther(mpReward2));
        // for(let i=0;i<rewardTokens2.length;i++) {
        //     console.log("Reward token: ", rewardTokens2[i]);
        //     console.log("Amount: ", utils.formatEther(amounts2[i]));
        // }
        expect(mpReward1).to.be.eq(mpReward2.mul(2));
        for (let i=0;i<amounts1.length;i++) {
            expect(amounts1[i]).to.be.eq(amounts2[i].mul(2));
        }

    });

    it("compoundRewards Tests", async() => {
        console.log("woo: %s usdc: %s weth: %s ", wooToken.address, usdcToken.address, wethToken.address);
        await stakingManager.stakeWoo(user1.address, utils.parseEther("20"));
        await stakingManager.stakeWoo(user2.address, utils.parseEther("10"));
        await mine(2);
        await stakingManager.compoundRewards(user1.address);
        // let swapAmount = await wooPPv2.getSwapAmount(
        //     usdcToken.address, wooToken.address,
        //     utils.parseEther("100"));
        // console.log("swapAmount: ", utils.formatEther(swapAmount));
    });

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
