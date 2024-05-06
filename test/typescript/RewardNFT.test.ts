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

import { RewardNFT, NftBooster, RewardCampaignManager } from "../../typechain";
import RewardNFTArtifact from "../../artifacts/contracts/RewardNFT.sol/RewardNFT.json";
import NftBoosterArtifact from "../../artifacts/contracts/rewarders/NftBooster.sol/NftBooster.json";
import RewardCampaignManagerArtifact from "../../artifacts/contracts/RewardCampaignManager.sol/RewardCampaignManager.json";



describe("RewardNFT tests", () => {

    let owner: SignerWithAddress;

    let rewardNFT: RewardNFT;
    let nftBooster: NftBooster;
    let campaignManager: RewardCampaignManager;
    let user: SignerWithAddress;
    let user1: SignerWithAddress;
    let user2: SignerWithAddress;
    let user3: SignerWithAddress;

    let usdcToken: Contract;
    let campaignId = 1;

    beforeEach(async () => {
        const signers = await ethers.getSigners();
        owner = signers[0];
        user = signers[1];
        user1 = signers[2];
        user2 = signers[3];
        user3 = signers[4];

        rewardNFT = await deployContract(owner, RewardNFTArtifact, []) as RewardNFT;
        campaignManager = await deployContract(owner, RewardCampaignManagerArtifact,
            [rewardNFT.address]) as RewardCampaignManager;
        await campaignManager.addCampaign(campaignId);
        await rewardNFT.setCampaignManager(campaignManager.address);
        nftBooster = (await deployContract(owner, NftBoosterArtifact, [rewardNFT.address])) as NftBooster;
    });

    it("NftBooster Tests", async() => {
        await campaignManager.addUsers(1, 0, [owner.address]);
        await campaignManager["claim(uint256,address)"](campaignId, owner.address);

        await rewardNFT.setApprovalForAll(nftBooster.address, true);
        await nftBooster.stakeNft(0);

        let boosterBalance = await rewardNFT.balanceOf(nftBooster.address, 0);
        expect(boosterBalance).to.be.equal(1);
    });

    it("Burnable Tests", async() => {
        let RELAXING = 3;
        let COMMON = 2;
        await rewardNFT.addNFTType(RELAXING, true);
        expect(await rewardNFT.burnable(RELAXING)).to.be.equal(true);
        expect(await rewardNFT.burnable(COMMON)).to.be.equal(false);
        await rewardNFT.setBurnable(RELAXING, false);
        expect(await rewardNFT.burnable(RELAXING)).to.be.equal(false);
    });

    it("Claim Tests", async() => {
        let balance;
        await campaignManager.addUsers(campaignId, 0, [user2.address, user1.address]);
        balance = await rewardNFT.balanceOf(user1.address, 0);
        expect(balance).to.be.equal(0);
        balance = await rewardNFT.balanceOf(user2.address, 0);
        expect(balance).to.be.equal(0);
        await campaignManager["claim(uint256,address)"](campaignId, user2.address);
        await campaignManager["claim(uint256,address)"](campaignId, user1.address);

        balance = await rewardNFT.balanceOf(user1.address, 0);
        expect(balance).to.be.equal(1);
        balance = await rewardNFT.balanceOf(user2.address, 0);
        expect(balance).to.be.equal(1);

        await campaignManager["claim(uint256,address)"](campaignId, user2.address);
        balance = await rewardNFT.balanceOf(user2.address, 0);
        expect(balance).to.be.equal(1);
    });

    it("Revert Tests", async() => {
        await campaignManager.addUsers(campaignId, 0, [user3.address]);
        await campaignManager.removeCampaign(campaignId);
        await expect(
            campaignManager["claim(uint256,address)"](campaignId, user3.address))
            .to.be.revertedWith("RewardCampaignManager: !campaignId");
        await campaignManager.addCampaign(campaignId);
    });

    it("Airdrop Tests", async() => {
        let oldBal2, oldBal3, newBal2, newBal3;
        let amount = 2;

        oldBal2 = await rewardNFT.balanceOf(user2.address, 0);
        oldBal3 = await rewardNFT.balanceOf(user3.address, 0);
        // console.log("oldBal user2, user3: %s %s", oldBal2, oldBal3);
        await rewardNFT.batchAirdrop([user2.address, user3.address], 0, amount);
        newBal2 = await rewardNFT.balanceOf(user2.address, 0);
        newBal3 = await rewardNFT.balanceOf(user3.address, 0);

        // console.log("newBal user2, user3: %s %s", newBal2, newBal3);
        await expect(newBal2).to.be.equal(oldBal2.add(amount));

        await expect(newBal3).to.be.equal(oldBal3.add(amount));
    });
});
