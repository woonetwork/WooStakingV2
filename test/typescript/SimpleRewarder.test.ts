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

import { SimpleRewarder, WooStakingManager } from "../../typechain";
import SimpleRewarderArtifact from "../../artifacts/contracts/rewarders/SimpleRewarder.sol/SimpleRewarder.json";
import WooStakingManagerArtifact from "../../artifacts/contracts/WooStakingManager.sol/WooStakingManager.json";
import TestTokenArtifact from "../../artifacts/contracts/test/TestToken.sol/TestToken.json";


describe("Staking & Reward tests", () => {

    let owner: SignerWithAddress;
    let baseToken: SignerWithAddress;

    let rewarder: SimpleRewarder;
    let stakingManager: Contract;
    let user: SignerWithAddress;
    let user1: SignerWithAddress;
    let user2: SignerWithAddress;

    let usdcToken: Contract;

    beforeEach(async () => {
        const signers = await ethers.getSigners();
        owner = signers[0];
        baseToken = signers[1];
        user = signers[2];
        user1 = signers[3];
        user2 = signers[4];

        stakingManager = await deployMockContract(owner, WooStakingManagerArtifact.abi);
        await stakingManager.mock.owner.returns(owner.address);
        await stakingManager.mock.wooBalance.withArgs(user.address).returns(5);
        await stakingManager.mock.wooBalance.withArgs(user1.address).returns(10);
        await stakingManager.mock.wooBalance.withArgs(user2.address).returns(30);
        await stakingManager.mock.wooTotalBalance.returns(100);
        await stakingManager.mock.stakeWoo.returns();
        await stakingManager.mock["totalBalance(address)"].withArgs(user.address).returns(10);
        await stakingManager.mock["totalBalance(address)"].withArgs(user1.address).returns(20);
        await stakingManager.mock["totalBalance(address)"].withArgs(user2.address).returns(30);
        await stakingManager.mock["totalBalance()"].withArgs().returns(100);

        usdcToken = await deployContract(owner, TestTokenArtifact, []);

        await usdcToken.mint(owner.address, utils.parseEther("100000"));

        rewarder = (await deployContract(owner, SimpleRewarderArtifact, [usdcToken.address, stakingManager.address])) as SimpleRewarder;

        await usdcToken.mint(rewarder.address, utils.parseEther("100000"));
    });

    it("Rewarder Tests", async () => {
        // mineUpTo(10);

        _logPendingReward();

        await rewarder.setRewardPerBlock(utils.parseEther("10"));

        const startBlock = (await ethers.provider.getBlock("latest")).number;
        // const rewardPerBlock = Number(utils.formatEther(await rewarder.rewardPerBlock()));
        const rewardPerBlock = await rewarder.rewardPerBlock();

        await mine(10);

        console.log('allPendingReward: ', utils.formatEther(await rewarder.allPendingReward()));
        expect(Number(utils.formatEther(await rewarder.allPendingReward()))).to.be.eq(100); // all pending = 100
        expect(Number(utils.formatEther(await rewarder.pendingReward(user.address)))).to.be.eq(10); // 100 * 10%
        expect(Number(utils.formatEther(await rewarder.pendingReward(user1.address)))).to.be.eq(20); // 100 * 20%
        expect(Number(utils.formatEther(await rewarder.pendingReward(user2.address)))).to.be.eq(30); // 100 * 30%

        await _logPendingReward();

        await mine(10);

        expect(Number(utils.formatEther(await rewarder.pendingReward(user.address)))).to.be.eq(20); // 200 * 10%
        expect(Number(utils.formatEther(await rewarder.pendingReward(user1.address)))).to.be.eq(40); // 200 * 20%
        expect(Number(utils.formatEther(await rewarder.pendingReward(user2.address)))).to.be.eq(60); // 200 * 30%

        await rewarder.updateRewardForUser(user.address);

        await _logPendingReward();

        await rewarder.updateReward();

        let currentBlock = (await ethers.provider.getBlock("latest")).number;
        let userReward = rewardPerBlock.mul(currentBlock - startBlock).div(10); // 10% of all rewards
        expect(await rewarder.pendingReward(user.address)).to.be.eq(userReward);
        expect(await rewarder.pendingReward(user1.address)).to.be.eq(userReward.mul(2));
        expect(await rewarder.pendingReward(user2.address)).to.be.eq(userReward.mul(3));

        // Verify the claim of pending reward
        await rewarder["claim(address)"](user1.address);

        expect(await usdcToken.balanceOf(user.address)).to.be.eq(0);
        expect(await usdcToken.balanceOf(user1.address)).to.be.gt(0);
        expect(await usdcToken.balanceOf(user2.address)).to.be.eq(0);

        currentBlock = (await ethers.provider.getBlock("latest")).number;
        userReward = rewardPerBlock.mul(currentBlock - startBlock).div(10); // 10% of all rewards

        expect(await usdcToken.balanceOf(user1.address)).to.be.eq(userReward.mul(2));

        expect(await rewarder.pendingReward(user.address)).to.be.eq(userReward);
        expect(await rewarder.pendingReward(user1.address)).to.be.eq(0);
        expect(await rewarder.pendingReward(user2.address)).to.be.eq(userReward.mul(3));

        await mine(10);

        // Claim again
        await rewarder["claim(address)"](user.address);
        currentBlock = (await ethers.provider.getBlock("latest")).number;
        await rewarder["claim(address)"](user1.address);
        console.log("\n--- Claimed user & user1 ---\n");

        expect(await usdcToken.balanceOf(user.address)).to.be.gt(0);
        expect(await usdcToken.balanceOf(user1.address)).to.be.gt(0);
        expect(await usdcToken.balanceOf(user2.address)).to.be.eq(0);

        userReward = rewardPerBlock.mul(currentBlock - startBlock).div(10); // 10% of all rewards
        expect(await usdcToken.balanceOf(user.address)).to.be.eq(userReward);
        expect(await usdcToken.balanceOf(user1.address)).to.be.gt(userReward.mul(2));

        currentBlock = (await ethers.provider.getBlock("latest")).number;
        userReward = rewardPerBlock.mul(currentBlock - startBlock).div(10); // 10% of all rewards
        expect(await rewarder.pendingReward(user2.address)).to.be.eq(userReward.mul(3));

        await _logPendingReward();  // user & user1 already claimed, pending reward should be small!

        await mine(10);
        await rewarder.updateReward(); // accTokenPerShare , got updated
        await _logPendingReward();
    });

    async function _logPendingReward() {
        console.log("\n-----------------");
        console.log('block number: ', (await ethers.provider.getBlock("latest")).number);
        console.log('accTokenPerShare: ', utils.formatEther(await rewarder.accTokenPerShare()));
        console.log("user pending: ", utils.formatEther(await rewarder.pendingReward(user.address)));
        console.log("user1 pending: ", utils.formatEther(await rewarder.pendingReward(user1.address)));
        console.log("user2 pending: ", utils.formatEther(await rewarder.pendingReward(user2.address)));
        console.log("-----------------\n");
    }

    function delay(ms: number) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
});
