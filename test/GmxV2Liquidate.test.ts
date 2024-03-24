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

describe("GmxV2-Liquidate", async () => {
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
  let readerLiteCode: any

  const pad32r = (s: string) => {
    if (s.length > 66) {
      return s
    } else if (s.startsWith("0x") || s.startsWith("0X")) {
      return s + "0".repeat(66 - s.length)
    } else {
      return s + "0".repeat(64 - s.length)
    }
  }

  before(async () => {
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: "https://arb1.arbitrum.io/rpc",
            enabled: true,
            ignoreUnknownTxType: true, // added in our hardhat patch. see README.md
            blockNumber: 155426264, // modify me if ./cache/hardhat-network-fork was cleared
          },
        },
      ],
    })
    readerLiteCode = await ethers.provider.getCode("0xfDDD2F1EDf589CA96ed510367Af02cC5524C57AC")
  })

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

    await ethers.provider.send("hardhat_setCode", ["0xf60becbba223EEA9495Da3f606753867eC10d139", readerLiteCode])

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
        toUnit("0.01", 5),
        toUnit("0.02", 5),
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
        blocknumberLowerBound: number - 10,
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
        blocknumberLowerBound: number - 10,
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

  enum OrderType {
    MarketSwap = 0,
    LimitSwap,
    MarketIncrease,
    LimitIncrease,
    MarketDecrease,
    LimitDecrease,
    StopLossDecrease,
    Liquidation,
  }

  it("margin rate", async () => {
    const market = "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336"
    const proxyAddress = await proxyFactory.getProxyAddress(PROJECT_ID, user0.address, weth.address, market, true)
    // await proxyFactory.createProxy(PROJECT_ID, weth.address, "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336", true)
    const proxy = (await ethers.getContractAt("GmxV2Adapter", proxyAddress)) as GmxV2Adapter
    await proxyFactory.connect(admin).setKeeper(user0.address, true)

    await priceHub.setPrice(weth.address, toWei("1784"))
    await priceHub.setPrice(usdc.address, toWei("1"))

    await setBalance(user0.address, toWei("10"))
    await weth.connect(user0).deposit({ value: toWei("1.10") })
    await weth.connect(user0).approve(proxyFactory.address, toWei("1.10"))
    expect(await weth.balanceOf(user0.address)).to.equal(toWei("1.10"))

    await proxyFactory.connect(user0).multicall([
      proxyFactory.interface.encodeFunctionData("transferToken", [
        2,
        weth.address,
        market,
        true,
        weth.address,
        toWei("0.15"),
      ]),
      proxyFactory.interface.encodeFunctionData("proxyFunctionCall", [
        {
          projectId: 2,
          collateralToken: weth.address,
          assetToken: market,
          isLong: true,
          referralCode: ethers.utils.formatBytes32String("muxprotocol"),
          value: 0,
          proxyCallData: proxy.interface.encodeFunctionData("placeOrder", [
            {
              swapPath: [],
              initialCollateralAmount: toWei("0.1"),
              tokenOutMinAmount: 0,
              borrowCollateralAmount: toWei("0.1"),
              sizeDeltaUsd: toUnit("17840", 30),
              triggerPrice: 0,
              acceptablePrice: toUnit("1785", 12),
              executionFee: toWei("0.05"),
              callbackGasLimit: "200000",
              orderType: OrderType.MarketIncrease,
            },
          ]),
        },
      ]),
    ])

    var key = (await proxy.getPendingOrders())[0].key
    await fillGmxOrder(key, toUnit("1784", 8), toUnit("1", 8))

    console.log(fromWei(await proxy.getMarginRate())) // 100x 0.01
    console.log(await proxy.isLiquidateable()) // 100x 0.01

    await expect(
      proxy.liquidatePosition(
        {
          collateralPrice: toWei("1784"),
          indexTokenPrice: toWei("1784"),
          longTokenPrice: toWei("1784"),
          shortTokenPrice: toWei("1"),
        },
        toWei("0.05"),
        "400000"
      )
    ).to.be.revertedWith("Safe")

    await priceHub.setPrice(weth.address, toWei("1775"))
    await priceHub.setPrice(usdc.address, toWei("1"))

    console.log(fromWei(await proxy.getMarginRate())) // 100x 0.01
    console.log(await proxy.isLiquidateable()) // 100x 0.01

    await weth.connect(user0).transfer(proxy.address, toWei("0.5"))
    await proxy.liquidatePosition(
      {
        collateralPrice: toWei("1775"),
        indexTokenPrice: toWei("1775"),
        longTokenPrice: toWei("1775"),
        shortTokenPrice: toWei("1"),
      },
      toWei("0.05"),
      "400000"
    )

    await expect(
      proxyFactory.connect(user0).multicall([
        proxyFactory.interface.encodeFunctionData("proxyFunctionCall", [
          {
            projectId: 2,
            collateralToken: weth.address,
            assetToken: market,
            isLong: true,
            referralCode: ethers.utils.formatBytes32String("muxprotocol"),
            value: 0,
            proxyCallData: proxy.interface.encodeFunctionData("placeOrder", [
              {
                swapPath: [],
                initialCollateralAmount: toWei("0"),
                tokenOutMinAmount: 0,
                borrowCollateralAmount: toWei("0"),
                sizeDeltaUsd: toUnit("17840", 30),
                triggerPrice: 0,
                acceptablePrice: toUnit("1781", 12),
                executionFee: toWei("0.05"),
                callbackGasLimit: "400000",
                orderType: OrderType.MarketDecrease,
              },
            ]),
          },
        ]),
      ])
    ).to.be.revertedWith("Liquidating")

    await expect(
      proxyFactory.connect(user0).multicall([
        proxyFactory.interface.encodeFunctionData("proxyFunctionCall", [
          {
            projectId: 2,
            collateralToken: weth.address,
            assetToken: market,
            isLong: true,
            referralCode: ethers.utils.formatBytes32String("muxprotocol"),
            value: 0,
            proxyCallData: proxy.interface.encodeFunctionData("updateOrder", [
              ethers.constants.HashZero,
              toWei("0"),
              toWei("0"),
              toWei("0"),
            ]),
          },
        ]),
      ])
    ).to.be.revertedWith("Liquidating")

    await expect(
      proxy.liquidatePosition(
        {
          collateralPrice: toWei("0"),
          indexTokenPrice: toWei("0"),
          longTokenPrice: toWei("0"),
          shortTokenPrice: toWei("0"),
        },
        toWei("0"),
        toWei("0")
      )
    ).to.be.revertedWith("Liquidating")
    await expect(
      proxyFactory.connect(user0).multicall([
        proxyFactory.interface.encodeFunctionData("proxyFunctionCall", [
          {
            projectId: 2,
            collateralToken: weth.address,
            assetToken: market,
            isLong: true,
            referralCode: ethers.utils.formatBytes32String("muxprotocol"),
            value: 0,
            proxyCallData: proxy.interface.encodeFunctionData("cancelOrder", [ethers.constants.HashZero]),
          },
        ]),
      ])
    ).to.be.revertedWith("Liquidating")

    var key = (await proxy.getPendingOrders())[0].key
    var tx = await fillGmxOrder(key, toUnit("1775", 8), toUnit("1", 8))
    console.log("liquidate order done")
    console.log(fromWei(await proxy.getMarginRate()))

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
    console.log(debtResult)
  })
})
