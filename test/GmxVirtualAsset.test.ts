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

describe("GmxVirtualAsset", () => {
  const wethAddress = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1" // Arb1 WETH
  const usdcAddress = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8" // Arb1 USDC
  const uniAddress = "0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0" // Arb1 uni

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
    const uni = (await ethers.getContractAt("MockERC20", uniAddress)) as MockERC20
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
    return { weth, usdc, uni, priceUpdater, gmxFastPriceFeed, gmxPositionRouter, gmxPositionManager, gmxOrderBook, gmxRouter, gmxVault, gmxReader, gmxVaultReader }
  }

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    })
  })

  const zBytes32 = "0x0000000000000000000000000000000000000000000000000000000000000000"
  const zAddress = "0x0000000000000000000000000000000000000000"

  it("no borrow", async () => {
    // recover snapshot
    const [_, trader1] = await ethers.getSigners()
    const { weth, usdc, uni, priceUpdater, gmxFastPriceFeed, gmxPositionRouter, gmxOrderBook, gmxRouter, gmxVault } = await loadFixture(deployTokenFixture)

    const setGmxPrice = async (price: any) => {
      const blockTime = await getBlockTime()
      await gmxFastPriceFeed.connect(priceUpdater).setPricesWithBits(getPriceBits([price, price, price, price]), blockTime)
    }

    // give me some token
    await hardhatSetArbERC20Balance(usdc.address, trader1.address, toUnit("3000", 6))
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
    await factory.setProjectAssetConfig(PROJECT_GMX, uni.address, defaultAssetConfig())

    await factory.setBorrowConfig(PROJECT_GMX, usdc.address, 0, toWei("1000"))
    await factory.setBorrowConfig(PROJECT_GMX, weth.address, 1, toWei("1000"))
    await factory.setBorrowConfig(PROJECT_GMX, uni.address, 255, toWei("0"))

    await factory.upgradeTo(PROJECT_GMX, aggregator.address)
    await factory.setKeeper(priceUpdater.address, true)

    const executionFee = await gmxPositionRouter.minExecutionFee()
    console.log(executionFee)

    await usdc.connect(trader1).approve(factory.address, toWei("10000"))
    await factory.connect(trader1).openPosition(
      {
        projectId: 1,
        collateralToken: uni.address,
        assetToken: uni.address,
        isLong: true,
        tokenIn: usdc.address,
        amountIn: toUnit("6.389196", 6), // 1
        minOut: toWei("0"),
        borrow: toWei("0"),
        sizeUsd: toWei("6.389196"),
        priceUsd: toWei("6.389196"),
        tpPriceUsd: 0,
        slPriceUsd: 0,
        flags: 0x40,
        referralCode: zBytes32,
      },
      { value: executionFee }
    )

    const [_proxy] = await factory.getProxiesOf(trader1.address)
    const orderKey = ethers.utils.solidityKeccak256(["address", "uint256"], [_proxy, 1])
    await gmxPositionRouter.connect(priceUpdater).executeIncreasePosition(orderKey, trader1.address)

    const proxy = await ethers.getContractAt("TestGmxAdapter", _proxy)
    var position = await proxy.getGmxPosition()
    expect(position.sizeUsd).to.equal(toUnit("6.389196", 30))

    await factory.connect(trader1).closePosition(
      {
        projectId: 1,
        collateralToken: uni.address,
        assetToken: uni.address,
        isLong: true,
        collateralUsd: toWei("0"),
        sizeUsd: toWei("6.389196"),
        priceUsd: toWei("6.389196"),
        tpPriceUsd: 0,
        slPriceUsd: 0,
        flags: 0x40,
        referralCode: zBytes32,
      },
      { value: executionFee }
    )
    await gmxPositionRouter.connect(priceUpdater).executeDecreasePosition(orderKey, trader1.address)



    var position = await proxy.getGmxPosition()
    expect(position.sizeUsd).to.equal(toUnit("0", 30))
  })

  it("try borrow", async () => {
    // recover snapshot
    const [_, trader1] = await ethers.getSigners()
    const { weth, usdc, uni, priceUpdater, gmxFastPriceFeed, gmxPositionRouter, gmxOrderBook, gmxRouter, gmxVault } = await loadFixture(deployTokenFixture)

    const setGmxPrice = async (price: any) => {
      const blockTime = await getBlockTime()
      await gmxFastPriceFeed.connect(priceUpdater).setPricesWithBits(getPriceBits([price, price, price, price]), blockTime)
    }

    // give me some token
    await hardhatSetArbERC20Balance(usdc.address, trader1.address, toUnit("3000", 6))
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
    await factory.setProjectAssetConfig(PROJECT_GMX, uni.address, defaultAssetConfig())

    await factory.setBorrowConfig(PROJECT_GMX, usdc.address, 0, toWei("1000"))
    await factory.setBorrowConfig(PROJECT_GMX, weth.address, 1, toWei("1000"))
    await factory.setBorrowConfig(PROJECT_GMX, uni.address, 255, toWei("0"))
    await factory.upgradeTo(PROJECT_GMX, aggregator.address)
    await factory.setKeeper(priceUpdater.address, true)

    const executionFee = await gmxPositionRouter.minExecutionFee()
    console.log(executionFee)

    await usdc.connect(trader1).approve(factory.address, toWei("10000"))
    await expect(factory.connect(trader1).openPosition(
      {
        projectId: 1,
        collateralToken: uni.address,
        assetToken: uni.address,
        isLong: true,
        tokenIn: usdc.address,
        amountIn: toUnit("6.399196", 6), // 1
        minOut: toWei("0"),
        borrow: toWei("1"),
        sizeUsd: toWei("6.389196"),
        priceUsd: toWei("6.389196"),
        tpPriceUsd: 0,
        slPriceUsd: 0,
        flags: 0x40,
        referralCode: zBytes32,
      },
      { value: executionFee }
    )).to.be.revertedWith("VirtualAsset")
  })



  it("trade", async () => {
    // recover snapshot
    const [_, trader1] = await ethers.getSigners()
    const { weth, usdc, uni, priceUpdater, gmxFastPriceFeed, gmxPositionRouter, gmxOrderBook, gmxRouter, gmxVault } = await loadFixture(deployTokenFixture)

    const setGmxPrice = async (price: any) => {
      const blockTime = await getBlockTime()
      await gmxFastPriceFeed.connect(priceUpdater).setPricesWithBits(getPriceBits([price, price, price, price]), blockTime)
    }

    // give me some token
    await hardhatSetArbERC20Balance(usdc.address, trader1.address, toUnit("3000", 6))
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
    await factory.setProjectAssetConfig(PROJECT_GMX, uni.address, defaultAssetConfig())

    await factory.setBorrowConfig(PROJECT_GMX, usdc.address, 0, toWei("1000"))
    await factory.setBorrowConfig(PROJECT_GMX, weth.address, 1, toWei("1000"))
    await factory.setBorrowConfig(PROJECT_GMX, uni.address, 255, toWei("0"))

    await factory.upgradeTo(PROJECT_GMX, aggregator.address)
    await factory.setKeeper(priceUpdater.address, true)

    const executionFee = await gmxPositionRouter.minExecutionFee()
    console.log(executionFee)


    await hardhatSetArbERC20Balance(uni.address, trader1.address, toWei("100000"))
    await uni.connect(trader1).approve(factory.address, toWei("10000"))
    await factory.connect(trader1).openPosition(
      {
        projectId: 1,
        collateralToken: uni.address,
        assetToken: uni.address,
        isLong: true,
        tokenIn: uni.address,
        amountIn: toWei("1.723547185178350365"),
        minOut: toWei("0"),
        borrow: toWei("0"),
        sizeUsd: toWei("320.7402"),
        priceUsd: toWei("6.414804"),
        tpPriceUsd: 0,
        slPriceUsd: 0,
        flags: 0x40,
        referralCode: zBytes32,
      },
      { value: executionFee }
    )

    const [_proxy] = await factory.getProxiesOf(trader1.address)
    const orderKey = ethers.utils.solidityKeccak256(["address", "uint256"], [_proxy, 1])
    await gmxPositionRouter.connect(priceUpdater).executeIncreasePosition(orderKey, trader1.address)

    const proxy = await ethers.getContractAt("TestGmxAdapter", _proxy)
    var position = await proxy.getGmxPosition()
    expect(position.sizeUsd).to.equal(toUnit("320.7402", 30))
    expect(position.collateralUsd).to.be.closeTo(toUnit("10.691340581352775438", 30), toUnit("1", 13))
    expect(await proxy.getMarginValue()).to.be.closeTo(toUnit("9.410940581352775438", 30), toUnit("1", 13))
  })
})
