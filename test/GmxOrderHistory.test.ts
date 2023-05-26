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
  defaultProjectConfig,
  defaultAssetConfig,
} from "../scripts/deployUtils"
import { hardhatSetArbERC20Balance, hardhatSkipBlockTime } from "../scripts/deployUtils"
import { loadFixture, setBalance, time } from "@nomicfoundation/hardhat-network-helpers"
import { IGmxReader } from "../typechain/contracts/interfaces/IGmxReader"
import { IGmxPositionManager } from "../typechain/contracts/interfaces/IGmxPositionManager"

describe("GmxOrderHistory", () => {
  const wethAddress = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1" // Arb1 WETH
  const usdcAddress = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8" // Arb1 USDC

  // We define a fixture to reuse the same setup in every test. We use
  // loadFixture to run this setup once, snapshot that state, and reset Hardhat
  // Network to that snapshot in every test.
  async function deployTokenFixture() {
    console.log("fixtures: generating...")
    const [priceUpdater, trader1] = await ethers.getSigners()

    // fork begins
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: "https://arb1.arbitrum.io/rpc",
            enabled: true,
            ignoreUnknownTxType: true, // added in our hardhat patch. see README.md
            blockNumber: testCaseForkBlock, // modify me if ./cache/hardhat-network-fork was cleared
          },
        },
      ],
    })

    // contracts
    const weth = (await ethers.getContractAt("MockERC20", wethAddress)) as MockERC20
    const usdc = (await ethers.getContractAt("MockERC20", usdcAddress)) as MockERC20
    const gmxFastPriceFeed = (await ethers.getContractAt("IGmxFastPriceFeed", FastPriceFeedAddress)) as IGmxFastPriceFeed
    const gmxPositionRouter = (await ethers.getContractAt("IGmxPositionRouter", PositionRouterAddress)) as IGmxPositionRouter
    const gmxPositionManager = (await ethers.getContractAt("IGmxPositionManager", PositionManagerAddress)) as IGmxPositionManager
    const gmxOrderBook = (await ethers.getContractAt("IGmxOrderBook", OrderBookAddress)) as IGmxOrderBook
    const gmxRouter = (await ethers.getContractAt("IGmxRouter", RouterAddress)) as IGmxRouter
    const gmxVault = (await ethers.getContractAt("IGmxVault", VaultAddress)) as IGmxVault
    const gmxReader = (await ethers.getContractAt("IGmxReader", ReaderAddress)) as IGmxReader
    const gmxVaultReader = (await ethers.getContractAt("IGmxReader", VaultReaderAddress)) as IGmxReader

    // set price updater
    const priceGovAddress = await gmxFastPriceFeed.gov()
    const priceGov = await ethers.getImpersonatedSigner(priceGovAddress)
    await setBalance(priceGov.address, toWei("1"))
    await gmxFastPriceFeed.connect(priceGov).setUpdater(priceUpdater.address, true)
    await setBalance(priceUpdater.address, toWei("1"))

    // set order keeper
    const positionAdminAddress = await gmxPositionManager.admin()
    const positionAdmin = await ethers.getImpersonatedSigner(positionAdminAddress)
    await setBalance(positionAdmin.address, toWei("1"))
    await gmxPositionManager.connect(positionAdmin).setOrderKeeper(priceUpdater.address, true)
    await gmxPositionRouter.connect(positionAdmin).setPositionKeeper(priceUpdater.address, true)

    // fixtures can return anything you consider useful for your tests
    console.log("fixtures: generated")
    return { weth, usdc, priceUpdater, gmxFastPriceFeed, gmxPositionRouter, gmxPositionManager, gmxOrderBook, gmxRouter, gmxVault, gmxReader, gmxVaultReader }
  }

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    })
  })

  const zBytes32 = "0x0000000000000000000000000000000000000000000000000000000000000000"
  const zAddress = "0x0000000000000000000000000000000000000000"

  it("orders", async () => {
    // recover snapshot
    const [_, trader1] = await ethers.getSigners()
    const { weth, usdc, priceUpdater, gmxFastPriceFeed, gmxPositionRouter, gmxOrderBook, gmxRouter, gmxVault } = await loadFixture(deployTokenFixture)

    const setGmxPrice = async (price: any) => {
      const blockTime = await getBlockTime()
      await gmxFastPriceFeed.connect(priceUpdater).setPricesWithBits(getPriceBits([price, price, price, price]), blockTime)
    }

    // give me some token
    await hardhatSetArbERC20Balance(usdc.address, trader1.address, toUnit("3000", 6))
    // await hardhatSetArbERC20Balance(weth.address, trader1.address, toWei("1"))
    expect(await usdc.balanceOf(trader1.address)).to.eq(toUnit("3000", 6))
    // expect(await weth.balanceOf(trader1.address)).to.eq(toWei("1"))

    const liquidityPool = await createContract("MockLiquidityPool")
    // USDC
    await liquidityPool.setAssetAddress(0, usdc.address)
    await hardhatSetArbERC20Balance(usdc.address, liquidityPool.address, toWei("100000"))

    await liquidityPool.setAssetAddress(1, weth.address)
    await liquidityPool.setAssetFunding(1, toWei("0.03081"), toWei("50.460957"))
    await hardhatSetArbERC20Balance(weth.address, liquidityPool.address, toWei("100000"))

    const PROJECT_GMX = 1

    const libGmx = await createContract("LibGmx")
    const aggregator = await createContract("TestGmxAdapter", [wethAddress], { LibGmx: libGmx })
    const factory = await createContract("ProxyFactory")
    await factory.initialize(weth.address, liquidityPool.address)
    await factory.setProjectConfig(PROJECT_GMX, defaultProjectConfig)
    await factory.setProjectAssetConfig(PROJECT_GMX, usdc.address, defaultAssetConfig());
    await factory.setProjectAssetConfig(PROJECT_GMX, weth.address, defaultAssetConfig());
    await factory.setBorrowConfig(PROJECT_GMX, usdc.address, 0, toWei("1000"))
    await factory.setBorrowConfig(PROJECT_GMX, weth.address, 1, toWei("1000"))
    await factory.upgradeTo(PROJECT_GMX, aggregator.address)
    await factory.setKeeper(priceUpdater.address, true);

    const executionFee = await gmxPositionRouter.minExecutionFee()
    console.log(executionFee)

    // await hardhatSetArbERC20Balance(weth.address, trader1.address, toWei("10"))
    await weth.connect(trader1).approve(factory.address, toWei("10000"))
    await usdc.connect(trader1).approve(factory.address, toWei("10000"))

    // create 1
    await factory.connect(trader1).openPosition(
      {
        projectId: 1,
        collateralToken: weth.address,
        assetToken: weth.address,
        isLong: true,
        tokenIn: usdc.address,
        amountIn: toUnit("14.493346", 6), // 1
        minOut: toWei("0"),
        borrow: toWei("0.01"),
        sizeUsd: toWei("1296.5"),
        priceUsd: toWei("1296.5"),
        tpPriceUsd: 0,
        slPriceUsd: 0,
        flags: 0x40,
        referralCode: zBytes32,
      },
      { value: executionFee }
    )

    const _proxy = await factory.getProxyAddress(PROJECT_GMX, trader1.address, weth.address, weth.address, true)
    const proxy = await ethers.getContractAt("TestGmxAdapter", _proxy)

    var order = await gmxPositionRouter.increasePositionRequests(
      ethers.utils.solidityKeccak256(["address", "uint256"], [proxy.address, 1])
    )
    expect(order.account).to.equal(proxy.address)

    {
      var keys = await proxy.getPendingGmxOrderKeys()
      expect(keys.length).to.equal(1)
      var history = await proxy.decodeOrderHistory(keys[0])
      expect(history.category).to.equal(1)
      expect(history.receiver).to.equal(0)
      expect(history.index).to.equal(1)
      expect(history.borrow).to.be.closeTo(toWei("0.01"), 1000)
    }
    // create 2
    await factory.connect(trader1).openPosition(
      {
        projectId: 1,
        collateralToken: weth.address,
        assetToken: weth.address,
        isLong: true,
        tokenIn: usdc.address,
        amountIn: toUnit("14.493346", 6), // 1
        minOut: toWei("0"),
        borrow: toWei("0.02"),
        sizeUsd: toWei("1296.5"),
        priceUsd: toWei("1296.5"),
        tpPriceUsd: 0,
        slPriceUsd: 0,
        flags: 0x40,
        referralCode: zBytes32,
      },
      { value: executionFee }
    )
    var order = await gmxPositionRouter.increasePositionRequests(
      ethers.utils.solidityKeccak256(["address", "uint256"], [proxy.address, 1])
    )
    expect(order.account).to.equal(proxy.address)
    var order = await gmxPositionRouter.increasePositionRequests(
      ethers.utils.solidityKeccak256(["address", "uint256"], [proxy.address, 2])
    )
    console.log("order.blockTime", order.blockTime)
    expect(order.account).to.equal(proxy.address)
    {
      var keys = await proxy.getPendingGmxOrderKeys()
      expect(keys.length).to.equal(2)
      var history = await proxy.decodeOrderHistory(keys[1])
      expect(history.category).to.equal(1)
      expect(history.receiver).to.equal(0)
      expect(history.index).to.equal(2)
      expect(history.borrow).to.be.closeTo(toWei("0.02"), 1000)
      expect(await proxy.hasPendingOrder(keys[0])).to.be.true
      expect(await proxy.hasPendingOrder(keys[1])).to.be.true
      expect(await proxy.hasPendingOrder(zBytes32)).to.be.false
    }

    // cancel 2
    var keys = await proxy.getPendingGmxOrderKeys()

    await time.increase(360)

    console.log("current", await getBlockTime())
    await proxy.connect(trader1).cancelOrders([keys[1]])
    {
      var keys = await proxy.getPendingGmxOrderKeys()
      expect(keys.length).to.equal(1)
      var history = await proxy.decodeOrderHistory(keys[0])
      expect(history.category).to.equal(1)
      expect(history.receiver).to.equal(0)
      expect(history.index).to.equal(1)
      expect(history.borrow).to.be.closeTo(toWei("0.01"), 1000)

      var order = await gmxPositionRouter.increasePositionRequests(
        ethers.utils.solidityKeccak256(["address", "uint256"], [proxy.address, 1])
      )
      expect(order.account).to.equal(proxy.address)

      var order = await gmxPositionRouter.increasePositionRequests(
        ethers.utils.solidityKeccak256(["address", "uint256"], [proxy.address, 2])
      )
      expect(order.account).to.equal(zAddress)
    }


    await proxy.withdraw();
    await factory.connect(trader1).openPosition(
      {
        projectId: 1,
        collateralToken: weth.address,
        assetToken: weth.address,
        isLong: true,
        tokenIn: usdc.address,
        amountIn: toUnit("14.493346", 6), // 1
        minOut: toWei("0"),
        borrow: toWei("0.015"),
        sizeUsd: toWei("1296.5"),
        priceUsd: toWei("1296.5"),
        tpPriceUsd: 0,
        slPriceUsd: 0,
        flags: 0x40,
        referralCode: zBytes32,
      },
      { value: executionFee }
    )
    {
      var keys = await proxy.getPendingGmxOrderKeys()
      expect(keys.length).to.equal(2)
      var history = await proxy.decodeOrderHistory(keys[1])
      expect(history.category).to.equal(1)
      expect(history.receiver).to.equal(0)
      expect(history.index).to.equal(3)
      expect(history.borrow).to.be.closeTo(toWei("0.015"), 1000)
    }
  })
})
