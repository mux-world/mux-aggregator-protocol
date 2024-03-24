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
    usdc = await createContract("MockERC20", ["USDC", "USDC", 18])

    rawPool = await createContract("MockLiquidityPool")
    factory = await createContract("MockProjectFactory", [2])
    priceHub = await createContract("MockPriceHub")

    lendingPool = await createContract("LendingPool")
    await lendingPool.initialize(lendingPool.address, priceHub.address, ethers.constants.AddressZero)

    await priceHub.setPrice(weth.address, toWei("2000"))
    await priceHub.setPrice(usdc.address, toWei("1"))

    libTest = await createContract("TestLibDebt2", [], {
      LibGmxV2: await createContract("LibGmxV2", []),
    })
    await libTest.setFactory(factory.address)

    await libTest.setProjectConfig([
      pad32r(ethers.constants.AddressZero),
      pad32r(ethers.constants.AddressZero),
      pad32r(ethers.constants.AddressZero),
      pad32r(ethers.constants.AddressZero),
      pad32r(ethers.constants.AddressZero),
      pad32r(ethers.constants.AddressZero),
      pad32r(ethers.constants.AddressZero),
      pad32r(ethers.constants.AddressZero),
      pad32r(ethers.constants.AddressZero),
      3,
      pad32r(weth.address),
      pad32r(lendingPool.address),
    ])

    await libTest.setMarketConfig([
      toUnit("0.02", 5),
      toUnit("0.006", 5),
      toUnit("0.005", 5),
      toUnit("0.00", 5),
      toUnit("0.02", 5),
      18,
    ])

    await lendingPool.setMaintainer(user0.address, true)
    await lendingPool.setBorrower(factory.address, true)
    await factory.setLendingPool(lendingPool.address)
  })

  const STATE_IS_ENABLED = 0x1
  const STATE_IS_BORROWABLE = 0x2
  const STATE_IS_REPAYABLE = 0x4
  const STATE_IS_DEPOSITABLE = 0x8
  const STATE_IS_WITHDRAWABLE = 0x16

  it("deposit", async () => {
    await expect(lendingPool.deposit(weth.address, toWei("10"))).to.be.revertedWith("Forbidden")
    await lendingPool.enable(weth.address, STATE_IS_ENABLED | STATE_IS_DEPOSITABLE | STATE_IS_WITHDRAWABLE)
    console.log(await lendingPool.getFlagsOf(weth.address))

    await weth.mint(user0.address, toWei("10"))
    await weth.approve(lendingPool.address, toWei("10"))
    await lendingPool.deposit(weth.address, toWei("10"))
    var states = await lendingPool.getBorrowStates(weth.address)
    expect(states.supplyAmount).to.equal(toWei("10"))
    expect(await weth.balanceOf(lendingPool.address)).to.equal(toWei("10"))

    await lendingPool.disable(weth.address, STATE_IS_ENABLED)
    console.log(await lendingPool.getFlagsOf(weth.address))

    await expect(lendingPool.deposit(weth.address, toWei("10"))).to.be.revertedWith("Forbidden")
    await expect(lendingPool.withdraw(weth.address, toWei("10"))).to.be.revertedWith("Forbidden")

    await lendingPool.enable(weth.address, STATE_IS_ENABLED)
    console.log(await lendingPool.getFlagsOf(weth.address))

    await lendingPool.withdraw(weth.address, toWei("5"))
    var states = await lendingPool.getBorrowStates(weth.address)
    expect(states.supplyAmount).to.equal(toWei("5"))
    expect(await weth.balanceOf(lendingPool.address)).to.equal(toWei("5"))
  })

  it("borrowAsset", async () => {
    await lendingPool.enable(
      weth.address,
      STATE_IS_ENABLED | STATE_IS_DEPOSITABLE | STATE_IS_BORROWABLE | STATE_IS_REPAYABLE
    )

    await weth.mint(user0.address, toWei("10"))
    await weth.approve(lendingPool.address, toWei("10"))
    await lendingPool.deposit(weth.address, toWei("10"))

    await libTest.setTokens(weth.address, usdc.address, weth.address)

    await libTest.borrowAsset(toWei("1.5"))
    var states = await lendingPool.getBorrowStates(weth.address)
    expect(states.supplyAmount).to.equal(toWei("8.5"))
    expect(states.totalAmountOut).to.equal(toWei("1.5")) // 1.5 * 0.02 = 0.03
    expect(await weth.balanceOf(lendingPool.address)).to.equal(toWei("8.5").add(toWei("0.03")))
    expect(await weth.balanceOf(libTest.address)).to.equal(toWei("1.5").sub(toWei("0.03")))

    var account = await libTest.muxAccountState()
    expect(account.debtCollateralAmount).to.equal(toWei("1.5"))
    expect(account.inflightDebtCollateralAmount).to.equal(toWei("0"))
    expect(account.pendingFeeCollateralAmount).to.equal(toWei("0"))
    expect(account.debtEntryFunding).to.equal(toWei("0"))

    await libTest.borrowAsset(toWei("2"))
    var states = await lendingPool.getBorrowStates(weth.address)
    expect(states.supplyAmount).to.equal(toWei("6.5"))
    expect(states.totalAmountOut).to.equal(toWei("3.5")) // 1.5 * 0.02 = 0.03
    expect(await weth.balanceOf(lendingPool.address)).to.equal(toWei("6.5").add(toWei("0.07")))
    expect(await weth.balanceOf(libTest.address)).to.equal(toWei("3.5").sub(toWei("0.07")))

    await libTest.borrowAsset(toWei("6.5"))
    var states = await lendingPool.getBorrowStates(weth.address)
    expect(states.supplyAmount).to.equal(toWei("0"))
    expect(states.totalAmountOut).to.equal(toWei("10")) // 1.5 * 0.02 = 0.03
    expect(await weth.balanceOf(lendingPool.address)).to.equal(toWei("0").add(toWei("0.2")))
    expect(await weth.balanceOf(libTest.address)).to.equal(toWei("10").sub(toWei("0.2")))

    await expect(libTest.borrowAsset(toWei("1"))).to.be.revertedWith("InsufficientSupply")
  })

  it("repayCancelledDebt", async () => {
    await lendingPool.enable(
      weth.address,
      STATE_IS_ENABLED | STATE_IS_DEPOSITABLE | STATE_IS_BORROWABLE | STATE_IS_REPAYABLE
    )

    await libTest.setOwner(user0.address)
    await libTest.setTokens(weth.address, usdc.address, weth.address)
    await libTest.setDebtStates(toWei("0.5"), toWei("0"), toWei("0"), toWei("0"))

    await expect(libTest.repayCancelledDebt(toWei("1.5"), toWei("0.5"))).to.be.revertedWith("NotEnoughBalance")
    await weth.mint(libTest.address, toWei("1.5"))
    await libTest.repayCancelledDebt(toWei("1.5"), toWei("0.5"))

    var account = await libTest.muxAccountState()
    expect(account.debtCollateralAmount).to.equal(toWei("0"))
    expect(account.inflightDebtCollateralAmount).to.equal(toWei("0"))
    expect(account.pendingFeeCollateralAmount).to.equal(toWei("0"))
    expect(account.debtEntryFunding).to.equal(toWei("0"))
  })

  it("repayByCollateral", async () => {
    await lendingPool.enable(
      weth.address,
      STATE_IS_ENABLED | STATE_IS_DEPOSITABLE | STATE_IS_BORROWABLE | STATE_IS_REPAYABLE
    )

    await libTest.setOwner(user0.address)
    await libTest.setTokens(weth.address, usdc.address, weth.address)
    await libTest.setDebtStates(toWei("1.5"), toWei("0"), toWei("0"), toWei("0"))

    await weth.mint(libTest.address, toWei("1.2"))
    // partial collateral
    var {
      remainCollateralAmount,
      repaidCollateralAmount,
      repaidFeeCollateralAmount,
      unpaidDebtCollateralAmount,
      unpaidFeeCollateralAmount,
    } = await libTest.callStatic.repayByCollateral(toWei("1.5"), toWei("0.1"), toWei("1.2"))
    expect(remainCollateralAmount).to.equal(0)
    expect(repaidCollateralAmount).to.equal(toWei("1.2"))
    expect(repaidFeeCollateralAmount).to.equal(0)
    expect(unpaidDebtCollateralAmount).to.equal(toWei("0.3"))
    expect(unpaidFeeCollateralAmount).to.equal(toWei("0.1"))

    // all collateral, no fee
    var {
      remainCollateralAmount,
      repaidCollateralAmount,
      repaidFeeCollateralAmount,
      unpaidDebtCollateralAmount,
      unpaidFeeCollateralAmount,
    } = await libTest.callStatic.repayByCollateral(toWei("1.2"), toWei("0.1"), toWei("1.2"))
    expect(remainCollateralAmount).to.equal(0)
    expect(repaidCollateralAmount).to.equal(toWei("1.2"))
    expect(repaidFeeCollateralAmount).to.equal(0)
    expect(unpaidDebtCollateralAmount).to.equal(toWei("0"))
    expect(unpaidFeeCollateralAmount).to.equal(toWei("0.1"))

    // all collateral, partial fee
    var {
      remainCollateralAmount,
      repaidCollateralAmount,
      repaidFeeCollateralAmount,
      unpaidDebtCollateralAmount,
      unpaidFeeCollateralAmount,
    } = await libTest.callStatic.repayByCollateral(toWei("1.15"), toWei("0.1"), toWei("1.2"))
    expect(remainCollateralAmount).to.equal(0)
    expect(repaidCollateralAmount).to.equal(toWei("1.15"))
    expect(repaidFeeCollateralAmount).to.equal(toWei("0.05"))
    expect(unpaidDebtCollateralAmount).to.equal(toWei("0"))
    expect(unpaidFeeCollateralAmount).to.equal(toWei("0.05"))

    // all collateral, all fee
    var {
      remainCollateralAmount,
      repaidCollateralAmount,
      repaidFeeCollateralAmount,
      unpaidDebtCollateralAmount,
      unpaidFeeCollateralAmount,
    } = await libTest.callStatic.repayByCollateral(toWei("1.1"), toWei("0.1"), toWei("1.2"))
    expect(remainCollateralAmount).to.equal(0)
    expect(repaidCollateralAmount).to.equal(toWei("1.1"))
    expect(repaidFeeCollateralAmount).to.equal(toWei("0.1"))
    expect(unpaidDebtCollateralAmount).to.equal(toWei("0"))
    expect(unpaidFeeCollateralAmount).to.equal(toWei("0"))

    // all collateral, all fee
    var {
      remainCollateralAmount,
      repaidCollateralAmount,
      repaidFeeCollateralAmount,
      unpaidDebtCollateralAmount,
      unpaidFeeCollateralAmount,
    } = await libTest.callStatic.repayByCollateral(toWei("1"), toWei("0.1"), toWei("1.2"))
    expect(remainCollateralAmount).to.equal(toWei("0.1"))
    expect(repaidCollateralAmount).to.equal(toWei("1"))
    expect(repaidFeeCollateralAmount).to.equal(toWei("0.1"))
    expect(unpaidDebtCollateralAmount).to.equal(toWei("0"))
    expect(unpaidFeeCollateralAmount).to.equal(toWei("0"))
  })

  it("repayByCollateral", async () => {
    await lendingPool.enable(
      weth.address,
      STATE_IS_ENABLED | STATE_IS_DEPOSITABLE | STATE_IS_BORROWABLE | STATE_IS_REPAYABLE
    )

    await libTest.setOwner(user0.address)
    await libTest.setTokens(weth.address, usdc.address, weth.address)
    await libTest.setDebtStates(toWei("1.5"), toWei("0"), toWei("0"), toWei("0"))

    await weth.mint(libTest.address, toWei("1.2"))
    // partial collateral
    var {
      remainCollateralAmount,
      repaidCollateralAmount,
      repaidFeeCollateralAmount,
      unpaidDebtCollateralAmount,
      unpaidFeeCollateralAmount,
    } = await libTest.callStatic.repayByCollateral(toWei("1.5"), toWei("0.1"), toWei("1.2"))
    expect(remainCollateralAmount).to.equal(0)
    expect(repaidCollateralAmount).to.equal(toWei("1.2"))
    expect(repaidFeeCollateralAmount).to.equal(0)
    expect(unpaidDebtCollateralAmount).to.equal(toWei("0.3"))
    expect(unpaidFeeCollateralAmount).to.equal(toWei("0.1"))

    // all collateral, no fee
    var {
      remainCollateralAmount,
      repaidCollateralAmount,
      repaidFeeCollateralAmount,
      unpaidDebtCollateralAmount,
      unpaidFeeCollateralAmount,
    } = await libTest.callStatic.repayByCollateral(toWei("1.2"), toWei("0.1"), toWei("1.2"))
    expect(remainCollateralAmount).to.equal(0)
    expect(repaidCollateralAmount).to.equal(toWei("1.2"))
    expect(repaidFeeCollateralAmount).to.equal(0)
    expect(unpaidDebtCollateralAmount).to.equal(toWei("0"))
    expect(unpaidFeeCollateralAmount).to.equal(toWei("0.1"))

    // all collateral, partial fee
    var {
      remainCollateralAmount,
      repaidCollateralAmount,
      repaidFeeCollateralAmount,
      unpaidDebtCollateralAmount,
      unpaidFeeCollateralAmount,
    } = await libTest.callStatic.repayByCollateral(toWei("1.15"), toWei("0.1"), toWei("1.2"))
    expect(remainCollateralAmount).to.equal(0)
    expect(repaidCollateralAmount).to.equal(toWei("1.15"))
    expect(repaidFeeCollateralAmount).to.equal(toWei("0.05"))
    expect(unpaidDebtCollateralAmount).to.equal(toWei("0"))
    expect(unpaidFeeCollateralAmount).to.equal(toWei("0.05"))

    // all collateral, all fee
    var {
      remainCollateralAmount,
      repaidCollateralAmount,
      repaidFeeCollateralAmount,
      unpaidDebtCollateralAmount,
      unpaidFeeCollateralAmount,
    } = await libTest.callStatic.repayByCollateral(toWei("1.1"), toWei("0.1"), toWei("1.2"))
    expect(remainCollateralAmount).to.equal(0)
    expect(repaidCollateralAmount).to.equal(toWei("1.1"))
    expect(repaidFeeCollateralAmount).to.equal(toWei("0.1"))
    expect(unpaidDebtCollateralAmount).to.equal(toWei("0"))
    expect(unpaidFeeCollateralAmount).to.equal(toWei("0"))

    // all collateral, all fee
    var {
      remainCollateralAmount,
      repaidCollateralAmount,
      repaidFeeCollateralAmount,
      unpaidDebtCollateralAmount,
      unpaidFeeCollateralAmount,
    } = await libTest.callStatic.repayByCollateral(toWei("1"), toWei("0.1"), toWei("1.2"))
    expect(remainCollateralAmount).to.equal(toWei("0.1"))
    expect(repaidCollateralAmount).to.equal(toWei("1"))
    expect(repaidFeeCollateralAmount).to.equal(toWei("0.1"))
    expect(unpaidDebtCollateralAmount).to.equal(toWei("0"))
    expect(unpaidFeeCollateralAmount).to.equal(toWei("0"))
  })
})
