import { ethers, network } from "hardhat"
import { expect } from "chai"
import { toWei, toUnit, fromUnit, fromWei, createContract } from "../scripts/deployUtils"
import { impersonateAccount, setBalance, time, mine } from "@nomicfoundation/hardhat-network-helpers"
import {
  GmxV2Adapter,
  IERC20,
  IExchangeRouter,
  IOrderHandler,
  IReader,
  IWETH,
  MockPriceHub,
  PriceHub,
  ProxyAdmin,
  ProxyFactory,
} from "../typechain"

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { encodeRealtimeData, parseEventLog } from "./GmxV2Utils"

const U = ethers.utils
const B = ethers.BigNumber

describe("GmxV2-Repay", async () => {
  const PROJECT_ID = 2

  let user0: SignerWithAddress
  let user1: SignerWithAddress
  let user2: SignerWithAddress
  let user3: SignerWithAddress
  let user4: SignerWithAddress

  let weth: IWETH
  let usdc: IERC20
  let proxyFactory: ProxyFactory
  let admin: SignerWithAddress
  let gmxBroker: SignerWithAddress
  let proxyAdmin: ProxyAdmin

  let exchangeRouter: IExchangeRouter
  let gmxReader: IReader
  let priceHub: MockPriceHub
  let orderHandler: IOrderHandler
  let eventEmitter: any

  let swapRouter: string
  let dataStore: string
  let referralStore: string
  let orderVault: string
  let mockArbSys: any
  let mockGmxReader: any

  const pad32r = (s: string) => {
    if (s.length > 66) {
      return s
    } else if (s.startsWith("0x") || s.startsWith("0X")) {
      return s + "0".repeat(66 - s.length)
    } else {
      return s + "0".repeat(64 - s.length)
    }
  }

  beforeEach(async () => {
    const accounts = await ethers.getSigners()
    user0 = accounts[0]
    user1 = accounts[1]
    user2 = accounts[2]
    user3 = accounts[3]
    user4 = accounts[4]

    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: "https://arb1.arbitrum.io/rpc",
            enabled: true,
            ignoreUnknownTxType: true, // added in our hardhat patch. see README.md
            blockNumber: 154503026, // modify me if ./cache/hardhat-network-fork was cleared
          },
        },
      ],
    })

    weth = await ethers.getContractAt("IWETH", "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1") // feedId = 0x74aca63821bf7ead199e924d261d277cbec96d1026ab65267d655c51b4536914
    usdc = await ethers.getContractAt("IERC20", "0xaf88d065e77c8cC2239327C5EDb3A432268e5831") // feedId = 0x95241f154d34539741b19ce4bae815473fd1b2a90ac3b4b023a692f31edfe90e

    exchangeRouter = (await ethers.getContractAt(
      "IExchangeRouter",
      "0x7C68C7866A64FA2160F78EEaE12217FFbf871fa8"
    )) as IExchangeRouter
    gmxReader = (await ethers.getContractAt("IReader", "0xf60becbba223EEA9495Da3f606753867eC10d139")) as IReader
    mockGmxReader = await createContract("MockGmxV2Reader", [])
    orderHandler = (await ethers.getContractAt(
      "IOrderHandler",
      "0x352f684ab9e97a6321a13CF03A61316B681D9fD2"
    )) as IOrderHandler
    priceHub = (await createContract("MockPriceHub", [])) as MockPriceHub
    eventEmitter = await createContract("EventEmitter", [])

    swapRouter = "0xE592427A0AEce92De3Edee1F18E0157C05861564"
    dataStore = "0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8"
    referralStore = "0xe6fab3F0c7199b0d34d7FbE83394fc0e0D06e99d"
    orderVault = "0x31eF83a530Fde1B38EE9A18093A333D8Bbbc40D5"

    gmxBroker = await ethers.getImpersonatedSigner("0xf1e1b2f4796d984ccb8485d43db0c64b83c1fa6d")
    admin = await ethers.getImpersonatedSigner("0xc2D28778447B1B0B2Ae3aD17dC6616b546FBBeBb")

    await setBalance(admin.address, toWei("1"))
    proxyAdmin = (await ethers.getContractAt("ProxyAdmin", "0xE52d9a3CBA458832A65cfa9FC8a74bacAbdeB32A")) as ProxyAdmin
    proxyFactory = (await ethers.getContractAt(
      "ProxyFactory",
      "0x2ff2f1D9826ae2410979ae19B88c361073Ab0918"
    )) as ProxyFactory

    // 1 update proxyFactory
    {
      const proxyFactoryImp = await createContract("ProxyFactory", [])
      await proxyAdmin.connect(admin).upgrade(proxyFactory.address, proxyFactoryImp.address)
    }

    await eventEmitter.initialize(proxyFactory.address)
    const adapter = await createContract("TestGmxV2Adapter", [], {
      LibGmxV2: await createContract("LibGmxV2", []),
    })
    // 2 update proxy
    await proxyFactory.connect(admin).upgradeTo(PROJECT_ID, adapter.address)
    // 3 set project config
    await proxyFactory.connect(admin).setProjectConfig(PROJECT_ID, [
      pad32r(swapRouter),
      pad32r(exchangeRouter.address),
      pad32r(orderVault),
      pad32r(dataStore),
      pad32r(referralStore),
      pad32r(mockGmxReader.address),
      pad32r(priceHub.address),
      pad32r(eventEmitter.address),
      ethers.utils.formatBytes32String("muxprotocol"),
      3, // weth
      pad32r(weth.address),
      86400 * 2,
    ])

    // 4 set market configs
    // WETH-USDC
    // [
    //     0x70d95587d40A2caf56bd97485aB3Eec10Bee6336, // market
    //     0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, // index = weth
    //     0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, // long = weth
    //     0xaf88d065e77c8cC2239327C5EDb3A432268e5831, // short = usdc
    // ]
    // WETH-USDC
    await proxyFactory
      .connect(admin)
      .setProjectAssetConfig(PROJECT_ID, "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336", [
        toUnit("0.02", 5),
        toUnit("0.006", 5),
        toUnit("0.005", 5),
        toUnit("0.00", 5),
        toUnit("0.02", 5),
        18,
        1,
      ])

    await proxyFactory.connect(admin).setBorrowConfig(PROJECT_ID, weth.address, 3, toWei("1000"))
    await proxyFactory.connect(admin).setBorrowConfig(PROJECT_ID, usdc.address, 11, toWei("1000"))

    // replace modifier
    const verifier = await createContract("MockRealtimeFeedVerifier", [])
    const verifyProxy = await ethers.getContractAt("IVerifierProxy", "0xDBaeB34DF0AcfA564a49e13840C5CE2894C4b886") // realtimeFeedVerifier

    const newVerifierCode = await ethers.provider.getCode(verifier.address)
    await ethers.provider.send("hardhat_setCode", [verifyProxy.address, newVerifierCode])
  })

  const encodeRealtimeFeedData = async (ethPrice: any, usdcPrice: any) => {
    const block = await ethers.provider.getBlock("latest")
    const number = block.number
    const timestamp = block.timestamp
    const blockHash = block.hash
    return [
      // eth
      encodeRealtimeData({
        feedId: "0x74aca63821bf7ead199e924d261d277cbec96d1026ab65267d655c51b4536914",
        median: ethPrice,
        bid: ethPrice,
        ask: ethPrice,
        upperBlockhash: blockHash,
        blocknumberUpperBound: number,
        blocknumberLowerBound: number,
        observationsTimestamp: timestamp,
        currentBlockTimestamp: timestamp,
      }),
      // usdc
      encodeRealtimeData({
        feedId: "0x95241f154d34539741b19ce4bae815473fd1b2a90ac3b4b023a692f31edfe90e",
        median: usdcPrice,
        bid: usdcPrice,
        ask: usdcPrice,
        upperBlockhash: blockHash,
        blocknumberUpperBound: number,
        blocknumberLowerBound: number,
        observationsTimestamp: timestamp,
        currentBlockTimestamp: timestamp,
      }),
    ]
  }

  const fillGmxOrder = async (key: any, ethPrice: any, usdcPrice: any) => {
    const tx = await orderHandler.connect(gmxBroker).executeOrder(key, {
      signerInfo: 0,
      tokens: [],
      compactedMinOracleBlockNumbers: [],
      compactedMaxOracleBlockNumbers: [],
      compactedOracleTimestamps: [],
      compactedDecimals: [],
      compactedMinPrices: [],
      compactedMinPricesIndexes: [],
      compactedMaxPrices: [],
      compactedMaxPricesIndexes: [],
      signatures: [],
      priceFeedTokens: [],
      realtimeFeedTokens: [weth.address, usdc.address],
      realtimeFeedData: await encodeRealtimeFeedData(ethPrice, usdcPrice),
    })
    // const receipt1 = await tx.wait()
    // for (const log of receipt1.logs) {
    //   const decoded = parseEventLog(log)
    //   if (decoded) {
    //     console.log(JSON.stringify(decoded, null, 2))
    //   }
    // }
    return tx
  }

  it("repay-single", async () => {
    const testAdmin = await ethers.getImpersonatedSigner("0x1426476e4ea1426c56a5b1d2469a62281e8dcfc9")
    const lendingPool = await ethers.getContractAt("LendingPool", "0x9Ba6172225118f3fa1D99EDb1cc698EA67B7d129")
    await lendingPool.connect(testAdmin).setBorrower(proxyFactory.address, true)
    // {
    //   const lendingPoolImp = await createContract("LendingPool", [])
    //   await proxyAdmin.connect(admin).upgrade(lendingPool.address, lendingPoolImp.address)
    //   console.log("upgraded")
    // }
    await proxyFactory.connect(admin).setLiquiditySource(2, 2, lendingPool.address)
    await proxyFactory.connect(admin).setKeeper(user0.address, true)

    const proxyAddress = await proxyFactory.getProxyAddress(
      PROJECT_ID,
      user0.address,
      weth.address,
      "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336",
      true
    )
    await proxyFactory.createProxy(PROJECT_ID, weth.address, "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336", true)
    const proxy = await ethers.getContractAt("TestGmxV2Adapter", proxyAddress)

    await setBalance(user0.address, toWei("200"))
    await weth.connect(user0).deposit({ value: toWei("100") })

    // set debut
    await proxy.debugSetDebtStates(toWei("10"), toWei("0"), toWei("0"), "213911250000000000")
    await proxy.makeTestOrder(ethers.utils.id("mockOrder"), toWei("0"), toWei("0"), false)
    await mockGmxReader.setSizeInUsd(0)
    await priceHub.setPrice(weth.address, toWei("1784"))
    await priceHub.setPrice(usdc.address, toWei("1"))
    const { order, events } = await proxy.makeEmptyOrderParams()
    // transfer

    expect((await proxy.getPendingOrders()).length).to.equal(1)
    var debtStates = await proxy.muxAccountState()
    expect(debtStates.debtCollateralAmount).to.equal(toWei("10"))
    expect(debtStates.inflightDebtCollateralAmount).to.equal(toWei("0"))
    expect(debtStates.pendingFeeCollateralAmount).to.equal(toWei("0"))

    await weth.connect(user0).transfer(proxy.address, toWei("10"))
    expect(await weth.balanceOf(proxy.address)).to.equal(toWei("10"))
    await proxy.connect(user0).afterOrderExecution(ethers.utils.id("mockOrder"), order, events)

    expect((await proxy.getPendingOrders()).length).to.equal(0)
    var debtStates = await proxy.muxAccountState()
    expect(debtStates.debtCollateralAmount).to.equal(toWei("0"))
    expect(debtStates.inflightDebtCollateralAmount).to.equal(toWei("0"))
    expect(debtStates.pendingFeeCollateralAmount).to.equal(toWei("0"))

    expect(await lendingPool.getAvailableLiquidity(weth.address)).to.equal(toWei("10"))
  })

  Object.defineProperties(ethers.BigNumber.prototype, {
    toJSON: {
      value: function (this: any) {
        return this.toString()
      },
    },
  })

  it("repay-multi", async () => {
    const testAdmin = await ethers.getImpersonatedSigner("0x1426476e4ea1426c56a5b1d2469a62281e8dcfc9")
    const lendingPool = await ethers.getContractAt("LendingPool", "0x9Ba6172225118f3fa1D99EDb1cc698EA67B7d129")
    await lendingPool.connect(testAdmin).setBorrower(proxyFactory.address, true)
    // {
    //   const lendingPoolImp = await createContract("LendingPool", [])
    //   await proxyAdmin.connect(admin).upgrade(lendingPool.address, lendingPoolImp.address)
    //   console.log("upgraded")
    // }
    await proxyFactory.connect(admin).setLiquiditySource(2, 2, lendingPool.address)
    await proxyFactory.connect(admin).setKeeper(user0.address, true)

    const proxyAddress = await proxyFactory.getProxyAddress(
      PROJECT_ID,
      user0.address,
      weth.address,
      "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336",
      true
    )
    await proxyFactory.createProxy(PROJECT_ID, weth.address, "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336", true)
    const proxy = await ethers.getContractAt("TestGmxV2Adapter", proxyAddress)

    await setBalance(user0.address, toWei("200"))
    await weth.connect(user0).deposit({ value: toWei("100") })

    // set debut
    await proxy.debugSetDebtStates(toWei("10"), toWei("0"), toWei("0"), "213911250000000000")
    await proxy.makeTestOrder(ethers.utils.id("mockOrder"), toWei("0"), toWei("0"), false)
    await mockGmxReader.setSizeInUsd(0)
    await priceHub.setPrice(weth.address, toWei("1784"))
    await priceHub.setPrice(usdc.address, toWei("1"))
    const { order, events } = await proxy.makeEmptyOrderParams()

    // transfer
    expect((await proxy.getPendingOrders()).length).to.equal(1)
    var debtStates = await proxy.muxAccountState()
    expect(debtStates.debtCollateralAmount).to.equal(toWei("10"))
    expect(debtStates.inflightDebtCollateralAmount).to.equal(toWei("0"))
    expect(debtStates.pendingFeeCollateralAmount).to.equal(toWei("0"))

    await weth.connect(user0).transfer(proxy.address, toWei("8"))
    const usdcHolder = await ethers.getImpersonatedSigner("0x47c031236e19d024b42f8ae6780e44a573170703")
    await setBalance(usdcHolder.address, toWei("1"))
    await usdc.connect(usdcHolder).transfer(proxy.address, toUnit("20000", 6))

    var tx = await proxy.connect(user0).afterOrderExecution(ethers.utils.id("mockOrder"), order, events)
    var receipt = await tx.wait()
    // console.log(eventEmitter.interface.parseLog(receipt.logs[receipt.logs.length - 1]).args.result)

    // should repay 8 eth + 1784 * 2 usd
    expect((await proxy.getPendingOrders()).length).to.equal(0)
    var debtStates = await proxy.muxAccountState()
    expect(debtStates.debtCollateralAmount).to.equal(toWei("0"))
    expect(debtStates.inflightDebtCollateralAmount).to.equal(toWei("0"))
    expect(debtStates.pendingFeeCollateralAmount).to.equal(toWei("0"))

    expect(await lendingPool.getAvailableLiquidity(weth.address)).to.equal(toWei("8"))
    expect(await lendingPool.getAvailableLiquidity(usdc.address)).to.equal(toUnit("1784", 6).mul(2))

    expect(await weth.balanceOf(proxy.address)).to.equal(0)
    expect(await usdc.balanceOf(proxy.address)).to.equal(0)
  })

  it("repay-multi", async () => {
    const testAdmin = await ethers.getImpersonatedSigner("0x1426476e4ea1426c56a5b1d2469a62281e8dcfc9")
    const lendingPool = await ethers.getContractAt("LendingPool", "0x9Ba6172225118f3fa1D99EDb1cc698EA67B7d129")
    await lendingPool.connect(testAdmin).setBorrower(proxyFactory.address, true)
    // {
    //   const lendingPoolImp = await createContract("LendingPool", [])
    //   await proxyAdmin.connect(admin).upgrade(lendingPool.address, lendingPoolImp.address)
    //   console.log("upgraded")
    // }
    await proxyFactory.connect(admin).setLiquiditySource(2, 2, lendingPool.address)
    await proxyFactory.connect(admin).setKeeper(user0.address, true)

    const proxyAddress = await proxyFactory.getProxyAddress(
      PROJECT_ID,
      user0.address,
      weth.address,
      "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336",
      true
    )
    await proxyFactory.createProxy(PROJECT_ID, weth.address, "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336", true)
    const proxy = await ethers.getContractAt("TestGmxV2Adapter", proxyAddress)

    await setBalance(user0.address, toWei("200"))
    await weth.connect(user0).deposit({ value: toWei("100") })

    // set debut
    await proxy.debugSetDebtStates(toWei("10"), toWei("0"), toWei("0"), "215423750000000000")
    await proxy.makeTestOrder(ethers.utils.id("mockOrder"), toWei("0"), toWei("0"), false)
    await mockGmxReader.setSizeInUsd(0)
    await priceHub.setPrice(weth.address, toWei("1784"))
    await priceHub.setPrice(usdc.address, toWei("1"))
    const { order, events } = await proxy.makeEmptyOrderParams()

    // transfer
    expect((await proxy.getPendingOrders()).length).to.equal(1)
    var debtStates = await proxy.muxAccountState()
    expect(debtStates.debtCollateralAmount).to.equal(toWei("10"))
    expect(debtStates.inflightDebtCollateralAmount).to.equal(toWei("0"))
    expect(debtStates.pendingFeeCollateralAmount).to.equal(toWei("0"))

    await weth.connect(user0).transfer(proxy.address, toWei("8"))
    const usdcHolder = await ethers.getImpersonatedSigner("0x47c031236e19d024b42f8ae6780e44a573170703")
    await setBalance(usdcHolder.address, toWei("1"))
    await usdc.connect(usdcHolder).transfer(proxy.address, toUnit("20000", 6))

    var tx = await proxy.connect(user0).afterOrderExecution(ethers.utils.id("mockOrder"), order, events)
    var receipt = await tx.wait()
    var debtResult = receipt.logs
      .map((log) => {
        try {
          return eventEmitter.interface.parseLog(log).args.result
        } catch {
          return null
        }
      })
      .filter((x) => x != null)[0]
    expect(debtResult.collateralBalance).to.equal(toWei("8"))
    expect(debtResult.totalFeeCollateralAmount).to.equal(toWei("0.2")) // 10 * 0.02
    expect(debtResult.repaidDebtCollateralAmount).to.equal(toWei("8"))
    expect(debtResult.repaidFeeCollateralAmount).to.equal(toWei("0"))
    expect(debtResult.unpaidFeeCollateralAmount).to.equal(toWei("0"))
    expect(debtResult.secondaryTokenBalance).to.equal(toUnit("20000", 6))
    expect(debtResult.repaidDebtSecondaryTokenAmount).to.equal(toUnit("1784", 6).mul(2))
    expect(debtResult.repaidFeeSecondaryTokenAmount).to.equal(toUnit("178.4", 6).mul(2)) // 10 * 1784 * 0.02

    // should repay 8 eth + 1784 * 2 usd
    expect((await proxy.getPendingOrders()).length).to.equal(0)
    var debtStates = await proxy.muxAccountState()
    expect(debtStates.debtCollateralAmount).to.equal(toWei("0"))
    expect(debtStates.inflightDebtCollateralAmount).to.equal(toWei("0"))
    expect(debtStates.pendingFeeCollateralAmount).to.equal(toWei("0"))

    expect(await lendingPool.getAvailableLiquidity(weth.address)).to.equal(toWei("8"))
    expect(await lendingPool.getAvailableLiquidity(usdc.address)).to.equal(toUnit("1784", 6).mul(2))

    expect(await weth.balanceOf(proxy.address)).to.equal(0)
    expect(await usdc.balanceOf(proxy.address)).to.equal(0)
  })

  it("repay-multi with fee", async () => {
    const testAdmin = await ethers.getImpersonatedSigner("0x1426476e4ea1426c56a5b1d2469a62281e8dcfc9")
    const lendingPool = await ethers.getContractAt("LendingPool", "0x9Ba6172225118f3fa1D99EDb1cc698EA67B7d129")
    await lendingPool.connect(testAdmin).setBorrower(proxyFactory.address, true)
    // {
    //   const lendingPoolImp = await createContract("LendingPool", [])
    //   await proxyAdmin.connect(admin).upgrade(lendingPool.address, lendingPoolImp.address)
    //   console.log("upgraded")
    // }
    await proxyFactory.connect(admin).setLiquiditySource(2, 2, lendingPool.address)
    await proxyFactory.connect(admin).setKeeper(user0.address, true)

    const proxyAddress = await proxyFactory.getProxyAddress(
      PROJECT_ID,
      user0.address,
      weth.address,
      "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336",
      true
    )
    await proxyFactory.createProxy(PROJECT_ID, weth.address, "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336", true)
    const proxy = await ethers.getContractAt("TestGmxV2Adapter", proxyAddress)

    await setBalance(user0.address, toWei("200"))
    await weth.connect(user0).deposit({ value: toWei("100") })

    // set debut
    await proxy.debugSetDebtStates(toWei("10"), toWei("0"), toWei("1"), "215423750000000000")
    await proxy.makeTestOrder(ethers.utils.id("mockOrder"), toWei("0"), toWei("0"), false)
    await mockGmxReader.setSizeInUsd(0)
    await priceHub.setPrice(weth.address, toWei("2000"))
    await priceHub.setPrice(usdc.address, toWei("1"))
    const { order, events } = await proxy.makeEmptyOrderParams()

    // transfer
    // 10 e + 1e
    expect((await proxy.getPendingOrders()).length).to.equal(1)
    var debtStates = await proxy.muxAccountState()
    expect(debtStates.debtCollateralAmount).to.equal(toWei("10"))
    expect(debtStates.inflightDebtCollateralAmount).to.equal(toWei("0"))
    expect(debtStates.pendingFeeCollateralAmount).to.equal(toWei("1"))

    // 8 e
    // 2000u = 1e
    await weth.connect(user0).transfer(proxy.address, toWei("8"))
    const usdcHolder = await ethers.getImpersonatedSigner("0x47c031236e19d024b42f8ae6780e44a573170703")
    await setBalance(usdcHolder.address, toWei("1"))
    await usdc.connect(usdcHolder).transfer(proxy.address, toUnit("2000", 6))

    var tx = await proxy.connect(user0).afterOrderExecution(ethers.utils.id("mockOrder"), order, events)
    var receipt = await tx.wait()
    var debtResult = receipt.logs
      .map((log) => {
        try {
          return eventEmitter.interface.parseLog(log).args.result
        } catch {
          return null
        }
      })
      .filter((x) => x != null)[0]
    expect(debtResult.collateralBalance).to.equal(toWei("8"))
    expect(debtResult.totalFeeCollateralAmount).to.equal(toWei("1.2")) // 10 * 0.02
    expect(debtResult.repaidDebtCollateralAmount).to.equal(toWei("8"))
    expect(debtResult.repaidFeeCollateralAmount).to.equal(toWei("0"))
    expect(debtResult.unpaidFeeCollateralAmount).to.equal(toWei("1.2"))
    expect(debtResult.secondaryTokenBalance).to.equal(toUnit("2000", 6))
    expect(debtResult.repaidDebtSecondaryTokenAmount).to.equal(toUnit("2000", 6))
    expect(debtResult.repaidFeeSecondaryTokenAmount).to.equal(toUnit("0", 6))

    // should repay 8 eth + 1784 * 2 usd
    expect((await proxy.getPendingOrders()).length).to.equal(0)
    var debtStates = await proxy.muxAccountState()
    expect(debtStates.debtCollateralAmount).to.equal(toWei("0"))
    expect(debtStates.inflightDebtCollateralAmount).to.equal(toWei("0"))
    expect(debtStates.pendingFeeCollateralAmount).to.equal(toWei("0"))

    expect(await lendingPool.getAvailableLiquidity(weth.address)).to.equal(toWei("8"))
    expect(await lendingPool.getAvailableLiquidity(usdc.address)).to.equal(toUnit("2000", 6))

    expect(await weth.balanceOf(proxy.address)).to.equal(0)
    expect(await usdc.balanceOf(proxy.address)).to.equal(0)
  })

  it("repay-multi with fee 2", async () => {
    const testAdmin = await ethers.getImpersonatedSigner("0x1426476e4ea1426c56a5b1d2469a62281e8dcfc9")
    const lendingPool = await ethers.getContractAt("LendingPool", "0x9Ba6172225118f3fa1D99EDb1cc698EA67B7d129")
    await lendingPool.connect(testAdmin).setBorrower(proxyFactory.address, true)
    // {
    //   const lendingPoolImp = await createContract("LendingPool", [])
    //   await proxyAdmin.connect(admin).upgrade(lendingPool.address, lendingPoolImp.address)
    //   console.log("upgraded")
    // }
    await proxyFactory.connect(admin).setLiquiditySource(2, 2, lendingPool.address)
    await proxyFactory.connect(admin).setKeeper(user0.address, true)

    const proxyAddress = await proxyFactory.getProxyAddress(
      PROJECT_ID,
      user0.address,
      weth.address,
      "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336",
      true
    )
    await proxyFactory.createProxy(PROJECT_ID, weth.address, "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336", true)
    const proxy = await ethers.getContractAt("TestGmxV2Adapter", proxyAddress)

    await setBalance(user0.address, toWei("200"))
    await weth.connect(user0).deposit({ value: toWei("100") })

    // set debut
    await proxy.debugSetDebtStates(toWei("10"), toWei("2"), toWei("1"), "215423750000000000")
    await proxy.makeTestOrder(ethers.utils.id("mockOrder"), toWei("0"), toWei("0"), false)
    await mockGmxReader.setSizeInUsd(0)
    await priceHub.setPrice(weth.address, toWei("2000"))
    await priceHub.setPrice(usdc.address, toWei("1"))
    const { order, events } = await proxy.makeEmptyOrderParams()

    // transfer
    // 10 e + 1e
    expect((await proxy.getPendingOrders()).length).to.equal(1)
    var debtStates = await proxy.muxAccountState()
    expect(debtStates.debtCollateralAmount).to.equal(toWei("10"))
    expect(debtStates.inflightDebtCollateralAmount).to.equal(toWei("2"))
    expect(debtStates.pendingFeeCollateralAmount).to.equal(toWei("1"))

    // 8 e
    // 2000u = 1e
    await weth.connect(user0).transfer(proxy.address, toWei("8"))
    const usdcHolder = await ethers.getImpersonatedSigner("0x47c031236e19d024b42f8ae6780e44a573170703")
    await setBalance(usdcHolder.address, toWei("1"))
    await usdc.connect(usdcHolder).transfer(proxy.address, toUnit("4500", 6))

    var tx = await proxy.connect(user0).afterOrderExecution(ethers.utils.id("mockOrder"), order, events)
    var receipt = await tx.wait()
    var debtResult = receipt.logs
      .map((log) => {
        try {
          return eventEmitter.interface.parseLog(log).args.result
        } catch {
          return null
        }
      })
      .filter((x) => x != null)[0]
    expect(debtResult.collateralBalance).to.equal(toWei("8"))
    expect(debtResult.totalFeeCollateralAmount).to.equal(toWei("1.16")) // 1 + 8 * 0.02
    expect(debtResult.repaidDebtCollateralAmount).to.equal(toWei("8"))
    expect(debtResult.repaidFeeCollateralAmount).to.equal(toWei("0"))
    // expect(debtResult.unpaidFeeCollateralAmount).to.equal(toWei("0.91")) // 500 / 2000 = 0.25
    expect(debtResult.secondaryTokenBalance).to.equal(toUnit("4500", 6))
    expect(debtResult.repaidDebtSecondaryTokenAmount).to.equal(toUnit("0", 6))
    expect(debtResult.repaidFeeSecondaryTokenAmount).to.equal(toUnit("2320", 6)) // 1.16 * 2000

    // should repay 8 eth + 1784 * 2 usd
    expect((await proxy.getPendingOrders()).length).to.equal(0)
    var debtStates = await proxy.muxAccountState()
    expect(debtStates.debtCollateralAmount).to.equal(toWei("2"))
    expect(debtStates.inflightDebtCollateralAmount).to.equal(toWei("2"))
    expect(debtStates.pendingFeeCollateralAmount).to.equal(toWei("0"))

    expect(await lendingPool.getAvailableLiquidity(weth.address)).to.equal(toWei("8"))
    expect(await lendingPool.getAvailableLiquidity(usdc.address)).to.equal(toUnit("0", 6))

    expect(await weth.balanceOf(proxy.address)).to.equal(0)
    expect(await usdc.balanceOf(proxy.address)).to.equal(0)
  })

  it("repay-multi with fee 3", async () => {
    const testAdmin = await ethers.getImpersonatedSigner("0x1426476e4ea1426c56a5b1d2469a62281e8dcfc9")
    const lendingPool = await ethers.getContractAt("LendingPool", "0x9Ba6172225118f3fa1D99EDb1cc698EA67B7d129")
    await lendingPool.connect(testAdmin).setBorrower(proxyFactory.address, true)
    // {
    //   const lendingPoolImp = await createContract("LendingPool", [])
    //   await proxyAdmin.connect(admin).upgrade(lendingPool.address, lendingPoolImp.address)
    //   console.log("upgraded")
    // }
    await proxyFactory.connect(admin).setLiquiditySource(2, 2, lendingPool.address)
    await proxyFactory.connect(admin).setKeeper(user0.address, true)

    const proxyAddress = await proxyFactory.getProxyAddress(
      PROJECT_ID,
      user0.address,
      weth.address,
      "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336",
      true
    )
    await proxyFactory.createProxy(PROJECT_ID, weth.address, "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336", true)
    const proxy = await ethers.getContractAt("TestGmxV2Adapter", proxyAddress)

    await setBalance(user0.address, toWei("200"))
    await weth.connect(user0).deposit({ value: toWei("100") })

    // set debut
    await proxy.debugSetDebtStates(toWei("12"), toWei("2"), toWei("1"), "215423750000000000")
    await proxy.makeTestOrder(ethers.utils.id("mockOrder"), toWei("0"), toWei("0"), false)
    await mockGmxReader.setSizeInUsd(0)
    await priceHub.setPrice(weth.address, toWei("2000"))
    await priceHub.setPrice(usdc.address, toWei("1"))
    const { order, events } = await proxy.makeEmptyOrderParams()

    // transfer
    // 10 e + 1e
    expect((await proxy.getPendingOrders()).length).to.equal(1)
    var debtStates = await proxy.muxAccountState()
    expect(debtStates.debtCollateralAmount).to.equal(toWei("12"))
    expect(debtStates.inflightDebtCollateralAmount).to.equal(toWei("2"))
    expect(debtStates.pendingFeeCollateralAmount).to.equal(toWei("1"))

    // 8 e
    // 2000u = 1e
    await weth.connect(user0).transfer(proxy.address, toWei("8"))
    const usdcHolder = await ethers.getImpersonatedSigner("0x47c031236e19d024b42f8ae6780e44a573170703")
    await setBalance(usdcHolder.address, toWei("1"))
    await usdc.connect(usdcHolder).transfer(proxy.address, toUnit("4500", 6))

    var tx = await proxy.connect(user0).afterOrderExecution(ethers.utils.id("mockOrder"), order, events)
    var receipt = await tx.wait()
    var debtResult = receipt.logs
      .map((log) => {
        try {
          return eventEmitter.interface.parseLog(log).args.result
        } catch {
          return null
        }
      })
      .filter((x) => x != null)[0]
    expect(debtResult.collateralBalance).to.equal(toWei("8"))
    expect(debtResult.totalFeeCollateralAmount).to.equal(toWei("1.2")) // 1 + 10 * 0.02
    expect(debtResult.repaidDebtCollateralAmount).to.equal(toWei("8"))
    expect(debtResult.repaidFeeCollateralAmount).to.equal(toWei("0"))
    // expect(debtResult.unpaidFeeCollateralAmount).to.equal(toWei("0.91")) // 500 / 2000 = 0.25
    expect(debtResult.secondaryTokenBalance).to.equal(toUnit("4500", 6))
    expect(debtResult.repaidDebtSecondaryTokenAmount).to.equal(toUnit("4000", 6))
    expect(debtResult.repaidFeeSecondaryTokenAmount).to.equal(toUnit("500", 6)) // 1.16 * 2000

    // should repay 8 eth + 1784 * 2 usd
    expect((await proxy.getPendingOrders()).length).to.equal(0)
    var debtStates = await proxy.muxAccountState()
    expect(debtStates.debtCollateralAmount).to.equal(toWei("2"))
    expect(debtStates.inflightDebtCollateralAmount).to.equal(toWei("2"))
    expect(debtStates.pendingFeeCollateralAmount).to.equal(toWei("0"))

    expect(await lendingPool.getAvailableLiquidity(weth.address)).to.equal(toWei("8"))
    expect(await lendingPool.getAvailableLiquidity(usdc.address)).to.equal(toUnit("4000", 6))

    expect(await weth.balanceOf(proxy.address)).to.equal(0)
    expect(await usdc.balanceOf(proxy.address)).to.equal(0)
  })

  it("repay no debt", async () => {
    await proxyFactory.connect(admin).setProjectAssetConfig(PROJECT_ID, "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336", [
      toUnit("0.02", 5),
      toUnit("0.006", 5),
      toUnit("0.005", 5),
      toUnit("0.00", 5),
      toUnit("0.02", 5),
      18,
      0, // unboostable
    ])

    const testAdmin = await ethers.getImpersonatedSigner("0x1426476e4ea1426c56a5b1d2469a62281e8dcfc9")
    const lendingPool = await ethers.getContractAt("LendingPool", "0x9Ba6172225118f3fa1D99EDb1cc698EA67B7d129")
    await lendingPool.connect(testAdmin).setBorrower(proxyFactory.address, true)
    // {
    //   const lendingPoolImp = await createContract("LendingPool", [])
    //   await proxyAdmin.connect(admin).upgrade(lendingPool.address, lendingPoolImp.address)
    //   console.log("upgraded")
    // }
    await proxyFactory.connect(admin).setLiquiditySource(2, 2, lendingPool.address)
    await proxyFactory.connect(admin).setKeeper(user0.address, true)

    const proxyAddress = await proxyFactory.getProxyAddress(
      PROJECT_ID,
      user0.address,
      weth.address,
      "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336",
      true
    )
    await proxyFactory.createProxy(PROJECT_ID, weth.address, "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336", true)
    const proxy = await ethers.getContractAt("TestGmxV2Adapter", proxyAddress)

    await setBalance(user0.address, toWei("200"))
    await weth.connect(user0).deposit({ value: toWei("100") })

    // set debut
    await proxy.debugSetDebtStates(toWei("0"), toWei("0"), toWei("0"), "0")
    await proxy.makeTestOrder(ethers.utils.id("mockOrder"), toWei("0"), toWei("0"), false)
    await mockGmxReader.setSizeInUsd(0)
    await priceHub.setPrice(weth.address, toWei("2000"))
    await priceHub.setPrice(usdc.address, toWei("1"))
    const { order, events } = await proxy.makeEmptyOrderParams()

    const usdcHolder = await ethers.getImpersonatedSigner("0x47c031236e19d024b42f8ae6780e44a573170703")
    await setBalance(usdcHolder.address, toWei("1"))

    // transfer
    // 10 e + 1e
    expect((await proxy.getPendingOrders()).length).to.equal(1)
    var debtStates = await proxy.muxAccountState()
    expect(debtStates.debtCollateralAmount).to.equal(toWei("0"))
    expect(debtStates.inflightDebtCollateralAmount).to.equal(toWei("0"))
    expect(debtStates.pendingFeeCollateralAmount).to.equal(toWei("0"))

    // 8 e
    // 2000u = 1e
    await weth.connect(user0).transfer(proxy.address, toWei("8"))
    await usdc.connect(usdcHolder).transfer(proxy.address, toUnit("4500", 6))
    await proxy.connect(user0).afterOrderExecution(ethers.utils.id("mockOrder"), order, events)

    expect(await weth.balanceOf(proxy.address)).to.equal(0)
    expect(await usdc.balanceOf(proxy.address)).to.equal(0)
  })
})
