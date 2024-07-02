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
import { Contract } from 'ethers'
import { ethers } from "hardhat";
import { deployContract } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { RewardNFT, NFTBoosterV2, RewardCampaignManager, WooStakingManager } from "../../typechain";
import RewardNFTArtifact from "../../artifacts/contracts/RewardNFT.sol/RewardNFT.json";
import NFTBoosterV2Artifact from "../../artifacts/contracts/rewarders/NFTBoosterV2.sol/NFTBoosterV2.json";
import RewardCampaignManagerArtifact from "../../artifacts/contracts/RewardCampaignManager.sol/RewardCampaignManager.json";
import WooStakingManagerArtifact from "../../artifacts/contracts/WooStakingManager.sol/WooStakingManager.json";
import TestTokenArtifact from "../../artifacts/contracts/test/TestToken.sol/TestToken.json";


describe("RewardNFT tests", () => {

    let owner: SignerWithAddress;

    let rewardNFT: RewardNFT;
    let stakingManager: WooStakingManager;
    let nftBoosterV2: NFTBoosterV2;
    let campaignManager: RewardCampaignManager;
    let user: SignerWithAddress;
    let user1: SignerWithAddress;
    let user2: SignerWithAddress;
    let user3: SignerWithAddress;

    let wooToken: Contract;
    let usdcToken: Contract;
    let campaignId = 1;

    beforeEach(async () => {
        const signers = await ethers.getSigners();
        owner = signers[0];
        user = signers[1];
        user1 = signers[2];
        user2 = signers[3];
        user3 = signers[4];

        rewardNFT = await deployContract(owner, RewardNFTArtifact, ["BoosterTest", "WooNFT001"]) as RewardNFT;
        campaignManager = await deployContract(owner, RewardCampaignManagerArtifact,
            [rewardNFT.address]) as RewardCampaignManager;
        await campaignManager.addCampaign(campaignId);
        await rewardNFT.setCampaignManager(campaignManager.address);
        wooToken = await deployContract(owner, TestTokenArtifact, []);
        stakingManager = (await deployContract(owner, WooStakingManagerArtifact, [wooToken.address])) as WooStakingManager;
        nftBoosterV2 = (await deployContract(owner, NFTBoosterV2Artifact, [rewardNFT.address, stakingManager.address])) as NFTBoosterV2;
        await rewardNFT.setNFTBooster(nftBoosterV2.address);
    });

    it("NFTBoosterV2 Test1", async() => {
        let nftType = 1;
        let bucket = 0;
        await campaignManager.addUsers(campaignId, nftType, [owner.address]);
        await campaignManager["claim(uint256,address)"](campaignId, owner.address);

        await rewardNFT.setApprovalForAll(nftBoosterV2.address, true);
        await nftBoosterV2.stakeAndBurn(nftType, bucket);

        let boosterBalance = await rewardNFT.balanceOf(nftBoosterV2.address, nftType);
        expect(boosterBalance).to.be.equal(0);

        let [boosterRatio, stakeTokenIds] = await nftBoosterV2.boostRatio(owner.address);
        // console.log("boosterRatio: %s stakeTokenIds: %s", boosterRatio, stakeTokenIds);
        expect(boosterRatio).to.be.equal(10000);

        await nftBoosterV2.setBoostRatios([nftType], [11000]);
        [boosterRatio, stakeTokenIds] = await nftBoosterV2.boostRatio(owner.address);
        // console.log("boosterRatio: %s stakeTokenIds: %s", boosterRatio, stakeTokenIds);
        expect(boosterRatio).to.be.equal(11000);
    });

    it("NftBoosterV2 Test2", async() => {
        let nftType = 2;
        await rewardNFT.setBurnable(nftType, true);
        await campaignManager.addUsers(campaignId, nftType, [owner.address]);
        await campaignManager["claim(uint256,address)"](campaignId, owner.address);

        await rewardNFT.setApprovalForAll(nftBoosterV2.address, true);
        await nftBoosterV2.stakeAndBurn(nftType, 0);

        let boosterBalance = await rewardNFT.balanceOf(nftBoosterV2.address, nftType);
        expect(boosterBalance).to.be.equal(0);

        await nftBoosterV2.setBoostRatios([nftType], [11000]);
        let [boosterRatio, _] = await nftBoosterV2.boostRatio(owner.address);
        expect(boosterRatio).to.be.equal(11000);

        let campaign2 = 10;
        await campaignManager.addCampaign(campaign2);
        await campaignManager.addUsers(campaign2, nftType, [owner.address]);
        await campaignManager["claim(uint256,address)"](campaign2, owner.address);
        await nftBoosterV2.setActiveBucket(1, true);
        await nftBoosterV2.stakeAndBurn(nftType, 1);

        [boosterRatio, _] = await nftBoosterV2.boostRatio(owner.address);
        // console.log("boosterRatio: %s", boosterRatio);
        expect(boosterRatio).to.be.equal(12100);

        let campaign3 = 11;
        await campaignManager.addCampaign(campaign3);
        await campaignManager.addUsers(campaign3, nftType, [owner.address]);
        await campaignManager["claim(uint256,address)"](campaign3, owner.address);
        await nftBoosterV2.setActiveBucket(2, true);
        await nftBoosterV2.stakeAndBurn(nftType, 2);
        [boosterRatio, _] = await nftBoosterV2.boostRatio(owner.address);
        // console.log("boosterRatio: %s", boosterRatio);
        expect(boosterRatio).to.be.equal(13310);

        await nftBoosterV2.setActiveBucket(2, false);
        [boosterRatio, _] = await nftBoosterV2.boostRatio(owner.address);
        expect(boosterRatio).to.be.equal(12100);
    });

    it("Burnable Tests", async() => {
        let RELAXING = 4;
        let COMMON = 1;
        await rewardNFT.addTokenId(RELAXING, false);
        expect(await rewardNFT.burnables(RELAXING)).to.be.equal(false);
        expect(await rewardNFT.burnables(COMMON)).to.be.equal(true);
        await rewardNFT.setBurnable(RELAXING, true);
        expect(await rewardNFT.burnables(RELAXING)).to.be.equal(true);
    });

    it("Claim Tests", async() => {
        let balance;
        let nftType = 1;
        await campaignManager.addUsers(campaignId, nftType, [user2.address, user1.address]);
        balance = await rewardNFT.balanceOf(user1.address, nftType);
        expect(balance).to.be.equal(0);
        balance = await rewardNFT.balanceOf(user2.address, nftType);
        expect(balance).to.be.equal(0);
        await campaignManager["claim(uint256,address)"](campaignId, user2.address);
        await campaignManager["claim(uint256,address)"](campaignId, user1.address);

        balance = await rewardNFT.balanceOf(user1.address, nftType);
        expect(balance).to.be.equal(1);
        balance = await rewardNFT.balanceOf(user2.address, nftType);
        expect(balance).to.be.equal(1);

        await campaignManager["claim(uint256,address)"](campaignId, user2.address);
        balance = await rewardNFT.balanceOf(user2.address, nftType);
        expect(balance).to.be.equal(1);
    });

    it("Revert Tests", async() => {
        let nftType = 1;
        await campaignManager.addUsers(campaignId, nftType, [user3.address]);
        await campaignManager.removeCampaign(campaignId);
        await expect(
            campaignManager["claim(uint256,address)"](campaignId, user3.address))
            .to.be.revertedWith("RewardCampaignManager: !_campaignId");
        await campaignManager.addCampaign(campaignId);
    });

    it("Airdrop Tests", async() => {
        let oldBal2, oldBal3, newBal2, newBal3;
        let amount = 2;
        let nftType = 1;

        oldBal2 = await rewardNFT.balanceOf(user2.address, nftType);
        oldBal3 = await rewardNFT.balanceOf(user3.address, nftType);
        // console.log("oldBal user2, user3: %s %s", oldBal2, oldBal3);
        await rewardNFT.batchAirdrop([user2.address, user3.address], nftType, amount);
        newBal2 = await rewardNFT.balanceOf(user2.address, nftType);
        newBal3 = await rewardNFT.balanceOf(user3.address, nftType);

        // console.log("newBal user2, user3: %s %s", newBal2, newBal3);
        await expect(newBal2).to.be.equal(oldBal2.add(amount));

        await expect(newBal3).to.be.equal(oldBal3.add(amount));
    });
});
