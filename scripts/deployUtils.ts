import { ethers } from "hardhat"
import { BytesLike } from "ethers"
import { ContractTransaction, Contract, ContractReceipt } from "ethers"
import { TransactionReceipt } from "@ethersproject/providers"
import { hexlify, concat, zeroPad, arrayify } from "@ethersproject/bytes"
import { BigNumber as EthersBigNumber, BigNumberish, parseFixed, formatFixed } from "@ethersproject/bignumber"
import { BigNumber } from 'bignumber.js'
import chalk from "chalk"
import { time } from "@nomicfoundation/hardhat-network-helpers";

// GMX Arbitrum mainnet contracts
export const VaultAddress = "0x489ee077994B6658eAfA855C308275EAd8097C4A"
export const RouterAddress = "0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064"
export const VaultReaderAddress = "0xfebB9f4CAC4cD523598fE1C5771181440143F24A"
export const ReaderAddress = "0x2b43c90D1B727cEe1Df34925bcd5Ace52Ec37694"
export const GlpManagerAddress = "0x321F653eED006AD1C29D174e17d96351BDe22649"
export const RewardRouterAddress = "0xA906F338CB21815cBc4Bc87ace9e68c87eF8d8F1"
export const RewardReaderAddress = "0x8BFb8e82Ee4569aee78D03235ff465Bd436D40E0"
export const NativeTokenAddress = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"
export const GLPAddress = "0x4277f8F2c384827B5273592FF7CeBd9f2C1ac258"
export const GMXAddress = "0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a"
export const USDGAddress = "0x45096e7aA921f27590f8F19e457794EB09678141"
export const OrderBookAddress = "0x09f77E8A13De9a35a7231028187e9fD5DB8a2ACB"
export const OrderExecutorAddress = "0x7257ac5D0a0aaC04AA7bA2AC0A6Eb742E332c3fB"
export const OrderBookReaderAddress = "0xa27C20A7CF0e1C68C0460706bB674f98F362Bc21"
export const PositionRouterAddress = "0xb87a436B93fFE9D75c5cFA7bAcFff96430b09868"
export const PositionManagerAddress = "0x75E42e6f01baf1D6022bEa862A28774a9f8a4A0C"
export const ReferralStorageAddress = "0xe6fab3f0c7199b0d34d7fbe83394fc0e0d06e99d"
export const ReferralReaderAddress = "0x8Aa382760BCdCe8644C33e6C2D52f6304A76F5c8"
export const FastPriceFeedAddress = "0x11d62807dae812a0f1571243460bf94325f43bb7"
export const executionFee = "300000000000000"
export const pricePrecisions = [
  1000, // [0] WBTC
  1000, // [1] WETH
  1000, // [2] LINK
  1000, // [3] UNI
]
// MUX Arbitrum mainnet contracts
export const MuxLiquidityPoolAddress = "0x3e0199792Ce69DC29A0a36146bFa68bd7C8D6633"
export const MuxOrderBookAddress = "0xa19fD5aB6C8DCffa2A295F78a5Bb4aC543AAF5e3"
export const testCaseForkBlock = 30928378 // modify me if ./cache/hardhat-network-fork was cleared

export function toWei(n: string): EthersBigNumber {
  return ethers.utils.parseEther(n)
}

export function fromWei(n: BigNumberish): string {
  return ethers.utils.formatEther(n)
}

export function toUnit(n: string, decimals: number): EthersBigNumber {
  return parseFixed(n, decimals)
}

export function fromUnit(n: BigNumberish, decimals: number): string {
  return formatFixed(n, decimals)
}

export function toGmxUsd(n: string): EthersBigNumber {
  return parseFixed(n, 30)
}

export function fromGmxUsd(n: BigNumberish): string {
  return formatFixed(n, 30)
}

export function toBytes32(s: string): string {
  return ethers.utils.formatBytes32String(s)
}

export function fromBytes32(s: BytesLike): string {
  return ethers.utils.parseBytes32String(s)
}

export function rate(n: string): EthersBigNumber {
  return toUnit(n, 5)
}

export function printInfo(...message: any[]) {
  console.log(chalk.yellow("INF "), ...message)
}

export function printError(...message: any[]) {
  console.log(chalk.red("ERR "), ...message)
}

export async function createFactory(path: any, libraries: { [name: string]: { address: string } } = {}): Promise<any> {
  const parsed: { [name: string]: string } = {}
  for (var name in libraries) {
    parsed[name] = libraries[name].address
  }
  return await ethers.getContractFactory(path, { libraries: parsed })
}

export async function createContract(path: any, args: any = [], libraries: { [name: string]: { address: string } } = {}): Promise<Contract> {
  const factory = await createFactory(path, libraries)
  return await factory.deploy(...args)
}

export function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms))
}

export async function ensureFinished(transaction: Promise<Contract> | Promise<ContractTransaction>): Promise<TransactionReceipt | ContractReceipt> {
  const result: Contract | ContractTransaction = await transaction
  let receipt: TransactionReceipt | ContractReceipt
  if ((result as Contract).deployTransaction) {
    receipt = await (result as Contract).deployTransaction.wait()
  } else {
    receipt = await result.wait()
  }
  if (receipt.status !== 1) {
    throw new Error(`receipt err: ${receipt.transactionHash}`)
  }
  return receipt
}

export async function hardhatSetArbERC20Balance(tokenAddress: BytesLike, account: BytesLike, balance: BigNumberish) {
  const balanceSlot = 51
  let slot = ethers.utils.keccak256(ethers.utils.defaultAbiCoder.encode(["address", "uint"], [account, balanceSlot]))
  // remove padding for JSON RPC. ex: 0x0dd9ff... => 0xdd9ff...
  while (slot.startsWith("0x0")) {
    slot = "0x" + slot.slice(3)
  }
  const val = ethers.utils.defaultAbiCoder.encode(["uint256"], [balance])
  await ethers.provider.send("hardhat_setStorageAt", [tokenAddress, slot, val])
}

export async function hardhatSkipBlockTime(seconds: number) {
  await time.increase(86400)
}


export async function getBlockTime(): Promise<number> {
  const block = await ethers.provider.getBlock('latest')
  return block.timestamp
}

// price = 32bits-compact-format / tokenPrecision
export function getPriceBits(prices: string[]): string {
  if (prices.length > pricePrecisions.length) {
    throw new Error("max prices.length exceeded")
  }
  let priceBits = ''
  for (let i = 0; i < prices.length; i++) {
    let price = new BigNumber(prices[i])
    price = price.times(pricePrecisions[i])
    if (price.gt("2147483648")) { // 2^31
      throw new Error(`price exceeds bit limit ${prices[i]}`)
    }
    const priceHex = price.dp(0).toNumber().toString(16)
    priceBits = priceHex.padStart(8, '0') + priceBits
  }
  return '0x' + priceBits.padStart(64, '0')
}

export function makeSubAccountId(account: string, collateral: number, asset: number, isLong: boolean): string {
  return hexlify(
    concat([
      arrayify(account),
      [arrayify(EthersBigNumber.from(collateral))[0]],
      [arrayify(EthersBigNumber.from(asset))[0]],
      arrayify(EthersBigNumber.from(isLong ? 1 : 0)),
      zeroPad([], 9),
    ])
  )
}

const pad32r = (s: string) => {
  if (s.length > 66) {
    return s;
  } else if (s.startsWith('0x') || s.startsWith('0X')) {
    return s + "0".repeat(66 - s.length)
  } else {
    return s + "0".repeat(64 - s.length)
  }
}


export const defaultProjectConfig = [
  pad32r(VaultAddress),
  pad32r(PositionRouterAddress),
  pad32r(OrderBookAddress),
  pad32r(RouterAddress),
  ethers.utils.formatBytes32String(""),
  120,
  86400 * 2,
  1, // weth
]

export const defaultAssetConfig = () => [
  toUnit("0.005", 5),
  toUnit("0.006", 5),
  toUnit("0.005", 5),
  toUnit("0.002", 5),
  0,
  toUnit("0.001", 5),
]