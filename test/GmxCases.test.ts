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

describe("GmxCases", () => {
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
    const gmxFastPriceFeed = (await ethers.getContractAt(
      "IGmxFastPriceFeed",
      FastPriceFeedAddress
    )) as IGmxFastPriceFeed
    const gmxPositionRouter = (await ethers.getContractAt(
      "IGmxPositionRouter",
      PositionRouterAddress
    )) as IGmxPositionRouter
    const gmxPositionManager = (await ethers.getContractAt(
      "IGmxPositionManager",
      PositionManagerAddress
    )) as IGmxPositionManager
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
    return {
      weth,
      usdc,
      priceUpdater,
      gmxFastPriceFeed,
      gmxPositionRouter,
      gmxPositionManager,
      gmxOrderBook,
      gmxRouter,
      gmxVault,
      gmxReader,
      gmxVaultReader,
    }
  }

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    })
  })

  const zeroBytes32 = "0x0000000000000000000000000000000000000000000000000000000000000000"

  // it("long ETH, collateral = USDC", async () => {
  //   // recover snapshot
  //   // recover snapshot
  //   const [_, trader1] = await ethers.getSigners()
  //   const { weth, usdc, priceUpdater, gmxFastPriceFeed, gmxPositionRouter, gmxOrderBook, gmxRouter, gmxVault } = await loadFixture(deployTokenFixture)

  //   const setGmxPrice = async (price: any) => {
  //     const blockTime = await getBlockTime()
  //     await gmxFastPriceFeed.connect(priceUpdater).setPricesWithBits(getPriceBits([price, price, price, price]), blockTime)
  //   }

  //   // give me some token
  //   await hardhatSetArbERC20Balance(usdc.address, trader1.address, toUnit("3000", 6))
  //   // await hardhatSetArbERC20Balance(weth.address, trader1.address, toWei("1"))
  //   expect(await usdc.balanceOf(trader1.address)).to.eq(toUnit("3000", 6))
  //   // expect(await weth.balanceOf(trader1.address)).to.eq(toWei("1"))

  //   const liquidityPool = await createContract("MockLiquidityPool")
  //   // USDC
  //   await liquidityPool.setAssetAddress(0, usdc.address)
  //   await hardhatSetArbERC20Balance(usdc.address, liquidityPool.address, toWei("100000"))

  //   await liquidityPool.setAssetAddress(1, weth.address)
  //   await liquidityPool.setAssetFunding(1, toWei("0.03081"), toWei("50.460957"))
  //   await hardhatSetArbERC20Balance(weth.address, liquidityPool.address, toWei("100000"))

  //   const PROJECT_GMX = 1

  //   const libGmx = await createContract("LibGmx")
  //   const aggregator = await createContract("TestGmxAdapter", [wethAddress], { LibGmx: libGmx })
  //   const factory = await createContract("ProxyFactory")
  //   await factory.initialize(weth.address, liquidityPool.address)
  //   await factory.setProjectConfig(PROJECT_GMX, defaultProjectConfig)
  //   await factory.setProjectAssetConfig(PROJECT_GMX, usdc.address, defaultAssetConfig())
  //   await factory.setProjectAssetConfig(PROJECT_GMX, weth.address, defaultAssetConfig())
  //   await factory.setBorrowConfig(PROJECT_GMX, usdc.address, 0, toWei("1000"))
  //   await factory.setBorrowConfig(PROJECT_GMX, weth.address, 1, toWei("1000"))
  //   await factory.upgradeTo(PROJECT_GMX, aggregator.address)
  //   await factory.setKeeper(priceUpdater.address, true)

  //   const executionFee = await gmxPositionRouter.minExecutionFee()
  //   console.log(executionFee)

  //   // await hardhatSetArbERC20Balance(weth.address, trader1.address, toWei("10"))
  //   await weth.connect(trader1).approve(factory.address, toWei("10000"))
  //   await usdc.connect(trader1).approve(factory.address, toWei("10000"))

  //   await setGmxPrice("1295.9")
  //   await factory.connect(trader1).openPositionV2(
  //     {
  //       projectId: 1,
  //       collateralToken: weth.address,
  //       assetToken: weth.address,
  //       isLong: true,
  //       tokenIn: weth.address,
  //       amountIn: toWei("0.011117352"), // 1
  //       minOut: toWei("0.011117352"),
  //       borrow: toWei("0.023333333333333334"),
  //       sizeUsd: toWei("1296.5"),
  //       priceUsd: toWei("1296.5"),
  //       flags: 0x40,
  //       referralCode: zeroBytes32,
  //     },
  //     { value: executionFee.add(toWei("0.011117352")) }
  //   )

  //   const [_proxy] = await factory.getProxiesOf(trader1.address)
  //   const orderKey = ethers.utils.solidityKeccak256(["address", "uint256"], [_proxy, 1])
  //   const gmxOrder = await gmxPositionRouter.increasePositionRequests(orderKey)
  //   expect(gmxOrder.amountIn).to.be.closeTo(toWei("0.034334018666666667"), toUnit("1", 10))

  //   await setGmxPrice("1296.5")
  //   await gmxPositionRouter.connect(priceUpdater).executeIncreasePosition(orderKey, trader1.address)

  //   const proxy = await ethers.getContractAt("TestGmxAdapter", _proxy)
  //   var position = await proxy.getGmxPosition()
  //   expect(position.sizeUsd).to.equal(toUnit("1296.5", 30))
  //   expect(position.collateralUsd).to.be.closeTo(toUnit("43.217555201333334193345", 30), toUnit("1", 20))
  //   expect(position.entryFundingRate).to.equal("329642")
  //   expect(position.averagePrice).to.equal(toUnit("1296.5", 30))
  //   expect(await proxy.getMarginValue()).to.be.closeTo(toUnit("12.965888534666666662345", 30), toUnit("1", 20))

  //   await factory.connect(trader1).openPositionV2(
  //     {
  //       projectId: 1,
  //       collateralToken: weth.address,
  //       assetToken: weth.address,
  //       isLong: true,
  //       tokenIn: weth.address,
  //       amountIn: toWei("0.011117352"), // 1
  //       minOut: toWei("0.011117352"),
  //       borrow: toWei("0.023333333333333334"),
  //       sizeUsd: toWei("1296.5"),
  //       priceUsd: toWei("1296.5"),
  //       flags: 0x00,
  //       referralCode: zeroBytes32,
  //     },
  //     { value: executionFee.add(toWei("0.011117352")) }
  //   )

  //   await factory.connect(trader1).openPositionV2(
  //     {
  //       projectId: 1,
  //       collateralToken: weth.address,
  //       assetToken: weth.address,
  //       isLong: true,
  //       tokenIn: weth.address,
  //       amountIn: toWei("0.011117352"), // 1
  //       minOut: toWei("0.011117352"),
  //       borrow: toWei("0.023333333333333334"),
  //       sizeUsd: toWei("1296.5"),
  //       priceUsd: toWei("1296.5"),
  //       flags: 0x00,
  //       referralCode: zeroBytes32,
  //     },
  //     { value: executionFee.add(toWei("0.011117352")) }
  //   )

  //   await time.increase(3600 * 24)

  //   console.log("close ============================================================")
  //   await liquidityPool.setAssetFunding(1, toWei("0.03111"), toWei("51.0495615"))

  //   await setGmxPrice("1298.5")
  //   var position = await proxy.getGmxPosition()
  //   await factory.connect(trader1).closePositionV2(
  //     {
  //       projectId: 1,
  //       collateralToken: weth.address,
  //       assetToken: weth.address,
  //       isLong: true,
  //       collateralUsd: toWei("6.455717258343739251"),
  //       sizeUsd: toWei("1296.5").div(2),
  //       priceUsd: toWei("1298.5"),
  //       flags: 0x40,
  //       referralCode: zeroBytes32,
  //     },
  //     { value: executionFee }
  //   )
  //   await gmxPositionRouter.connect(priceUpdater).executeDecreasePosition(orderKey, trader1.address)
  //   // expect(await weth.balanceOf(proxy.address)).to.be.closeTo(toWei("0.033417083713002182"), 1000)
  //   // const before = await ethers.provider.getBalance(trader1.address)
  //   await proxy.connect(priceUpdater).withdraw()

  //   // expect(await proxy.getMarginValue()).to.be.closeTo(toUnit("7.436264202000461781595", 30), toUnit("1", 20))
  //   expect(await proxy.getMarginValue()).to.be.closeTo(toUnit("7.436236109656261612", 30), toUnit("1", 20))

  //   const keys = await proxy.getPendingGmxOrderKeys();
  //   console.log(keys)
  //   await proxy.connect(trader1).cancelOrders([keys[keys.length - 1]])
  //   expect(await proxy.getMarginValue()).to.be.closeTo(toUnit("7.436236109656261612", 30), toUnit("1", 20))
  // })

  it("partial close short ETH, collateral = USDC. pnl < 0. open open open close", async () => {
    // recover snapshot
    const [_, trader1] = await ethers.getSigners()
    const { weth, usdc, priceUpdater, gmxFastPriceFeed, gmxPositionRouter, gmxOrderBook, gmxRouter, gmxVault } =
      await loadFixture(deployTokenFixture)

    const setGmxPrice = async (price: any) => {
      const blockTime = await getBlockTime()
      await gmxFastPriceFeed
        .connect(priceUpdater)
        .setPricesWithBits(getPriceBits([price, price, price, price]), blockTime)
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
    await factory.setProjectAssetConfig(PROJECT_GMX, usdc.address, defaultAssetConfig())
    await factory.setProjectAssetConfig(PROJECT_GMX, weth.address, defaultAssetConfig())
    await factory.setBorrowConfig(PROJECT_GMX, usdc.address, 0, toWei("1000"))
    await factory.setBorrowConfig(PROJECT_GMX, weth.address, 1, toWei("1000"))
    await factory.upgradeTo(PROJECT_GMX, aggregator.address)
    await factory.setKeeper(priceUpdater.address, true)

    const executionFee = await gmxPositionRouter.minExecutionFee()
    console.log(executionFee)

    // await hardhatSetArbERC20Balance(weth.address, trader1.address, toWei("10"))
    await weth.connect(trader1).approve(factory.address, toWei("10000"))
    await usdc.connect(trader1).approve(factory.address, toWei("10000"))

    await setGmxPrice("1295.9")
    await factory.connect(trader1).openPositionV2(
      {
        projectId: 1,
        collateralToken: usdc.address,
        assetToken: weth.address,
        isLong: false,
        tokenIn: usdc.address,
        amountIn: toUnit("14.412759", 6), // 1
        minOut: toWei("0"),
        borrow: toUnit("30.251667", 6),
        sizeUsd: toWei("1296.5"),
        priceUsd: toWei("1296.5"),
        tpPriceUsd: 0,
        slPriceUsd: 0,
        flags: 0x40,
        referralCode: zeroBytes32,
      },
      { value: executionFee }
    )
    console.log("placed")

    const [_proxy] = await factory.getProxiesOf(trader1.address)
    const orderKey = ethers.utils.solidityKeccak256(["address", "uint256"], [_proxy, 1])
    const gmxOrder = await gmxPositionRouter.increasePositionRequests(orderKey)
    expect(gmxOrder.amountIn).to.be.closeTo(toUnit("44.513168", 6), 10)

    await setGmxPrice("1296.5")
    await gmxPositionRouter.connect(priceUpdater).executeIncreasePosition(orderKey, trader1.address)

    const proxy = await ethers.getContractAt("TestGmxAdapter", _proxy)
    var position = await proxy.getGmxPosition()
    expect(position.sizeUsd).to.equal(toUnit("1296.5", 30))
    expect(position.collateralUsd).to.be.closeTo(toUnit("43.216668", 30), toUnit("1", 20))
    expect(position.entryFundingRate).to.equal("212231")
    expect(position.averagePrice).to.equal(toUnit("1296.5", 30))
    expect(await proxy.getMarginValue()).to.be.closeTo(toUnit("12.965001", 30), toUnit("1", 20))

    await factory.connect(trader1).openPositionV2(
      {
        projectId: 1,
        collateralToken: usdc.address,
        assetToken: weth.address,
        isLong: false,
        tokenIn: usdc.address,
        amountIn: toUnit("14.412759", 6), // 1
        minOut: toWei("0"),
        borrow: toUnit("30.251667", 6),
        sizeUsd: toWei("1296.5"),
        priceUsd: toWei("1296.5"),
        tpPriceUsd: 0,
        slPriceUsd: 0,
        flags: 0x00,
        referralCode: zeroBytes32,
      },
      { value: executionFee }
    )

    await factory.connect(trader1).openPositionV2(
      {
        projectId: 1,
        collateralToken: usdc.address,
        assetToken: weth.address,
        isLong: false,
        tokenIn: usdc.address,
        amountIn: toUnit("14.412759", 6), // 1
        minOut: toWei("0"),
        borrow: toUnit("30.251667", 6),
        sizeUsd: toWei("1296.5"),
        priceUsd: toWei("1296.5"),
        tpPriceUsd: 0,
        slPriceUsd: 0,
        flags: 0x00,
        referralCode: zeroBytes32,
      },
      { value: executionFee }
    )

    await time.increase(3600 * 24)

    console.log("close ============================================================")
    await liquidityPool.setAssetFunding(1, toWei("0.03111"), toWei("51.0495615"))

    await setGmxPrice("1298.5")
    var position = await proxy.getGmxPosition()
    await factory.connect(trader1).closePositionV2(
      {
        projectId: 1,
        collateralToken: usdc.address,
        assetToken: weth.address,
        isLong: false,
        collateralUsd: toWei("5.441362326832652092"),
        sizeUsd: toWei("1296.5").div(2),
        priceUsd: toWei("1298.5"),
        tpPriceUsd: 0,
        slPriceUsd: 0,
        flags: 0x40,
        referralCode: zeroBytes32,
      },
      { value: executionFee }
    )
    await gmxPositionRouter.connect(priceUpdater).executeDecreasePosition(orderKey, trader1.address)
    const before = await usdc.balanceOf(trader1.address)
    await proxy.connect(priceUpdater).withdraw()

    expect(await proxy.getMarginValue()).to.be.closeTo(toUnit("5.482500673167347908", 30), toUnit("1", 20))

    const keys = await proxy.getPendingGmxOrderKeys()
    console.log(keys)
    await proxy.connect(trader1).cancelOrders([keys[keys.length - 1]])
    expect(await proxy.getMarginValue()).to.be.closeTo(toUnit("5.482500673167347908", 30), toUnit("1", 20))
  })

  it("partial close short ETH, collateral = USDC. pnl < 0. open close", async () => {
    // recover snapshot
    const [_, trader1] = await ethers.getSigners()
    const { weth, usdc, priceUpdater, gmxFastPriceFeed, gmxPositionRouter, gmxOrderBook, gmxRouter, gmxVault } =
      await loadFixture(deployTokenFixture)

    const setGmxPrice = async (price: any) => {
      const blockTime = await getBlockTime()
      await gmxFastPriceFeed
        .connect(priceUpdater)
        .setPricesWithBits(getPriceBits([price, price, price, price]), blockTime)
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
    await factory.setProjectAssetConfig(PROJECT_GMX, usdc.address, defaultAssetConfig())
    await factory.setProjectAssetConfig(PROJECT_GMX, weth.address, defaultAssetConfig())
    await factory.setBorrowConfig(PROJECT_GMX, usdc.address, 0, toWei("1000"))
    await factory.setBorrowConfig(PROJECT_GMX, weth.address, 1, toWei("1000"))
    await factory.upgradeTo(PROJECT_GMX, aggregator.address)
    await factory.setKeeper(priceUpdater.address, true)

    const executionFee = await gmxPositionRouter.minExecutionFee()
    console.log(executionFee)

    // await hardhatSetArbERC20Balance(weth.address, trader1.address, toWei("10"))
    await weth.connect(trader1).approve(factory.address, toWei("10000"))
    await usdc.connect(trader1).approve(factory.address, toWei("10000"))

    await setGmxPrice("1295.9")
    await factory.connect(trader1).openPositionV2(
      {
        projectId: 1,
        collateralToken: usdc.address,
        assetToken: weth.address,
        isLong: false,
        tokenIn: usdc.address,
        amountIn: toUnit("14.412759", 6), // 1
        minOut: toWei("0"),
        borrow: toUnit("30.251667", 6),
        sizeUsd: toWei("1296.5"),
        priceUsd: toWei("1296.5"),
        tpPriceUsd: 0,
        slPriceUsd: 0,
        flags: 0x40,
        referralCode: zeroBytes32,
      },
      { value: executionFee }
    )
    console.log("placed")

    const [_proxy] = await factory.getProxiesOf(trader1.address)
    const orderKey = ethers.utils.solidityKeccak256(["address", "uint256"], [_proxy, 1])
    const gmxOrder = await gmxPositionRouter.increasePositionRequests(orderKey)
    expect(gmxOrder.amountIn).to.be.closeTo(toUnit("44.513168", 6), 10)

    await setGmxPrice("1296.5")
    await gmxPositionRouter.connect(priceUpdater).executeIncreasePosition(orderKey, trader1.address)

    const proxy = await ethers.getContractAt("TestGmxAdapter", _proxy)
    var position = await proxy.getGmxPosition()
    expect(position.sizeUsd).to.equal(toUnit("1296.5", 30))
    expect(position.collateralUsd).to.be.closeTo(toUnit("43.216668", 30), toUnit("1", 20))
    expect(position.entryFundingRate).to.equal("212231")
    expect(position.averagePrice).to.equal(toUnit("1296.5", 30))
    expect(await proxy.getMarginValue()).to.be.closeTo(toUnit("12.965001", 30), toUnit("1", 20))

    await time.increase(3600 * 24)

    console.log("close ============================================================")
    await liquidityPool.setAssetFunding(1, toWei("0.03111"), toWei("51.0495615"))

    await setGmxPrice("1298.5")
    var position = await proxy.getGmxPosition()
    await factory.connect(trader1).closePositionV2(
      {
        projectId: 1,
        collateralToken: usdc.address,
        assetToken: weth.address,
        isLong: false,
        collateralUsd: toWei("5.468788406718581914"),
        sizeUsd: toWei("1296.5").div(2),
        priceUsd: toWei("1298.5"),
        tpPriceUsd: 0,
        slPriceUsd: 0,
        flags: 0x40,
        referralCode: zeroBytes32,
      },
      { value: executionFee }
    )
    await gmxPositionRouter.connect(priceUpdater).executeDecreasePosition(orderKey, trader1.address)
    var before = await usdc.balanceOf(trader1.address)

    await proxy.connect(priceUpdater).withdraw()
    var debt = await proxy.debtStates()
    expect(debt.cumulativeDebt).to.equal(toUnit("30.251667", 6))
    expect(debt.cumulativeFee).to.equal(toUnit("0.013712", 6))

    var position = await proxy.getGmxPosition()
    expect(position.sizeUsd).to.equal(toUnit("648.25", 30))
    expect(position.collateralUsd).to.be.closeTo(toUnit("36.747879593281418086", 30), toUnit("1", 20))
    expect(position.entryFundingRate).to.equal("212828")
    expect(position.averagePrice).to.equal(toUnit("1296.5", 30))

    expect(await weth.balanceOf(proxy.address)).to.equal(0)
    var after = await usdc.balanceOf(trader1.address)
    expect(after.sub(before)).to.be.closeTo(toUnit("4.046527", 6), 10)
    console.log(after)

    const orderKey2 = ethers.utils.solidityKeccak256(["address", "uint256"], [_proxy, 2])
    await factory.connect(trader1).closePositionV2(
      {
        projectId: 1,
        collateralToken: usdc.address,
        assetToken: weth.address,
        isLong: false,
        collateralUsd: toWei("0"),
        sizeUsd: toWei("1296.5").div(2),
        priceUsd: toWei("1298.5"),
        tpPriceUsd: 0,
        slPriceUsd: 0,
        flags: 0x40,
        referralCode: zeroBytes32,
      },
      { value: executionFee }
    )
    await gmxPositionRouter.connect(priceUpdater).executeDecreasePosition(orderKey2, trader1.address)

    var debt = await proxy.debtStates()
    console.log(debt)

    var position = await proxy.getGmxPosition()
    console.log(position)

    var before = await usdc.balanceOf(trader1.address)
    await proxy.connect(priceUpdater).withdraw()

    var debt = await proxy.debtStates()
    console.log(debt)
    var after = await usdc.balanceOf(trader1.address)
    expect(after.sub(before)).to.be.closeTo(toUnit("4.682992", 6), 10)
    console.log(after)
  })
  
  it("open without principal, should fail", async () => {
    // recover snapshot
    const [_, trader1] = await ethers.getSigners()
    const { weth, usdc, priceUpdater, gmxFastPriceFeed, gmxPositionRouter, gmxOrderBook, gmxRouter, gmxVault } =
      await loadFixture(deployTokenFixture)

    const setGmxPrice = async (price: any) => {
      const blockTime = await getBlockTime()
      await gmxFastPriceFeed
        .connect(priceUpdater)
        .setPricesWithBits(getPriceBits([price, price, price, price]), blockTime)
    }

    // give me some token
    await hardhatSetArbERC20Balance(usdc.address, trader1.address, toUnit("3000", 6))
    
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
    await factory.setProjectAssetConfig(PROJECT_GMX, usdc.address, defaultAssetConfig())
    await factory.setProjectAssetConfig(PROJECT_GMX, weth.address, defaultAssetConfig())
    await factory.setBorrowConfig(PROJECT_GMX, usdc.address, 0, toWei("1000"))
    await factory.setBorrowConfig(PROJECT_GMX, weth.address, 1, toWei("1000"))
    await factory.upgradeTo(PROJECT_GMX, aggregator.address)
    await factory.setKeeper(priceUpdater.address, true)

    const executionFee = await gmxPositionRouter.minExecutionFee()
    console.log(executionFee)

    await setGmxPrice("1295.9")
    await expect(factory.connect(trader1).openPositionV2(
      {
        projectId: 1,
        collateralToken: usdc.address,
        assetToken: weth.address,
        isLong: false,
        tokenIn: usdc.address,
        amountIn: toUnit("0", 6),
        minOut: toWei("0"),
        borrow: toUnit("1000", 6),
        sizeUsd: toWei("1296.5"),
        priceUsd: toWei("1296.5"),
        tpPriceUsd: 0,
        slPriceUsd: 0,
        flags: 0x40,
        referralCode: zeroBytes32,
      },
      { value: executionFee }
    )).to.be.revertedWith("ImMarginUnsafe");
  })
})
