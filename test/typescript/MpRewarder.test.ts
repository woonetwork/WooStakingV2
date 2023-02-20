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


describe("MpRewarder tests", () => {

    let owner: SignerWithAddress;
    let baseToken: SignerWithAddress;

    let mpRewarder: MpRewarder;
    let booster: RewardBooster;
    let stakingManager: WooStakingManager;
    let user: SignerWithAddress;
    let user1: SignerWithAddress;
    let user2: SignerWithAddress;

    let mpToken: Contract;

    beforeEach(async () => {
        const signers = await ethers.getSigners();
        owner = signers[0];
        baseToken = signers[1];
        user = signers[2];
        user1 = signers[3];
        user2 = signers[4];

        stakingManager = (await deployContract(owner, TestStakingManagerArtifact, [])) as WooStakingManager;
        await stakingManager.stakeWoo(user.address, 50);
        await stakingManager.stakeWoo(user1.address, 100);
        await stakingManager.stakeWoo(user2.address, 300);

        mpToken = await deployContract(owner, TestTokenArtifact, []);

        await mpToken.mint(owner.address, utils.parseEther("100000"));

        mpRewarder = (await deployContract(owner, MpRewarderArtifact, [mpToken.address, stakingManager.address])) as MpRewarder;
        await mpToken.mint(mpRewarder.address, utils.parseEther("100000"));
        booster = (await deployContract(owner, RewardBoosterArtifact, [mpRewarder.address])) as RewardBooster;
        await mpRewarder.setBooster(booster.address);
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

        const blockTimestamp = (await ethers.provider.getBlock("latest")).timestamp;
        let deltaSeconds = BigNumber.from(blockTimestamp - startBlockTimestamp);

        expect(user1Pending).to.be.eq(userPending.mul(2));
        expect(user2Pending).to.be.eq(userPending.mul(6));
        expect(allPending).to.be.eq(userPending.mul(9));
        expect(allPending).to.be.eq(deltaSeconds.mul(450).div(100));

        // console.log('allPendingReward: ', utils.formatEther(allPending));
        // await _logPendingReward();

        // Verify the claim of pending reward
        await mpRewarder["claim(address,address)"](user1.address, stakingManager.address);
        // await _logUserBals();
        expect(await stakingManager.mpBalance(user1.address)).to.be.gte(user1Pending);
        expect(await stakingManager.mpBalance(user.address)).to.be.equal(0);
        expect(await stakingManager.mpBalance(user2.address)).to.be.equal(0);

        await mpRewarder["claim(address,address)"](user.address, stakingManager.address);
        expect(await stakingManager.mpBalance(user.address)).to.be.gte(userPending);
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