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
import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import { deployContract } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
const { mine } = require("@nomicfoundation/hardhat-network-helpers");

import { SimpleRewarder, WooStakingManager } from "../../typechain";
import SimpleRewarderArtifact from "../../artifacts/contracts/rewarders/SimpleRewarder.sol/SimpleRewarder.json";
import TestStakingManagerArtifact from "../../artifacts/contracts/test/TestStakingManager.sol/TestStakingManager.json";


describe("SimpleRewarder tests", () => {
    let owner: SignerWithAddress;
    let baseToken: SignerWithAddress;

    let rewarder: SimpleRewarder;
    let stakingManager: WooStakingManager;
    let user: SignerWithAddress;
    beforeEach(async () => {
        const signers = await ethers.getSigners();
        owner = signers[0];
        baseToken = signers[1];
        user = signers[2];
        stakingManager = (await deployContract(owner, TestStakingManagerArtifact, [baseToken.address, baseToken.address])) as WooStakingManager;
        rewarder = (await deployContract(owner, SimpleRewarderArtifact, [baseToken.address, stakingManager.address])) as SimpleRewarder;
    });
    it("Init with correct owner", async () => {
        expect(await rewarder.owner()).to.eq(owner.address);
        expect(await stakingManager.owner()).to.eq(owner.address);
    });

    it("Get pending reward",async () => {
        await stakingManager.stakeWoo(user.address, 10);
        let amount = await stakingManager.wooBalance(user.address);
        expect(amount).to.eq(10);
        let total = await stakingManager.userBalance(user.address);
        expect(total).to.eq(10);

        let [block1, accShare1] = await rewarder.state();
        console.log("block: " + block1 + ", accshare: " + accShare1);
        await mine(10);

        await rewarder.setRewardPerBlock(20);
        await rewarder.updateReward();
        let reward = await rewarder.pendingReward(user.address);

        console.log("reward: ", reward.toNumber());

        let [block2, accShare2] = await rewarder.state();
        console.log("block: " + block2 + ", accshare: " + accShare2);
    });
});