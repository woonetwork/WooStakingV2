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

import { expect, util } from "chai";
import { BigNumber, Contract, utils, Wallet } from 'ethers'
import { ethers } from "hardhat";
import { deployContract, deployMockContract } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
const { mine, time, mineUpTo } = require("@nomicfoundation/hardhat-network-helpers");

import { MpRewarder, SimpleRewarder, WooStakingManager, RewardBooster } from "../../typechain";
import MpRewarderArtifact from "../../artifacts/contracts/rewarders/MpRewarder.sol/MpRewarder.json";
import WooStakingManagerArtifact from "../../artifacts/contracts/WooStakingManager.sol/WooStakingManager.json";
import TestTokenArtifact from "../../artifacts/contracts/test/TestToken.sol/TestToken.json";
import TestStakingManagerArtifact from "../../artifacts/contracts/test/TestStakingManager.sol/TestStakingManager.json";
import RewardBoosterArtifact from "../../artifacts/contracts/rewarders/RewardBooster.sol/RewardBooster.json";
import IWooStakingCompounder from "../../artifacts/contracts/interfaces/IWooStakingCompounder.sol/IWooStakingCompounder.json";


describe("MpRewarder tests", () => {

    let owner: SignerWithAddress;
    let baseToken: SignerWithAddress;

    let mpRewarder: MpRewarder;
    let booster: RewardBooster;
    let compounder: Contract;
    let stakingManager: WooStakingManager;
    let user: SignerWithAddress;
    let user1: SignerWithAddress;
    let user2: SignerWithAddress;

    before(async () => {
        [owner] = await ethers.getSigners();

        stakingManager = (await deployContract(owner, TestStakingManagerArtifact, [])) as WooStakingManager;

        compounder = await deployMockContract(owner, IWooStakingCompounder.abi);
        await compounder.mock.contains.returns(true);

        mpRewarder = (await deployContract(owner, MpRewarderArtifact, [stakingManager.address])) as MpRewarder;
        booster = (await deployContract(owner, RewardBoosterArtifact, [mpRewarder.address, compounder.address])) as RewardBooster;
        await mpRewarder.setBooster(booster.address);
        await stakingManager.setMPRewarder(mpRewarder.address);

        [user, user1, user2] = await ethers.getSigners();
        await stakingManager.stakeWoo(user.address, utils.parseEther("5"));
        await stakingManager.stakeWoo(user1.address, utils.parseEther("10"));
        await stakingManager.stakeWoo(user2.address, utils.parseEther("30"));
    });

    it("MP tests", async () => {

        await mpRewarder.setRewardRate(31536000 * 100);   // 1% per second

        const startBlockTimestamp = Number(await mpRewarder.lastRewardTs());
        const rewardRate = await mpRewarder.rewardRate();

        await mine(10);

        let allPending = await mpRewarder.allPendingReward();
        let userPending = await mpRewarder.pendingReward(user.address);
        let user1Pending = await mpRewarder.pendingReward(user1.address);
        let user2Pending = await mpRewarder.pendingReward(user2.address);
        let totalWeight = await mpRewarder.totalWeight()

        const blockTimestamp = (await ethers.provider.getBlock("latest")).timestamp;
        let deltaSeconds = BigNumber.from(blockTimestamp - startBlockTimestamp);

        expect(user1Pending).to.be.eq(userPending.mul(2));
        expect(user2Pending).to.be.eq(userPending.mul(6));
        expect(allPending).to.be.eq(userPending.mul(9));
        expect(allPending).to.be.eq(deltaSeconds.mul(totalWeight).div(100));

        // console.log('allPendingReward: ', utils.formatEther(allPending));
        // await _logPendingReward();

        // Verify the claim of pending reward
        await mpRewarder["claim(address)"](user1.address);
        // await _logUserBals();
        expect(await stakingManager.mpBalance(user1.address)).to.be.gte(user1Pending);
        expect(await stakingManager.mpBalance(user.address)).to.be.equal(0);
        expect(await stakingManager.mpBalance(user2.address)).to.be.equal(0);

        await mpRewarder["claim(address)"](user.address);
        expect(await stakingManager.mpBalance(user.address)).to.be.gte(userPending);
    });

    it("Booster tests", async() => {
        await compounder.mock.contains.returns(false);
        await mpRewarder.setRewardRate(31536000 * 100);   // 1% per second

        const startBlockTimestamp = Number(await mpRewarder.lastRewardTs());
        const rewardRate = await mpRewarder.rewardRate();
        const weight1 = await mpRewarder.weight(user1.address);

        await mine(10);

        let pending1 = await mpRewarder.pendingReward(user1.address);
        expect(pending1).to.be.gt(0);
        await booster.setUserRatios([user1.address], [true], [false]);
        const weight2 = await mpRewarder.weight(user1.address);
        let pending2 = await mpRewarder.pendingReward(user1.address);

        await booster.setUserRatios([user1.address], [false], [false]);
        const weight3 = await mpRewarder.weight(user1.address);
        let pending3 = await mpRewarder.pendingReward(user1.address);
        // console.log("weight1: %s weight2: %s weight3: %s",
        //     weight1, weight2, weight3);
        // console.log("pending1: %s pending2: %s pending3: %s",
        //     pending1, pending2, pending3);
        expect(pending3).to.be.gt(0);
        expect(weight3).to.be.eq(weight1);
        expect(weight3).to.be.lt(weight2);
    });

    async function _logUserBals() {
        await _logUserBal(user.address, "user");
        await _logUserBal(user1.address, "user1");
        await _logUserBal(user2.address, "user2");
    }

    async function _logUserBal(user:String, name:String) {
        console.log("mp for ", name, ": ", utils.formatEther(await stakingManager.mpBalance(user)));
    }

    async function _logPendingReward() {
        console.log("\n-----------------");
        console.log('block timestamp: ', (await ethers.provider.getBlock("latest")).timestamp);
        console.log('accTokenPerShare: ', utils.formatEther(await mpRewarder.accTokenPerShare()));
        console.log("user pending: ", utils.formatEther(await mpRewarder.pendingReward(user.address)));
        console.log("user1 pending: ", utils.formatEther(await mpRewarder.pendingReward(user1.address)));
        console.log("user2 pending: ", utils.formatEther(await mpRewarder.pendingReward(user2.address)));
        console.log("-----------------\n");
    }
});