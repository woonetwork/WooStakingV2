import { Log } from "@ethersproject/providers";
import chai from "chai";
import { BigNumber, Event, utils } from "ethers";
import { EventFragment } from "ethers/lib/utils";
import { ethers, waffle } from "hardhat";

const { expect } = chai;
const provider = waffle.provider;

export const TimeFor1Days: number = 1 * 24 * 3600;
export const TimeFor3Days: number = 3 * 24 * 3600;
export const TimeFor5Days: number = 5 * 24 * 3600;
export const TimeFor7Days: number = 7 * 24 * 3600;
export const TimeFor1Week: number = 7 * 24 * 3600;
export const TimeFor10Days: number = 10 * 24 * 3600;
export const TimeFor30Days: number = 30 * 24 * 3600;
export const TimeFor90Days: number = 90 * 24 * 3600;
export const TimeFor1Years: number = 365 * 24 * 3600;
export const TimeFor4Years: number = 4 * 365 * 24 * 3600;

export function getHashValue(str: string): string {
  return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(str));
}

export async function latestTime(): Promise<number> {
  const rslt = await latestBlock();
  return rslt.ts;
}

export function max(a: number, b: number): number {
  return a > b ? a : b;
}

export function roundedByWeek(ts: number): number {
  return ts - (ts % TimeFor1Week);
}

export async function latestBlock(): Promise<{ num: number; ts: number }> {
  const latestBlock = await provider.getBlock("latest");
  return { num: latestBlock.number, ts: latestBlock.timestamp };
}

export function getTokenAmount(num: string): BigNumber {
  return ethers.utils.parseEther(num);
}

export async function getLatestBlockTime(): Promise<number> {
  return (await ethers.provider.getBlock("latest")).timestamp;
}

export async function fastForward(timeDelta: number): Promise<void> {
  await ethers.provider.send("evm_mine", []); // force mine the next block
  await ethers.provider.send("evm_increaseTime", [timeDelta]);
  await ethers.provider.send("evm_mine", []); // force mine the next block
}

export async function mineBlockAtTimestamp(timestamp: number): Promise<void> {
  await ethers.provider.send("evm_setNextBlockTimestamp", [timestamp]);
  await ethers.provider.send("evm_mine", []);
}

export function roundDownToNearestWeek(timestamp: number): number {
  const week = 7 * 24 * 3600;
  return Math.floor(timestamp / week) * week;
}
