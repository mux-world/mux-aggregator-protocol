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
import { gmx } from "../typechain/contracts/aggregators"
import { proxy } from "../typechain/@openzeppelin/contracts"

describe("GmxLiquidate", () => {
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

  it("long ETH, collateral = USDC", async () => {
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
        collateralToken: weth.address,
        assetToken: weth.address,
        isLong: true,
        tokenIn: usdc.address,
        amountIn: toUnit("14.464836", 6), // 1
        minOut: toWei("0.011117352"),
        borrow: toWei("0.023333333333333334"),
        sizeUsd: toWei("1296.5"),
        priceUsd: toWei("1296.5"),
        tpPriceUsd: 0,
        slPriceUsd: 0,
        flags: 0x40,
        referralCode: zeroBytes32,
      },
      { value: executionFee }
    )
    const [_proxy] = await factory.getProxiesOf(trader1.address)
    const orderKey = ethers.utils.solidityKeccak256(["address", "uint256"], [_proxy, 1])
    const gmxOrder = await gmxPositionRouter.increasePositionRequests(orderKey)
    expect(gmxOrder.amountIn).to.be.closeTo(toWei("0.034334018666666667"), toUnit("1", 10))

    await setGmxPrice("1296.5")
    await gmxPositionRouter.connect(priceUpdater).executeIncreasePosition(orderKey, trader1.address)

    const proxy = await ethers.getContractAt("TestGmxAdapter", _proxy)
    var position = await proxy.getGmxPosition()
    expect(position.sizeUsd).to.equal(toUnit("1296.5", 30))
    expect(await proxy.getMarginValue()).to.be.closeTo(toUnit("12.965888534666666662345", 30), toUnit("1", 20))

    console.log("close ============================================================")
    await liquidityPool.setAssetFunding(1, toWei("0.03111"), toWei("51.0495615"))

    await setGmxPrice("1286.5")
    var position = await proxy.getGmxPosition()
    await expect(
      factory.connect(trader1).closePositionV2(
        {
          projectId: 1,
          collateralToken: weth.address,
          assetToken: weth.address,
          isLong: true,
          collateralUsd: toWei("0"),
          sizeUsd: toWei("1296.5"),
          priceUsd: toWei("1200"),
          tpPriceUsd: 0,
          slPriceUsd: 0,
          flags: 0x40,
          referralCode: zeroBytes32,
        },
        { value: executionFee }
      )
    ).to.be.revertedWith("MmMarginUnsafe")

    const [value, isNeg] = await proxy.getMarginValue2()
    expect(isNeg).to.be.false

    var state = await proxy.muxAccountState()
    expect(state.isLiquidating).to.be.false
    await factory
      .connect(priceUpdater)
      .liquidatePosition(1, trader1.address, weth.address, weth.address, true, toWei("1200"), { value: executionFee })
    var state = await proxy.muxAccountState()
    expect(state.isLiquidating).to.be.true

    console.log(await proxy.getPendingGmxOrderKeys())
    await gmxPositionRouter.connect(priceUpdater).executeDecreasePosition(orderKey, trader1.address)

    console.log(await weth.balanceOf(proxy.address))
    await factory.connect(priceUpdater).withdraw(1, trader1.address, weth.address, weth.address, true)

    console.log(await proxy.debtStates())
    const debt = await proxy.debtStates()
    expect(debt.cumulativeDebt).to.equal(toWei("0"))
    expect(debt.cumulativeFee).to.equal(toWei("0"))
  })

  it("long ETH, collateral = USDC", async () => {
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
        collateralToken: weth.address,
        assetToken: weth.address,
        isLong: true,
        tokenIn: usdc.address,
        amountIn: toUnit("14.464836", 6), // 1
        minOut: toWei("0.011117352"),
        borrow: toWei("0.023333333333333334"),
        sizeUsd: toWei("1296.5"),
        priceUsd: toWei("1296.5"),
        tpPriceUsd: 0,
        slPriceUsd: 0,
        flags: 0x40,
        referralCode: zeroBytes32,
      },
      { value: executionFee }
    )
    const [_proxy] = await factory.getProxiesOf(trader1.address)
    const orderKey = ethers.utils.solidityKeccak256(["address", "uint256"], [_proxy, 1])
    const gmxOrder = await gmxPositionRouter.increasePositionRequests(orderKey)
    expect(gmxOrder.amountIn).to.be.closeTo(toWei("0.034334018666666667"), toUnit("1", 10))

    await setGmxPrice("1296.5")
    await gmxPositionRouter.connect(priceUpdater).executeIncreasePosition(orderKey, trader1.address)

    const proxy = await ethers.getContractAt("TestGmxAdapter", _proxy)
    var position = await proxy.getGmxPosition()
    expect(position.sizeUsd).to.equal(toUnit("1296.5", 30))
    expect(await proxy.getMarginValue()).to.be.closeTo(toUnit("12.965888534666666662345", 30), toUnit("1", 20))

    console.log("close ============================================================")
    await liquidityPool.setAssetFunding(1, toWei("0.03111"), toWei("51.0495615"))

    await setGmxPrice("1226.5")
    var position = await proxy.getGmxPosition()
    await expect(
      factory.connect(trader1).closePositionV2(
        {
          projectId: 1,
          collateralToken: weth.address,
          assetToken: weth.address,
          isLong: true,
          collateralUsd: toWei("0"),
          sizeUsd: toWei("1296.5"),
          priceUsd: toWei("1200"),
          tpPriceUsd: 0,
          slPriceUsd: 0,
          flags: 0x40,
          referralCode: zeroBytes32,
        },
        { value: executionFee }
      )
    ).to.be.revertedWith("MmMarginUnsafe")

    const [value, isNeg] = await proxy.getMarginValue2()
    expect(isNeg).to.be.true
    var state = await proxy.muxAccountState()
    expect(state.isLiquidating).to.be.false

    const govAddr = await gmxVault.gov()
    const gov = await ethers.getImpersonatedSigner(govAddr)
    await setBalance(gov.address, toWei("1"))
    await gmxVault.connect(gov).setLiquidator(priceUpdater.address, true)

    await gmxVault
      .connect(priceUpdater)
      .liquidatePosition(proxy.address, weth.address, weth.address, true, proxy.address)

    var state = await proxy.muxAccountState()
    expect(state.isLiquidating).to.be.false

    console.log(await proxy.debtStates())
    var debt = await proxy.debtStates()
    expect(debt.cumulativeDebt).to.equal(toWei("0.023333333333333334"))
    expect(debt.cumulativeFee).to.equal(toWei("0"))

    await proxy.withdraw()

    var debt = await proxy.debtStates()
    expect(debt.cumulativeDebt).to.equal(toWei("0"))
    expect(debt.cumulativeFee).to.equal(toWei("0"))
  })

  it("long ETH, collateral = USDC", async () => {
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
        collateralToken: weth.address,
        assetToken: weth.address,
        isLong: true,
        tokenIn: usdc.address,
        amountIn: toUnit("14.464836", 6), // 1
        minOut: toWei("0.011117352"),
        borrow: toWei("0.023333333333333334"),
        sizeUsd: toWei("1296.5"),
        priceUsd: toWei("1296.5"),
        tpPriceUsd: 0,
        slPriceUsd: 0,
        flags: 0x40,
        referralCode: zeroBytes32,
      },
      { value: executionFee }
    )
    const [_proxy] = await factory.getProxiesOf(trader1.address)
    const orderKey = ethers.utils.solidityKeccak256(["address", "uint256"], [_proxy, 1])
    const gmxOrder = await gmxPositionRouter.increasePositionRequests(orderKey)
    expect(gmxOrder.amountIn).to.be.closeTo(toWei("0.034334018666666667"), toUnit("1", 10))

    await setGmxPrice("1296.5")
    await gmxPositionRouter.connect(priceUpdater).executeIncreasePosition(orderKey, trader1.address)

    const proxy = await ethers.getContractAt("TestGmxAdapter", _proxy)
    var position = await proxy.getGmxPosition()
    expect(position.sizeUsd).to.equal(toUnit("1296.5", 30))
    expect(await proxy.getMarginValue()).to.be.closeTo(toUnit("12.965888534666666662345", 30), toUnit("1", 20))

    console.log("close ============================================================")
    await liquidityPool.setAssetFunding(1, toWei("0.03111"), toWei("51.0495615"))

    await setGmxPrice("1256.5")
    var position = await proxy.getGmxPosition()
    await expect(
      factory.connect(trader1).closePositionV2(
        {
          projectId: 1,
          collateralToken: weth.address,
          assetToken: weth.address,
          isLong: true,
          collateralUsd: toWei("0"),
          sizeUsd: toWei("1296.5"),
          priceUsd: toWei("1200"),
          tpPriceUsd: 0,
          slPriceUsd: 0,
          flags: 0x40,
          referralCode: zeroBytes32,
        },
        { value: executionFee }
      )
    ).to.be.revertedWith("MmMarginUnsafe")

    const [value, isNeg] = await proxy.getMarginValue2()
    expect(isNeg).to.be.true

    var state = await proxy.muxAccountState()
    expect(state.isLiquidating).to.be.false

    const govAddr = await gmxVault.gov()
    const gov = await ethers.getImpersonatedSigner(govAddr)
    await setBalance(gov.address, toWei("1"))
    await gmxVault.connect(gov).setLiquidator(priceUpdater.address, true)

    await gmxVault
      .connect(priceUpdater)
      .liquidatePosition(proxy.address, weth.address, weth.address, true, proxy.address)

    console.log(await weth.balanceOf(proxy.address))

    await factory.connect(priceUpdater).withdraw(1, trader1.address, weth.address, weth.address, true)
    console.log(await proxy.debtStates())
    var state = await proxy.muxAccountState()
    expect(state.isLiquidating).to.be.false
    const debt = await proxy.debtStates()
    expect(debt.cumulativeDebt).to.equal(toWei("0"))
    expect(debt.cumulativeFee).to.equal(toWei("0"))
  })

  it("long ETH, collateral = USDC", async () => {
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
    const factory = await createContract("TestProxyFactory")
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

    await factory.connect(trader1).createProxy(1, weth.address, weth.address, true)
    const [_proxy] = await factory.getProxiesOf(trader1.address)
    const proxy = await ethers.getContractAt("TestGmxAdapter", _proxy)
    await proxy.setDebtState(toWei("10"), 0, 0)
    await factory.setTotalBorrows(1, weth.address, toWei("100"))

    console.log("weth", await weth.balanceOf(proxy.address))
    console.log(await proxy.debtStates())
    await expect(
      factory
        .connect(priceUpdater)
        .liquidatePosition(1, trader1.address, weth.address, weth.address, true, toWei("1200"))
    ).to.be.revertedWith("NoPositionToLiquidate")
    const debt = await proxy.debtStates()
    expect(debt.cumulativeDebt).to.equal(toWei("10"))
    expect(debt.cumulativeFee).to.equal(toWei("0"))
  })

  it("long ETH, collateral = USDC", async () => {
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
        collateralToken: weth.address,
        assetToken: weth.address,
        isLong: true,
        tokenIn: usdc.address,
        amountIn: toUnit("14.464836", 6), // 1
        minOut: toWei("0.011117352"),
        borrow: toWei("0.023333333333333334"),
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
    expect(gmxOrder.amountIn).to.be.closeTo(toWei("0.034334018666666667"), toUnit("1", 10))

    await setGmxPrice("1296.5")
    await gmxPositionRouter.connect(priceUpdater).executeIncreasePosition(orderKey, trader1.address)

    const proxy = await ethers.getContractAt("TestGmxAdapter", _proxy)
    console.log(await proxy.getMarginValue())
    await expect(proxy.liquidatePosition(toWei("1290.1"), { value: executionFee })).to.be.revertedWith("MmMarginSafe")
    await proxy.liquidatePosition(toWei("1290"), { value: executionFee })
  })
})
