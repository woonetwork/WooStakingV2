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

import { expect, use } from "chai";
import { Contract, utils } from 'ethers'
import { ethers } from "hardhat";
import { deployContract, deployMockContract } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { RewardNFT, NftBooster } from "../../typechain";
import RewardNFTArtifact from "../../artifacts/contracts/RewardNFT.sol/RewardNFT.json";
import NftBoosterArtifact from "../../artifacts/contracts/rewarders/NftBooster.sol/NftBooster.json";



describe("RewardNFT tests", () => {

    let owner: SignerWithAddress;

    let rewardNFT: RewardNFT;
    let nftBooster: NftBooster;
    let user: SignerWithAddress;
    let user1: SignerWithAddress;
    let user2: SignerWithAddress;

    let usdcToken: Contract;

    beforeEach(async () => {
        const signers = await ethers.getSigners();
        owner = signers[0];
        user = signers[2];
        user1 = signers[3];
        user2 = signers[4];

        rewardNFT = await deployContract(owner, RewardNFTArtifact, []) as RewardNFT;
        await rewardNFT.setCampaign(1);


        nftBooster = (await deployContract(owner, NftBoosterArtifact, [rewardNFT.address])) as NftBooster;

    });

    it("NftBooster Tests", async() => {
        await rewardNFT.setCampaign(2);
        await rewardNFT.addUsers(0, [owner.address]);
        await rewardNFT["claim(address)"](owner.address);

        await rewardNFT.setApprovalForAll(nftBooster.address, true);
        await nftBooster.stakeNft(0);

        let boosterBalance = await rewardNFT.balanceOf(nftBooster.address, 0);
        // console.log("boosterBalance: %s", boosterBalance);
        expect(boosterBalance).to.be.equal(1);

        await rewardNFT.setCampaign(1);
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
        await rewardNFT.addUsers(0, [user2.address]);
        await rewardNFT["claim(address)"](user2.address);

        balance = await rewardNFT.balanceOf(user2.address, 0);
        expect(balance).to.be.equal(1);

        await rewardNFT["claim(address)"](user2.address);
        balance = await rewardNFT.balanceOf(user2.address, 0);
        expect(balance).to.be.equal(1);
    });

    // it("Transfer Tests", async () => {
    //     const nftType = 0; // epic
    //     const nftAmount = await rewardNFT.balanceOf(rewardNFT.address, nftType);
    //     console.log("nftAmount: %s", nftAmount);

    //     await rewardNFT.safeTransfer(nftType, user.address, 1);
    //     const userEpic = await rewardNFT.balanceOf(user.address, nftType);
    //     // console.log("user Amount: %s", userEpic);
    //     expect(userEpic).to.be.equal(1);

    //     // await rewardNFT.safeBatchTransferFrom(owner.address, user1.address, [0,1], [50,100], []);
    //     // const user1Silver = await rewardNFT.balanceOf(user1.address, 1);
    //     // console.log("user1 SilverAmount: %s", user1Silver);

    // });

    function delay(ms: number) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
});
