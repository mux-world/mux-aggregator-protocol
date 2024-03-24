import { ethers, network } from "hardhat"
import { expect } from "chai"
import { toWei, toUnit, fromUnit, fromWei, createContract } from "../scripts/deployUtils"
import { impersonateAccount, setBalance, time, mine } from "@nomicfoundation/hardhat-network-helpers"
import { IERC20, IReader, IReaderLite, IWETH } from "../typechain"

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { encodeRealtimeData, parseEventLog } from "./GmxV2Utils"

const U = ethers.utils
const B = ethers.BigNumber

describe("GmxV2Reader", async () => {
  const PROJECT_ID = 2

  let user0: SignerWithAddress
  let user1: SignerWithAddress
  let user2: SignerWithAddress
  let user3: SignerWithAddress
  let user4: SignerWithAddress

  let weth: IWETH
  let usdc: IERC20

  let rawReader: IReader
  let liteReader: IReaderLite

  beforeEach(async () => {
    const accounts = await ethers.getSigners()
    user0 = accounts[0]
    user1 = accounts[1]
    user2 = accounts[2]
    user3 = accounts[3]
    user4 = accounts[4]

    weth = await ethers.getContractAt("IWETH", "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1") // feedId = 0x74aca63821bf7ead199e924d261d277cbec96d1026ab65267d655c51b4536914
    usdc = await ethers.getContractAt("IERC20", "0xaf88d065e77c8cC2239327C5EDb3A432268e5831") // feedId = 0x95241f154d34539741b19ce4bae815473fd1b2a90ac3b4b023a692f31edfe90e

    rawReader = (await ethers.getContractAt("IReader", "0xf60becbba223EEA9495Da3f606753867eC10d139")) as IReader
    liteReader = (await ethers.getContractAt(
      "IReaderLite",
      "0xfDDD2F1EDf589CA96ed510367Af02cC5524C57AC"
    )) as IReaderLite
  })

  it("market", async () => {
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: "https://arb1.arbitrum.io/rpc",
            enabled: true,
            ignoreUnknownTxType: true, // added in our hardhat patch. see README.md
            blockNumber: 155405457, // modify me if ./cache/hardhat-network-fork was cleared
          },
        },
      ],
    })

    const dataStore = "0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8"
    const market = "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336"

    var raw = await rawReader.getMarket(dataStore, market)
    var lite = await liteReader.getMarketTokens(dataStore, market)
    expect(raw.marketToken).to.equal(lite.marketToken)
    expect(raw.indexToken).to.equal(lite.indexToken)
    expect(raw.longToken).to.equal(lite.longToken)
    expect(raw.shortToken).to.equal(lite.shortToken)
  })

  it("isOrderExist", async () => {
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: "https://arb1.arbitrum.io/rpc",
            enabled: true,
            ignoreUnknownTxType: true, // added in our hardhat patch. see README.md
            blockNumber: 155405457, // modify me if ./cache/hardhat-network-fork was cleared
          },
        },
      ],
    })

    const dataStore = "0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8"
    const market = "0x70d95587d40A2caf56bd97485aB3Eec10Bee6336"
    const key = "0xaf6c2ae63994f1a75bc33e69b765b141435f18fcf53c94ee7d97f6fb9d3a46fc"
    const keyNotExist = "0xaf6c2ae63994f1a75bc33e69b765b141435f18fcf53c94ee7d97f6fb9d3a46fd"

    var raw = await rawReader.getOrder(dataStore, key)
    var lite = await liteReader.isOrderExist(dataStore, key)
    expect(raw.addresses.account != "0x0000000000000000000000000000000000000000").to.equal(lite)
    console.log(raw.addresses.account, lite)

    var raw = await rawReader.getOrder(dataStore, keyNotExist)
    var lite = await liteReader.isOrderExist(dataStore, keyNotExist)
    expect(raw.addresses.account != "0x0000000000000000000000000000000000000000").to.equal(lite)
    console.log(raw.addresses.account, lite)
  })

  it("getPositionSizeInUsd", async () => {
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: "https://arb1.arbitrum.io/rpc",
            enabled: true,
            ignoreUnknownTxType: true, // added in our hardhat patch. see README.md
            blockNumber: 155407421, // modify me if ./cache/hardhat-network-fork was cleared
          },
        },
      ],
    })

    const dataStore = "0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8"
    const key = "0x401b696e62f83eb082e13e4d44352d9473968a59a4632e2f1d49b23460ad2058"
    const keyNotExist = "0x401b696e62f83eb082e13e4d44352d9473968a59a4632e2f1d49b23460ad2051"

    var raw = await rawReader.getPosition(dataStore, key)
    var lite = await liteReader.getPositionSizeInUsd(dataStore, key)
    expect(raw.numbers.sizeInUsd).equal(lite)

    var raw = await rawReader.getPosition(dataStore, keyNotExist)
    var lite = await liteReader.getPositionSizeInUsd(dataStore, keyNotExist)
    expect(raw.numbers.sizeInUsd).equal(lite)
  })

  it("getPositionInfo", async () => {
    await network.provider.request({
      method: "hardhat_reset",
      params: [
        {
          forking: {
            jsonRpcUrl: "https://arb1.arbitrum.io/rpc",
            enabled: true,
            ignoreUnknownTxType: true, // added in our hardhat patch. see README.md
            blockNumber: 155407421, // modify me if ./cache/hardhat-network-fork was cleared
          },
        },
      ],
    })

    const dataStore = "0xFD70de6b91282D8017aA4E741e9Ae325CAb992d8"
    const referralStore = "0xe6fab3F0c7199b0d34d7FbE83394fc0e0D06e99d"
    const key = "0x401b696e62f83eb082e13e4d44352d9473968a59a4632e2f1d49b23460ad2058"
    const keyNotExist = "0x401b696e62f83eb082e13e4d44352d9473968a59a4632e2f1d49b23460ad2051"
    const prices = {
      indexTokenPrice: {
        min: toUnit("1", 12),
        max: toUnit("1", 12),
      },
      longTokenPrice: {
        min: toUnit("1", 12),
        max: toUnit("1", 12),
      },
      shortTokenPrice: {
        min: toUnit("1", 24),
        max: toUnit("1", 24),
      },
    }

    var raw = await rawReader.getPositionInfo(
      dataStore,
      referralStore,
      key,
      prices,
      0,
      ethers.constants.AddressZero,
      true
    )
    var lite = await liteReader.getPositionMarginInfo(dataStore, referralStore, key, prices)
    expect(raw.position.numbers.sizeInUsd).equal(lite.sizeInUsd)
    expect(raw.position.numbers.collateralAmount).equal(lite.collateralAmount)
    expect(raw.fees.totalCostAmount).equal(lite.totalCostAmount)
    expect(raw.pnlAfterPriceImpactUsd).equal(lite.pnlAfterPriceImpactUsd)

    // var raw = await rawReader.getPositionInfo(
    //   dataStore,
    //   referralStore,
    //   keyNotExist,
    //   prices,
    //   0,
    //   ethers.constants.AddressZero,
    //   true
    // )
    // var lite = await liteReader.getPositionMarginInfo(dataStore, referralStore, keyNotExist, prices)
    // expect(raw.position.numbers.sizeInUsd).equal(lite.sizeInUsd)
    // expect(raw.position.numbers.collateralAmount).equal(lite.collateralAmount)
    // expect(raw.fees.totalCostAmount).equal(lite.totalCostAmount)
    // expect(raw.pnlAfterPriceImpactUsd).equal(lite.pnlAfterPriceImpactUsd)
  })
})
