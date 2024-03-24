import { ethers, network } from "hardhat"
import { expect } from "chai"
import { createContract, toWei } from "../scripts/deployUtils"
import { setBalance } from "@nomicfoundation/hardhat-network-helpers"

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

  beforeEach(async () => {
    const accounts = await ethers.getSigners()
    user0 = accounts[0]
    user1 = accounts[1]
    user2 = accounts[2]
    user3 = accounts[3]
    user4 = accounts[4]
  })

  it("LibDebt", async () => {
    const cases = await createContract("TestLibDebt", [], {})
    await cases.testAll()
  })

  it("LibUniswap", async () => {
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

    const cases = await createContract("TestLibSwap", [], {})

    const weth = await ethers.getContractAt("IWETH", "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1")
    await setBalance(user0.address, toWei("30"))
    await weth.connect(user0).deposit({ value: toWei("20") })
    await weth.connect(user0).transfer(cases.address, toWei("20"))
    await cases.testAll()
  })

  it("TestLibGmxV2", async () => {
    const cases = await createContract("TestLibGmxV2", [], {})
    await cases.testAll()
  })
})
