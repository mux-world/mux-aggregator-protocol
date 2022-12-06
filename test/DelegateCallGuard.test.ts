import { ethers, network } from "hardhat"
import "@nomiclabs/hardhat-ethers"
import { expect } from "chai"
import { MockERC20, IGmxFastPriceFeed, IGmxPositionRouter, IGmxOrderBook, IGmxRouter, IGmxVault } from "../typechain"
import {
  toWei,
  toUnit,
  fromWei,
  fromUnit,
  createContract,
  rate,
  FastPriceFeedAddress,
  PositionRouterAddress,
  OrderBookAddress,
  executionFee,
  toGmxUsd,
  RouterAddress,
  VaultAddress,
  getBlockTime,
  getPriceBits,
  ReaderAddress,
  VaultReaderAddress,
  PositionManagerAddress,
  testCaseForkBlock,
  MuxOrderBookAddress,
  sleep,
} from "../scripts/deployUtils"
import { hardhatSetArbERC20Balance, hardhatSkipBlockTime } from "../scripts/deployUtils"
import { loadFixture, setBalance, time } from "@nomicfoundation/hardhat-network-helpers"
import { IGmxReader } from "../typechain/contracts/interfaces/IGmxReader"
import { IGmxPositionManager } from "../typechain/contracts/interfaces/IGmxPositionManager"

describe("DelegateCallGuard", () => {

  const pad32r = (s: string) => {
    if (s.length > 66) {
      return s;
    } else if (s.startsWith('0x') || s.startsWith('0X')) {
      return s + "0".repeat(66 - s.length)
    } else {
      return s + "0".repeat(64 - s.length)
    }
  }

  it("disable directly call", async () => {
    // recover snapshot
    const weth = await createContract("MockERC20", ["WETH", "WETH", 18])
    const liquidityPool = await createContract("MockLiquidityPool")
    await liquidityPool.setAssetAddress(1, weth.address)

    const libGmx = await createContract("LibGmx")
    const aggregator = await createContract("GmxAdapter", [weth.address], { LibGmx: libGmx })
    const factory = await createContract("ProxyFactory")
    await factory.initialize(weth.address, liquidityPool.address)

    const emptyAddr = "0x0000000000000000000000000000000000000000"
    const PROJECT_GMX = 1
    await factory.upgradeTo(PROJECT_GMX, aggregator.address)
    await factory.setProjectAssetConfig(PROJECT_GMX, weth.address, [toUnit("0.000", 5), toUnit("0.006", 5), toUnit("0.005", 5), toUnit("0.002", 5), 0, toUnit("0.001", 5)]);
    await factory.setBorrowConfig(PROJECT_GMX, weth.address, 1, toWei("1000"))

    await factory.createProxy(PROJECT_GMX, weth.address, weth.address, true)

    await expect(aggregator.initialize(PROJECT_GMX, liquidityPool.address, emptyAddr, weth.address, weth.address, true)).to.be.revertedWith("")
  })

})
