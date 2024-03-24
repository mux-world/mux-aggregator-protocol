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
import { encodeRealtimeData } from "./GmxV2Utils"

const U = ethers.utils
const B = ethers.BigNumber

describe("Simulate", async () => {
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
            blockNumber: 144707133, // modify me if ./cache/hardhat-network-fork was cleared
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
    const adapter = await createContract("GmxV2Adapter", [], {
      LibGmxV2: await createContract("LibGmxV2", []),
      LibUtils: await createContract("contracts/aggregators/gmxV2/libraries/LibUtils.sol:LibUtils", []),
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
      pad32r(gmxReader.address),
      pad32r(priceHub.address),
      pad32r(eventEmitter.address),
      ethers.utils.formatBytes32String("muxprotocol"),
      3, // weth
      pad32r(weth.address),
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
        toUnit("0.00", 5),
        toUnit("0.006", 5),
        toUnit("0.005", 5),
        toUnit("0.00", 5),
        18,
      ])

    await proxyFactory.connect(admin).setBorrowConfig(PROJECT_ID, weth.address, 3, toWei("1000"))
    await proxyFactory.connect(admin).setBorrowConfig(PROJECT_ID, usdc.address, 11, toWei("1000"))

    // replace modifier
    const verifier = await createContract("MockRealtimeFeedVerifier", [])
    const verifyProxy = await ethers.getContractAt("IVerifierProxy", "0xDBaeB34DF0AcfA564a49e13840C5CE2894C4b886") // realtimeFeedVerifier

    const newVerifierCode = await ethers.provider.getCode(verifier.address)
    await ethers.provider.send("hardhat_setCode", [verifyProxy.address, newVerifierCode])

    // mockArbSys = await ethers.getContractAt("MockArbSys", "0x0000000000000000000000000000000000000064")
    // const initBlockNumber = await mockArbSys.arbBlockNumber()
    // mockArbSys = await createContract("MockArbSys", [initBlockNumber])
    // const newArbSysCode = await ethers.provider.getCode(mockArbSys.address)
    // await ethers.provider.send("hardhat_setCode", ["0x0000000000000000000000000000000000000064", newArbSysCode])
    // mockArbSys = await ethers.getContractAt("MockArbSys", "0x0000000000000000000000000000000000000064")
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
    return tx
  }

  it("createProxy - 0 boost fee", async () => {
    const market = "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336"
    const proxyAddress = await proxyFactory.getProxyAddress(PROJECT_ID, user0.address, weth.address, market, true)
    // await proxyFactory.createProxy(PROJECT_ID, weth.address, "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336", true)
    const proxy = (await ethers.getContractAt("GmxV2Adapter", proxyAddress)) as GmxV2Adapter

    await priceHub.setPrice(weth.address, toWei("1784"))
    await priceHub.setPrice(usdc.address, toWei("1"))

    await setBalance(user0.address, toWei("10"))
    await weth.connect(user0).deposit({ value: toWei("5") })
    await weth.connect(user0).approve(proxyFactory.address, toWei("5"))

    await proxyFactory.connect(user0).multicall([
      proxyFactory.interface.encodeFunctionData("transferToken", [
        2,
        weth.address,
        market,
        true,
        weth.address,
        toWei("1.05"),
      ]),
      proxyFactory.interface.encodeFunctionData("proxyFunctionCall", [
        {
          projectId: 2,
          collateralToken: weth.address,
          assetToken: market,
          isLong: true,
          referralCode: ethers.utils.formatBytes32String("muxprotocol"),
          value: 0,
          proxyCallData: proxy.interface.encodeFunctionData("openPosition", [
            {
              swapPath: [],
              initialCollateralAmount: toWei("1"),
              tokenOutMinAmount: 0,
              borrowCollateralAmount: toWei("1"),
              sizeDeltaUsd: toUnit("17840", 30),
              triggerPrice: 0,
              acceptablePrice: toUnit("1785", 12),
              tpTriggerPrice: 0,
              tpAcceptablePrice: 0,
              slTriggerPrice: 0,
              slAcceptablePrice: 0,
              openExecutionFee: toWei("0.05"),
              openCallbackGasLimit: "100000",
              closeExecutionFee: toWei("0.05"),
              closeCallbackGasLimit: "800000",
              flags: 0x40,
            },
          ]),
        },
      ]),
    ])
    var key = (await proxy.getPendingOrders())[0].key
    await fillGmxOrder(key, toUnit("1784", 8), toUnit("1", 8))
    console.log("open order done")

    // 2 * 1784 / 17840
    console.log(fromWei(await proxy.getMarginRate()))
    expect(await proxy.getMarginRate()).to.be.closeTo(toWei("0.2"), toWei("0.005"))

    await proxyFactory.connect(user0).multicall([
      proxyFactory.interface.encodeFunctionData("transferToken", [
        2,
        weth.address,
        market,
        true,
        weth.address,
        toWei("0.05"),
      ]),
      proxyFactory.interface.encodeFunctionData("proxyFunctionCall", [
        {
          projectId: 2,
          collateralToken: weth.address,
          assetToken: market,
          isLong: true,
          referralCode: ethers.utils.formatBytes32String("muxprotocol"),
          value: 0,
          proxyCallData: proxy.interface.encodeFunctionData("closePosition", [
            {
              swapPath: [],
              initialCollateralAmount: toWei("0"),
              tokenOutMinAmount: 0,
              borrowCollateralAmount: toWei("0"),
              sizeDeltaUsd: toUnit("8920", 30),
              triggerPrice: 0,
              acceptablePrice: toUnit("1781", 12),
              tpTriggerPrice: 0,
              tpAcceptablePrice: 0,
              slTriggerPrice: 0,
              slAcceptablePrice: 0,
              openExecutionFee: toWei("0.05"),
              openCallbackGasLimit: "100000",
              closeExecutionFee: toWei("0.05"),
              closeCallbackGasLimit: "800000",
              flags: 0x40,
            },
          ]),
        },
      ]),
    ])
    var key = (await proxy.getPendingOrders())[0].key
    await fillGmxOrder(key, toUnit("1784", 8), toUnit("1", 8))
    console.log("close order done")

    // 2 * 1784 / 17840
    console.log(fromWei(await proxy.getMarginRate()))
    expect(await proxy.getMarginRate()).to.be.closeTo(toWei("0.4"), toWei("0.005"))

    await proxyFactory.connect(user0).multicall([
      proxyFactory.interface.encodeFunctionData("transferToken", [
        2,
        weth.address,
        market,
        true,
        weth.address,
        toWei("0.05"),
      ]),
      proxyFactory.interface.encodeFunctionData("proxyFunctionCall", [
        {
          projectId: 2,
          collateralToken: weth.address,
          assetToken: market,
          isLong: true,
          referralCode: ethers.utils.formatBytes32String("muxprotocol"),
          value: 0,
          proxyCallData: proxy.interface.encodeFunctionData("closePosition", [
            {
              swapPath: [],
              initialCollateralAmount: toWei("1.5"),
              tokenOutMinAmount: 0,
              borrowCollateralAmount: toWei("0"),
              sizeDeltaUsd: toUnit("0", 30),
              triggerPrice: 0,
              acceptablePrice: toUnit("1781", 12),
              tpTriggerPrice: 0,
              tpAcceptablePrice: 0,
              slTriggerPrice: 0,
              slAcceptablePrice: 0,
              openExecutionFee: toWei("0.05"),
              openCallbackGasLimit: "100000",
              closeExecutionFee: toWei("0.05"),
              closeCallbackGasLimit: "800000",
              flags: 0x40,
            },
          ]),
        },
      ]),
    ])
    var key = (await proxy.getPendingOrders())[0].key
    await fillGmxOrder(key, toUnit("1784", 8), toUnit("1", 8))
    console.log("close order done")

    console.log(fromWei(await proxy.getMarginRate()))
    expect(await proxy.getMarginRate()).to.be.closeTo(toWei("0.1"), toWei("0.005"))
  })
})
