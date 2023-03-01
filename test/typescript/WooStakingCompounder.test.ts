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
import { deployContract, deployMockContract } from "ethereum-waffle";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
const { mine } = require("@nomicfoundation/hardhat-network-helpers");

import { WooStakingCompounder } from "../../typechain";
import WooStakingManagerArtifact from "../../artifacts/contracts/WooStakingManager.sol/WooStakingManager.json";
import WooStakingCompounderArtifact from "../../artifacts/contracts/WooStakingCompounder.sol/WooStakingCompounder.json";


describe("WooStakingCompounder tests", () => {
    let compounder: WooStakingCompounder;
    let owner: SignerWithAddress;
    let user1: SignerWithAddress;
    let user2: SignerWithAddress;
    let stakingManager: Contract;

    before(async () => {
        [owner, user1, user2] = await ethers.getSigners();

        stakingManager = await deployMockContract(owner, WooStakingManagerArtifact.abi);
        await stakingManager.mock.owner.returns(owner.address);
        await stakingManager.mock.compoundAll.returns();

        compounder = (await deployContract(owner, WooStakingCompounderArtifact, [stakingManager.address])) as WooStakingCompounder;
    });

    it("User Tests", async () => {
        await expect(compounder.addUser())
            .to.emit(compounder, "AddUser")
            .withArgs(owner.address);
        await expect(compounder.addUsers([user1.address, user2.address]))
            .to.emit(compounder, "AddUser")
            .withArgs(user2.address);
        let totalUsers = await compounder.allUsersLength();
        expect(totalUsers).to.be.eq(3);

        await expect(compounder.removeUser()).to.be.revertedWith(
            "WooStakingCompounder: STILL_IN_COOL_DOWN"
        );

        await mine(10);
        await compounder.setCooldownDuration(2);

        await expect(compounder.removeUsers([user1.address]))
            .to.emit(compounder, "RemoveUser")
            .withArgs(user1.address);
        expect(await compounder.contains(user1.address)).to.be.eq(false);
        expect(await compounder.allUsersLength()).to.be.eq(2);

        let allUsers = await compounder.allUsers();
        expect(allUsers[0]).to.be.eq(owner.address);
        expect(allUsers[1]).to.be.eq(user2.address);

        await compounder.compound(0, 1);
        await compounder.compoundAll();
    });
});