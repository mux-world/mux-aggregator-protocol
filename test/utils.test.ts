import "@nomiclabs/hardhat-ethers"
import { expect } from "chai"
import { getPriceBits } from "../scripts/deployUtils"

describe("Utils", () => {
  it("getPriceBits", () => {
    expect(
      getPriceBits([
        "19736.500", // BTC
        "1460.459", // ETH
        "7.688", // LINK
        "5.830", // UNI
      ])
    ).to.eq("0x00000000000000000000000000000000000016c600001e08001648eb012d27b4")
    expect(getPriceBits([])).to.eq("0x0000000000000000000000000000000000000000000000000000000000000000")
  })
})
