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

import { MpRewarder, SimpleRewarder, WooStakingManager, RewardBooster, WooStakingLocal } from "../../typechain";
import MpRewarderArtifact from "../../artifacts/contracts/rewarders/MpRewarder.sol/MpRewarder.json";
import WooStakingManagerArtifact from "../../artifacts/contracts/WooStakingManager.sol/WooStakingManager.json";
import WooStakingLocalArtifact from "../../artifacts/contracts/WooStakingLocal.sol/WooStakingLocal.json";
import TestTokenArtifact from "../../artifacts/contracts/test/TestToken.sol/TestToken.json";
import RewardBoosterArtifact from "../../artifacts/contracts/rewarders/RewardBooster.sol/RewardBooster.json";
import IWooStakingCompounder from "../../artifacts/contracts/interfaces/IWooStakingCompounder.sol/IWooStakingCompounder.json";
import IWooPPV2Artifact from "../../artifacts/contracts/interfaces/IWooPPV2.sol/IWooPPV2.json";


describe("WooStakingLocal tests", () => {

    let owner: SignerWithAddress;
    let baseToken: SignerWithAddress;

    let mpRewarder: MpRewarder;
    let booster: RewardBooster;
    let compounder: Contract;
    let stakingManager: WooStakingManager;
    let stakingLocal: WooStakingLocal;
    let user: SignerWithAddress;
    let user1: SignerWithAddress;
    let user2: SignerWithAddress;

    let wooToken: Contract;
    let wooPPv2: Contract;

    before(async () => {
        [owner] = await ethers.getSigners();

        wooToken = await deployContract(owner, TestTokenArtifact, []);
        await wooToken.mint(owner.address, utils.parseEther("100000"));

        stakingManager = (await deployContract(owner, WooStakingManagerArtifact, [wooToken.address])) as WooStakingManager;

        wooPPv2 = await deployMockContract(owner, IWooPPV2Artifact.abi);
        await wooPPv2.mock.swap.returns(10000);
        await stakingManager.setWooPP(wooPPv2.address);

        compounder = await deployMockContract(owner, IWooStakingCompounder.abi);
        await compounder.mock.contains.returns(true);

        mpRewarder = (await deployContract(owner, MpRewarderArtifact, [stakingManager.address])) as MpRewarder;
        booster = (await deployContract(owner, RewardBoosterArtifact, [mpRewarder.address, compounder.address])) as RewardBooster;
        await mpRewarder.setBooster(booster.address);
        await stakingManager.setMPRewarder(mpRewarder.address);
    });

    beforeEach(async () => {
        [user, user1, user2] = await ethers.getSigners();

        await wooToken.mint(user.address, utils.parseEther("100000"));
        await wooToken.mint(user1.address, utils.parseEther("100000"));
        await wooToken.mint(user2.address, utils.parseEther("100000"));

        stakingLocal = (await deployContract(
            owner,
            WooStakingLocalArtifact,
            [wooToken.address, stakingManager.address])) as WooStakingLocal;

        await stakingManager.setStakingLocal(stakingLocal.address);
        await stakingLocal.setAdmin(stakingManager.address, true);
    });

    it("Staking local tests", async () => {
        expect(await stakingLocal.balances(owner.address)).to.be.equal(0);
        expect(await stakingManager.wooBalance(owner.address)).to.be.equal(0);
        expect(await stakingLocal.balances(user1.address)).to.be.equal(0);
        expect(await stakingManager.wooBalance(user1.address)).to.be.equal(0);

        await wooToken.approve(stakingLocal.address, 1000);
        await stakingLocal["stake(uint256)"](100);  // why not error ?

        expect(await stakingLocal.balances(owner.address)).to.be.equal(100);
        expect(await stakingManager.wooBalance(owner.address)).to.be.equal(100);
        expect(await stakingLocal.balances(user1.address)).to.be.equal(0);
        expect(await stakingManager.wooBalance(user1.address)).to.be.equal(0);

        await stakingLocal["stake(address,uint256)"](user1.address, 500);  // why not error ?
        expect(await stakingLocal.balances(owner.address)).to.be.equal(100);
        expect(await stakingManager.wooBalance(owner.address)).to.be.equal(100);
        expect(await stakingLocal.balances(user1.address)).to.be.equal(500);
        expect(await stakingManager.wooBalance(user1.address)).to.be.equal(500);
    });

    it("Unstaking local tests", async () => {
        expect(await stakingLocal.balances(owner.address)).to.be.equal(0);
        expect(await stakingLocal.balances(user1.address)).to.be.equal(0);
        expect(await stakingManager.wooBalance(owner.address)).to.be.equal(100);
        expect(await stakingManager.wooBalance(user1.address)).to.be.equal(500);

        await wooToken.approve(stakingLocal.address, 1000);
        await stakingLocal["stake(uint256)"](100);  // why not error ?
        await stakingLocal["stake(address,uint256)"](user1.address, 500);  // why not error ?

        expect(await stakingLocal.balances(owner.address)).to.be.equal(100);
        expect(await stakingManager.wooBalance(owner.address)).to.be.equal(100 + 100);
        expect(await stakingLocal.balances(user1.address)).to.be.equal(500);
        expect(await stakingManager.wooBalance(user1.address)).to.be.equal(500 + 500);

        await stakingLocal.unstake(50);
        expect(await stakingLocal.balances(owner.address)).to.be.equal(50);
        expect(await stakingManager.wooBalance(owner.address)).to.be.equal(50 + 100);
        expect(await stakingLocal.balances(user1.address)).to.be.equal(500);
        expect(await stakingManager.wooBalance(user1.address)).to.be.equal(500 + 500);

        await stakingLocal.connect(user1).unstakeAll();
        expect(await stakingLocal.balances(owner.address)).to.be.equal(50);
        expect(await stakingManager.wooBalance(owner.address)).to.be.equal(50 + 100);
        expect(await stakingLocal.balances(user1.address)).to.be.equal(0);
        expect(await stakingManager.wooBalance(user1.address)).to.be.equal(0 + 500);
    });

    it("CompoundAll local tests", async () => {
        expect(await stakingLocal.balances(owner.address)).to.be.equal(0);
        expect(await stakingLocal.balances(user1.address)).to.be.equal(0);

        await wooToken.approve(stakingLocal.address, 1000);
        await stakingLocal["stake(uint256)"](100);
        await stakingLocal["stake(address,uint256)"](user1.address, 500);

        await mine(5);

        await stakingLocal.compoundAll();
    });

    it("StakeForUsers local tests", async () => {
        expect(await stakingLocal.balances(owner.address)).to.be.equal(0);
        expect(await stakingLocal.balances(user1.address)).to.be.equal(0);

        await wooToken.approve(stakingLocal.address, 600);
        await stakingLocal.stakeForUsers([owner.address, user1.address], [100, 500], 600);

        await mine(5);

        expect(await stakingLocal.balances(owner.address)).to.be.equal(100);
        expect(await stakingLocal.balances(user1.address)).to.be.equal(500);
    });

});