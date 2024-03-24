import { ethers, network } from "hardhat"
import { expect } from "chai"
import { createContract, toWei, toUnit } from "../scripts/deployUtils"
import { impersonateAccount, setBalance } from "@nomicfoundation/hardhat-network-helpers"

import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { encodeRealtimeData } from "./GmxV2Utils"

const U = ethers.utils
const B = ethers.BigNumber

const pad32r = (s: string) => {
  if (s.length > 66) {
    return s
  } else if (s.startsWith("0x") || s.startsWith("0X")) {
    return s + "0".repeat(66 - s.length)
  } else {
    return s + "0".repeat(64 - s.length)
  }
}

describe("GmxV2-Debt", async () => {
  const PROJECT_ID = 2

  let user0: SignerWithAddress
  let user1: SignerWithAddress
  let user2: SignerWithAddress
  let user3: SignerWithAddress
  let user4: SignerWithAddress

  let rawPool: any
  let lendingPool: any
  let libTest: any
  let factory: any
  let priceHub: any

  let weth: any
  let usdc: any

  beforeEach(async () => {
    const accounts = await ethers.getSigners()
    user0 = accounts[0]
    user1 = accounts[1]
    user2 = accounts[2]
    user3 = accounts[3]
    user4 = accounts[4]

    weth = await createContract("MockERC20", ["WETH", "WETH", 18])
    usdc = await createContract("MockERC20", ["USDC", "USDC", 6])

    priceHub = await createContract("MockPriceHub")
    lendingPool = await createContract("LendingPool")

    await lendingPool.initialize(lendingPool.address, priceHub.address, ethers.constants.AddressZero)

    await priceHub.setPrice(weth.address, toWei("2000"))
    await priceHub.setPrice(usdc.address, toWei("1"))

    await lendingPool.setMaintainer(user0.address, true)
  })

  const STATE_IS_ENABLED = 0x1
  const STATE_IS_BORROWABLE = 0x2
  const STATE_IS_REPAYABLE = 0x4
  const STATE_IS_DEPOSITABLE = 0x8
  const STATE_IS_WITHDRAWABLE = 0x10

  it("deposit / withdraw", async () => {
    await expect(lendingPool.deposit(weth.address, toWei("1"))).to.be.revertedWith("Forbidden")
    await lendingPool.enable(weth.address, STATE_IS_ENABLED)
    await expect(lendingPool.deposit(weth.address, toWei("1"))).to.be.revertedWith("Forbidden")
    await lendingPool.enable(weth.address, STATE_IS_DEPOSITABLE)
    console.log(await lendingPool.getStatusOf(weth.address))

    await weth.mint(user0.address, toWei("1"))
    await weth.approve(lendingPool.address, toWei("1"))
    await lendingPool.deposit(weth.address, toWei("1"))
    expect(await lendingPool.getAvailableLiquidity(weth.address)).to.eq(toWei("1"))
    expect(await weth.balanceOf(lendingPool.address)).to.eq(toWei("1"))

    await expect(lendingPool.withdraw(weth.address, toWei("1"))).to.be.revertedWith("Forbidden")
    await lendingPool.enable(weth.address, STATE_IS_WITHDRAWABLE)
    console.log(await lendingPool.getStatusOf(weth.address))

    await expect(lendingPool.withdraw(weth.address, toWei("2"))).to.be.revertedWith("InsufficientSupply")
    await lendingPool.withdraw(weth.address, toWei("1"))
    expect(await lendingPool.getAvailableLiquidity(weth.address)).to.eq(toWei("0"))
    expect(await weth.balanceOf(lendingPool.address)).to.eq(toWei("0"))
  })

  it("borrow / repay", async () => {
    await lendingPool.enable(weth.address, STATE_IS_ENABLED | STATE_IS_DEPOSITABLE)
    await lendingPool.enable(usdc.address, STATE_IS_ENABLED | STATE_IS_DEPOSITABLE)

    await weth.mint(user0.address, toWei("10"))
    await weth.approve(lendingPool.address, toWei("10"))
    await lendingPool.deposit(weth.address, toWei("10"))

    await usdc.mint(user0.address, toUnit("10000", 6))
    await usdc.approve(lendingPool.address, toUnit("10000", 6))
    await lendingPool.deposit(usdc.address, toUnit("10000", 6))

    await expect(lendingPool.borrowToken(2, user0.address, weth.address, toWei("1"), toWei("0"))).to.be.revertedWith(
      "UnauthorizedCaller"
    )
    await lendingPool.setBorrower(user0.address, true)
    await expect(lendingPool.borrowToken(2, user0.address, weth.address, toWei("11"), toWei("0"))).to.be.revertedWith(
      "Forbidden"
    )
    await lendingPool.enable(weth.address, STATE_IS_BORROWABLE)
    await expect(lendingPool.borrowToken(2, user0.address, weth.address, toWei("11"), toWei("0"))).to.be.revertedWith(
      "InsufficientSupply"
    )
    expect(await weth.balanceOf(user0.address)).to.eq(toWei("0"))
    await lendingPool.borrowToken(2, user0.address, weth.address, toWei("2"), toWei("0.1"))
    expect(await lendingPool.getAvailableLiquidity(weth.address)).to.eq(toWei("8"))
    var states = await lendingPool.getBorrowStates(weth.address)
    expect(states.supplyAmount).to.eq(toWei("8"))
    expect(states.borrowFeeAmount).to.eq(toWei("0.1"))
    expect(states.totalAmountOut).to.eq(toWei("2"))
    expect(states.totalAmountIn).to.eq(toWei("0"))
    expect(await lendingPool.getTotalDebtUsd()).to.eq(toWei("4000"))
    expect(await lendingPool.getDebtUsdOf(user0.address)).to.eq(toWei("4000"))
    expect(await weth.balanceOf(user0.address)).to.eq(toWei("2").sub(toWei("0.1")))

    await lendingPool.enable(usdc.address, STATE_IS_BORROWABLE)
    expect(await usdc.balanceOf(user0.address)).to.eq(toUnit("0", 6))
    await lendingPool.borrowToken(2, user0.address, usdc.address, toUnit("100", 6), toUnit("1", 6))
    expect(await usdc.balanceOf(user0.address)).to.eq(toUnit("100", 6).sub(toUnit("1", 6)))
    expect(await lendingPool.getTotalDebtUsd()).to.eq(toWei("4100"))
    expect(await lendingPool.getDebtUsdOf(user0.address)).to.eq(toWei("4100"))

    await expect(lendingPool.repayToken(2, user0.address, weth.address, toWei("1"), toWei("0.1"))).to.be.revertedWith(
      "Forbidden"
    )
    await lendingPool.enable(weth.address, STATE_IS_REPAYABLE)
    await weth.transfer(lendingPool.address, toWei("1.9"))
    await lendingPool.repayToken(2, user0.address, weth.address, toWei("1.8"), toWei("0.1"))
    var states = await lendingPool.getBorrowStates(weth.address)
    expect(states.supplyAmount).to.eq(toWei("9.8"))
    expect(states.borrowFeeAmount).to.eq(toWei("0.2"))
    expect(states.totalAmountOut).to.eq(toWei("2"))
    expect(states.totalAmountIn).to.eq(toWei("1.8"))
    expect(await lendingPool.getTotalDebtUsd()).to.eq(toWei("500")) // 0.2 * 2000 + 100 * 1 = 500
    expect(await lendingPool.getDebtUsdOf(user0.address)).to.eq(toWei("500"))
    expect(await weth.balanceOf(lendingPool.address)).to.eq(toWei("9.8").add(toWei("0.2")))

    await lendingPool.enable(usdc.address, STATE_IS_REPAYABLE)
    await usdc.transfer(lendingPool.address, toUnit("99", 6))
    await lendingPool.repayToken(2, user0.address, usdc.address, toUnit("98", 6), toUnit("1", 6))
    var states = await lendingPool.getBorrowStates(usdc.address)
    expect(states.supplyAmount).to.eq(toUnit("9998", 6))
    expect(states.borrowFeeAmount).to.eq(toUnit("2", 6))
    expect(states.totalAmountOut).to.eq(toUnit("100", 6))
    expect(states.totalAmountIn).to.eq(toUnit("98", 6))

    await usdc.mint(user0.address, toUnit("1000", 6))
    await usdc.transfer(lendingPool.address, toUnit("1000", 6))
    await lendingPool.repayToken(2, user0.address, usdc.address, toUnit("1000", 6), toUnit("0", 6))
    var states = await lendingPool.getBorrowStates(usdc.address)
    expect(states.supplyAmount).to.eq(toUnit("10998", 6))
    expect(states.borrowFeeAmount).to.eq(toUnit("2", 6))
    expect(states.totalAmountOut).to.eq(toUnit("100", 6))
    expect(states.totalAmountIn).to.eq(toUnit("1098", 6))

    expect(await lendingPool.getTotalDebtUsd()).to.eq(toWei("0"))
    expect(await lendingPool.getDebtUsdOf(user0.address)).to.eq(toWei("0"))
  })

  it("settings", async () => {
    expect(await lendingPool.isMaintainer(user1.address)).to.equal(false)
    await lendingPool.setMaintainer(user1.address, true)
    expect(await lendingPool.isMaintainer(user1.address)).to.equal(true)
    await lendingPool.setMaintainer(user1.address, false)
    expect(await lendingPool.isMaintainer(user1.address)).to.equal(false)

    await expect(lendingPool.connect(user1).enable(weth.address, STATE_IS_ENABLED)).to.be.revertedWith(
      "UnauthorizedCaller"
    )
    var { isEnabled, isBorrowable, isRepayable, isDepositable, isWithdrawable } = await lendingPool.getStatusOf(
      weth.address
    )
    expect(isEnabled).to.equal(false)
    expect(isBorrowable).to.equal(false)
    expect(isRepayable).to.equal(false)
    expect(isDepositable).to.equal(false)
    expect(isWithdrawable).to.equal(false)

    const toSet = [
      STATE_IS_ENABLED,
      STATE_IS_BORROWABLE,
      STATE_IS_REPAYABLE,
      STATE_IS_DEPOSITABLE,
      STATE_IS_WITHDRAWABLE,
    ]

    for (let i = 0; i < toSet.length; i++) {
      await lendingPool.enable(weth.address, toSet[i])
      var { isEnabled, isBorrowable, isRepayable, isDepositable, isWithdrawable } = await lendingPool.getStatusOf(
        weth.address
      )
      expect(isEnabled).to.equal(STATE_IS_ENABLED <= toSet[i])
      expect(isBorrowable).to.equal(STATE_IS_BORROWABLE <= toSet[i])
      expect(isRepayable).to.equal(STATE_IS_REPAYABLE <= toSet[i])
      expect(isDepositable).to.equal(STATE_IS_DEPOSITABLE <= toSet[i])
      expect(isWithdrawable).to.equal(STATE_IS_WITHDRAWABLE <= toSet[i])
    }

    for (let i = 0; i < toSet.length; i++) {
      await lendingPool.disable(weth.address, toSet[i])
      var { isEnabled, isBorrowable, isRepayable, isDepositable, isWithdrawable } = await lendingPool.getStatusOf(
        weth.address
      )
      expect(isEnabled).to.equal(STATE_IS_ENABLED > toSet[i])
      expect(isBorrowable).to.equal(STATE_IS_BORROWABLE > toSet[i])
      expect(isRepayable).to.equal(STATE_IS_REPAYABLE > toSet[i])
      expect(isDepositable).to.equal(STATE_IS_DEPOSITABLE > toSet[i])
      expect(isWithdrawable).to.equal(STATE_IS_WITHDRAWABLE > toSet[i])
    }
  })
})
