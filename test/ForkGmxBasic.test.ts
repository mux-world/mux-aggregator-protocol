import { ethers, network } from "hardhat"
import "@nomiclabs/hardhat-ethers"
import { expect } from "chai"
import { MockERC20, IGmxFastPriceFeed, IGmxPositionRouter, IGmxOrderBook, IGmxRouter, IGmxVault } from "../typechain"
import {
  toWei,
  toUnit,
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
  USDGAddress,
} from "../scripts/deployUtils"
import { hardhatSetArbERC20Balance } from "../scripts/deployUtils"
import { loadFixture, setBalance, time } from "@nomicfoundation/hardhat-network-helpers"
import { IGmxReader } from "../typechain/contracts/interfaces/IGmxReader"
import { IGmxPositionManager } from "../typechain/contracts/interfaces/IGmxPositionManager"

describe("Fork gmx basic", () => {
  // arb1
  const wethAddress = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"
  const wbtcAddress = "0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f"
  const usdcAddress = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8"

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
    const wbtc = (await ethers.getContractAt("MockERC20", wbtcAddress)) as MockERC20
    const usdc = (await ethers.getContractAt("MockERC20", usdcAddress)) as MockERC20
    const usdg = (await ethers.getContractAt("MockERC20", USDGAddress)) as MockERC20
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

    // fixtures can return anything you consider useful for your tests
    console.log("fixtures: generated")
    return { weth, usdc, priceUpdater, gmxFastPriceFeed, gmxPositionRouter, gmxPositionManager, gmxOrderBook, gmxRouter, gmxVault, gmxReader, gmxVaultReader, usdg }
  }

  after(async () => {
    await network.provider.request({
      method: "hardhat_reset",
      params: [],
    })
  })

  it("market order: increase long", async () => {
    // recover snapshot
    const [_, trader1] = await ethers.getSigners()
    const { weth, usdc, priceUpdater, gmxFastPriceFeed, gmxPositionRouter, gmxRouter, gmxVault } = await loadFixture(deployTokenFixture)

    // give me some token
    await hardhatSetArbERC20Balance(usdc.address, trader1.address, toUnit("3000", 6))
    await hardhatSetArbERC20Balance(weth.address, trader1.address, toWei("1"))
    expect(await usdc.balanceOf(trader1.address)).to.eq(toUnit("3000", 6))
    expect(await weth.balanceOf(trader1.address)).to.eq(toWei("1"))

    // no position
    {
      const [size, collateral, avgPrice, entryFunding, reserve, rpnl, hasProfit, last] = await gmxVault.getPosition(trader1.address, weth.address, weth.address, true)
      expect(size).to.eq(toGmxUsd("0"))
      expect(collateral).to.eq(toGmxUsd("0"))
    }

    // place
    await gmxRouter.connect(trader1).approvePlugin(PositionRouterAddress)
    await usdc.connect(trader1).approve(gmxRouter.address, toUnit("20", 6))
    await gmxPositionRouter.connect(trader1).createIncreasePosition(
      [usdc.address, weth.address], // _path
      weth.address, // _indexToken
      toUnit("20", 6), // _amountIn
      0, // _minOut
      toGmxUsd("50"), // _sizeDelta
      true, // _isLong
      toGmxUsd("5000"), // _acceptablePrice
      executionFee, // _executionFee
      ethers.constants.HashZero, // _referralCode
      ethers.constants.AddressZero, // _callbackTarget
      { value: executionFee }
    )

    // fill
    const blockTime = await getBlockTime()
    const priceBits = getPriceBits([])
    await gmxFastPriceFeed.connect(priceUpdater).setPricesWithBitsAndExecute(
      priceBits,
      blockTime,
      9999999999, // _endIndexForIncreasePositions
      9999999999, // _endIndexForDecreasePositions
      1, // _maxIncreasePositions
      0 // _maxDecreasePositions
    )

    // new position
    {
      const [size, collateral, avgPrice, entryFunding, reserve, rpnl, hasProfit, last] = await gmxVault.getPosition(trader1.address, weth.address, weth.address, true)
      expect(size).to.eq(toGmxUsd("50"))
    }
  })

  it("limit order: increase short", async () => {
    // recover snapshot
    const [_, trader1] = await ethers.getSigners()
    const { weth, usdc, priceUpdater, gmxPositionManager, gmxOrderBook, gmxRouter, gmxVault } = await loadFixture(deployTokenFixture)

    // give me some token
    await hardhatSetArbERC20Balance(usdc.address, trader1.address, toUnit("3000", 6))
    await hardhatSetArbERC20Balance(weth.address, trader1.address, toWei("1"))

    // no position
    {
      const [size, collateral, avgPrice, entryFunding, reserve, rpnl, hasProfit, last] = await gmxVault.getPosition(trader1.address, usdc.address, weth.address, false)
      expect(size).to.eq(toGmxUsd("0"))
      expect(collateral).to.eq(toGmxUsd("0"))
    }

    // place
    await gmxRouter.connect(trader1).approvePlugin(OrderBookAddress)
    await usdc.connect(trader1).approve(gmxRouter.address, toUnit("20", 6))
    await expect(
      gmxOrderBook.connect(trader1).createIncreaseOrder(
        [usdc.address], // _path
        toUnit("20", 6), // _amountIn
        weth.address, // _indexToken
        0, // _minOut
        toGmxUsd("50"), // _sizeDelta
        usdc.address, // _collateralToken
        false, // _isLong
        toGmxUsd("1000"), // _triggerPrice
        true, // _triggerAboveThreshold
        executionFee, // _executionFee
        false, // _shouldWrap
        { value: executionFee }
      )
    )
      .to.emit(gmxOrderBook, "CreateIncreaseOrder")
      .withArgs(
        trader1.address, //  _account
        0, // _orderIndex
        usdc.address, // _purchaseToken
        toUnit("20", 6), // _purchaseTokenAmount
        usdc.address, // _collateralToken
        weth.address, // _indexToken
        toGmxUsd("50"), // _sizeDelta
        false, // _isLong
        toGmxUsd("1000"), // _triggerPrice
        true, // _triggerAboveThreshold
        executionFee // _executionFee
      )

    // fill
    await gmxPositionManager.connect(priceUpdater).executeIncreaseOrder(
      trader1.address, // _address
      0, // _orderIndex
      priceUpdater.address // _feeReceiver
    )

    // new position
    {
      const [size, collateral, avgPrice, entryFunding, reserve, rpnl, hasProfit, last] = await gmxVault.getPosition(trader1.address, usdc.address, weth.address, false)
      expect(size).to.eq(toGmxUsd("50"))
    }
  })

  it("dump gmx storage", async () => {
    const { weth, usdg, gmxVault, gmxReader, gmxVaultReader } = await loadFixture(deployTokenFixture)
    const [
      vaultTokenInfo,
      fundingRateInfo,
      usdgSupply,
      totalTokenWeights,
      liquidationFeeUsd,
      taxBasisPoints,
      stableTaxBasisPoints,
      swapFeeBasisPoints,
      stableSwapFeeBasisPoints,
      marginFeeBasisPoints,
    ] = await Promise.all([
      gmxVaultReader.getVaultTokenInfoV4(VaultAddress, PositionRouterAddress, weth.address, toWei("1"), [wethAddress, wbtcAddress, usdcAddress]),
      gmxReader.getFundingRates(VaultAddress, weth.address, [wethAddress, wbtcAddress, usdcAddress]),
      usdg.totalSupply(),
      gmxVault.totalTokenWeights(),
      gmxVault.liquidationFeeUsd(),
      gmxVault.taxBasisPoints(),
      gmxVault.stableTaxBasisPoints(),
      gmxVault.swapFeeBasisPoints(),
      gmxVault.stableSwapFeeBasisPoints(),
      gmxVault.marginFeeBasisPoints(),
    ])
    const vaultPropsLength = 15
    const fundingRatePropsLength = 2
    console.log("# dump gmx storage")
    console.log("  totalTokenWeights       ", totalTokenWeights.toString())
    console.log("  liquidationFeeUsd       ", liquidationFeeUsd.toString())
    console.log("  taxBasisPoints          ", taxBasisPoints.toString())
    console.log("  stableTaxBasisPoints    ", stableTaxBasisPoints.toString())
    console.log("  swapFeeBasisPoints      ", swapFeeBasisPoints.toString())
    console.log("  stableSwapFeeBasisPoints", stableSwapFeeBasisPoints.toString())
    console.log("  marginFeeBasisPoints    ", marginFeeBasisPoints.toString())
    console.log("  ## usdg")
    console.log("    supply", usdgSupply.toString())
    console.log("  ## weth")
    console.log("    poolAmount", vaultTokenInfo[0 * vaultPropsLength + 0].toString())
    console.log("    reserved  ", vaultTokenInfo[0 * vaultPropsLength + 1].toString())
    console.log("    usdgAmount", vaultTokenInfo[0 * vaultPropsLength + 2].toString())
    console.log("    weight    ", vaultTokenInfo[0 * vaultPropsLength + 4].toNumber())
    console.log("    short     ", vaultTokenInfo[0 * vaultPropsLength + 7].toString())
    console.log("    maxShort  ", vaultTokenInfo[0 * vaultPropsLength + 8].toString())
    console.log("    maxLong   ", vaultTokenInfo[0 * vaultPropsLength + 9].toString())
    console.log("    minPrice  ", vaultTokenInfo[0 * vaultPropsLength + 10].toString())
    console.log("    maxPrice  ", vaultTokenInfo[0 * vaultPropsLength + 11].toString())
    console.log("    fr        ", fundingRateInfo[0 * fundingRatePropsLength + 0].toString())
    console.log("    acc.fr    ", fundingRateInfo[0 * fundingRatePropsLength + 1].toString())
    console.log("  ## wbtc")
    console.log("    poolAmount", vaultTokenInfo[1 * vaultPropsLength + 0].toString())
    console.log("    reserved  ", vaultTokenInfo[1 * vaultPropsLength + 1].toString())
    console.log("    usdgAmount", vaultTokenInfo[1 * vaultPropsLength + 2].toString())
    console.log("    weight    ", vaultTokenInfo[1 * vaultPropsLength + 4].toNumber())
    console.log("    short     ", vaultTokenInfo[1 * vaultPropsLength + 7].toString())
    console.log("    maxShort  ", vaultTokenInfo[1 * vaultPropsLength + 8].toString())
    console.log("    maxLong   ", vaultTokenInfo[1 * vaultPropsLength + 9].toString())
    console.log("    minPrice  ", vaultTokenInfo[1 * vaultPropsLength + 10].toString())
    console.log("    maxPrice  ", vaultTokenInfo[1 * vaultPropsLength + 11].toString())
    console.log("    fr        ", fundingRateInfo[1 * fundingRatePropsLength + 0].toString())
    console.log("    acc.fr    ", fundingRateInfo[1 * fundingRatePropsLength + 1].toString())
    console.log("  ## usdc")
    console.log("    poolAmount", vaultTokenInfo[2 * vaultPropsLength + 0].toString())
    console.log("    reserved  ", vaultTokenInfo[2 * vaultPropsLength + 1].toString())
    console.log("    usdgAmount", vaultTokenInfo[2 * vaultPropsLength + 2].toString())
    console.log("    weight    ", vaultTokenInfo[2 * vaultPropsLength + 4].toNumber())
    console.log("    short     ", vaultTokenInfo[2 * vaultPropsLength + 7].toString())
    console.log("    maxShort  ", vaultTokenInfo[2 * vaultPropsLength + 8].toString())
    console.log("    maxLong   ", vaultTokenInfo[2 * vaultPropsLength + 9].toString())
    console.log("    minPrice  ", vaultTokenInfo[2 * vaultPropsLength + 10].toString())
    console.log("    maxPrice  ", vaultTokenInfo[2 * vaultPropsLength + 11].toString())
    console.log("    fr        ", fundingRateInfo[2 * fundingRatePropsLength + 0].toString())
    console.log("    acc.fr    ", fundingRateInfo[2 * fundingRatePropsLength + 1].toString())
  })

  it("swap", async () => {
    // recover snapshot
    const [_, trader1] = await ethers.getSigners()
    const { weth, usdc, gmxReader, gmxVault } = await loadFixture(deployTokenFixture)

    // give me some token
    await hardhatSetArbERC20Balance(usdc.address, trader1.address, toUnit("2000", 6))
    await hardhatSetArbERC20Balance(weth.address, trader1.address, toWei("0"))
    expect(await usdc.balanceOf(trader1.address)).to.eq(toUnit("2000", 6))
    expect(await weth.balanceOf(trader1.address)).to.eq(toWei("0"))

    // swap
    await usdc.connect(trader1).transfer(gmxVault.address, toUnit("2000", 6))
    await gmxVault.connect(trader1).swap(usdc.address, weth.address, trader1.address)
    expect(await usdc.balanceOf(trader1.address)).to.eq(toUnit("0", 6))
    expect(await weth.balanceOf(trader1.address)).to.eq(toWei("1.537154688000000000"))
  })

  it("fr 24 hours later", async () => {
    // recover snapshot
    const [_, trader1] = await ethers.getSigners()
    const { weth, usdc, gmxReader, gmxVault } = await loadFixture(deployTokenFixture)
    const fundingRatePropsLength = 2

    // read fr
    {
      const [fundingRateInfo] = await Promise.all([gmxReader.getFundingRates(VaultAddress, weth.address, [wethAddress, wbtcAddress, usdcAddress])])
      expect(fundingRateInfo[0 * fundingRatePropsLength + 0]).to.eq("17")
      expect(fundingRateInfo[1 * fundingRatePropsLength + 0]).to.eq("16")
      expect(fundingRateInfo[2 * fundingRatePropsLength + 0]).to.eq("24")
      expect(fundingRateInfo[0 * fundingRatePropsLength + 1]).to.eq("329642")
      expect(fundingRateInfo[1 * fundingRatePropsLength + 1]).to.eq("255642")
      expect(fundingRateInfo[2 * fundingRatePropsLength + 1]).to.eq("212231")
    }

    // 24 hours later. 12:00:08 UTC -> 12:00:08
    await time.increase(3600 * 24)

    // swap (just update fr)
    await hardhatSetArbERC20Balance(usdc.address, trader1.address, toUnit("0.000001", 6))
    await usdc.connect(trader1).transfer(gmxVault.address, toUnit("0.000001", 6))
    await gmxVault.connect(trader1).swap(usdc.address, weth.address, trader1.address)

    // read fr
    {
      const [fundingRateInfo] = await Promise.all([gmxReader.getFundingRates(VaultAddress, weth.address, [wethAddress, wbtcAddress, usdcAddress])])
      expect(fundingRateInfo[0 * fundingRatePropsLength + 0]).to.eq("17")
      expect(fundingRateInfo[1 * fundingRatePropsLength + 0]).to.eq("16")
      expect(fundingRateInfo[2 * fundingRatePropsLength + 0]).to.eq("24")
      expect(fundingRateInfo[0 * fundingRatePropsLength + 1]).to.eq("330050")
      expect(fundingRateInfo[1 * fundingRatePropsLength + 1]).to.eq("256039")
      expect(fundingRateInfo[2 * fundingRatePropsLength + 1]).to.eq("212828")
    }
  })
})
