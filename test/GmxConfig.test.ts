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

describe("GmxConfig", () => {
    const wethAddress = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1" // Arb1 WETH
    const usdcAddress = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8" // Arb1 USDC

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
        return { weth, usdc, priceUpdater, gmxFastPriceFeed, gmxPositionRouter, gmxPositionManager, gmxOrderBook, gmxRouter, gmxVault, gmxReader, gmxVaultReader }
    }

    after(async () => {
        await network.provider.request({
            method: "hardhat_reset",
            params: [],
        })
    })

    const zBytes32 = "0x0000000000000000000000000000000000000000000000000000000000000000"
    const zAddress = "0x0000000000000000000000000000000000000000"

    const pad32r = (s: string) => {
        if (s.length > 66) {
            return s;
        } else if (s.startsWith('0x') || s.startsWith('0X')) {
            return s + "0".repeat(66 - s.length)
        } else {
            return s + "0".repeat(64 - s.length)
        }
    }


    it("configs", async () => {
        // recover snapshot
        const [_, trader1] = await ethers.getSigners()
        const { weth, usdc, priceUpdater, gmxFastPriceFeed, gmxPositionRouter, gmxOrderBook, gmxRouter, gmxVault } = await loadFixture(deployTokenFixture)

        const setGmxPrice = async (price: any) => {
            const blockTime = await getBlockTime()
            await gmxFastPriceFeed.connect(priceUpdater).setPricesWithBits(getPriceBits([price, price, price, price]), blockTime)
        }

        // give me some token
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
        await factory.setProjectAssetConfig(PROJECT_GMX, usdc.address, defaultAssetConfig());
        await factory.setProjectAssetConfig(PROJECT_GMX, weth.address, defaultAssetConfig());
        await factory.setBorrowConfig(PROJECT_GMX, usdc.address, 0, toWei("1000"))
        await factory.setBorrowConfig(PROJECT_GMX, weth.address, 1, toWei("1000"))
        await factory.upgradeTo(PROJECT_GMX, aggregator.address)
        await factory.setKeeper(priceUpdater.address, true);

        const expProxy0Address = await factory.getProxyAddress(PROJECT_GMX, trader1.address, weth.address, weth.address, true)
        await factory.connect(trader1).createProxy(PROJECT_GMX, weth.address, weth.address, true)
        const expProxy1Address = await factory.getProxyAddress(PROJECT_GMX, trader1.address, usdc.address, weth.address, true)
        await factory.connect(trader1).createProxy(PROJECT_GMX, usdc.address, weth.address, true)
        const [proxy0Address, proxy1Address] = await factory.getProxiesOf(trader1.address)
        expect(expProxy0Address).to.equal(proxy0Address)
        expect(expProxy1Address).to.equal(proxy1Address)

        const proxy0 = await ethers.getContractAt("TestGmxAdapter", proxy0Address)
        const proxy1 = await ethers.getContractAt("TestGmxAdapter", proxy1Address)

        const pc0 = await proxy0.getProjectConfigs()
        const pc1 = await proxy1.getProjectConfigs()
        expect(pc0).to.deep.equal(pc1)

        expect(pc0.vault).to.equal(VaultAddress)
        expect(pc0.positionRouter).to.equal(PositionRouterAddress)
        expect(pc0.orderBook).to.equal(OrderBookAddress)
        expect(pc0.router).to.equal(RouterAddress)
        expect(pc0.referralCode).to.equal(zBytes32)

        expect(pc0.marketOrderTimeoutSeconds).to.equal(120)
        expect(pc0.limitOrderTimeoutSeconds).to.equal(86400 * 2)
        expect(pc0.fundingAssetId).to.equal(1)

        await factory.setProjectConfig(PROJECT_GMX, [
            pad32r(VaultAddress),
            pad32r(PositionRouterAddress),
            pad32r(OrderBookAddress),
            pad32r(weth.address),
            ethers.utils.formatBytes32String("NewCode"),
            150,
            86400 * 3,
            2, // weth
        ])

        await proxy0.updateConfigs()
        const npc0 = await proxy0.getProjectConfigs()
        expect(npc0.vault).to.equal(VaultAddress)
        expect(npc0.positionRouter).to.equal(PositionRouterAddress)
        expect(npc0.orderBook).to.equal(OrderBookAddress)
        expect(npc0.router).to.equal(weth.address)
        expect(npc0.referralCode).to.equal(ethers.utils.formatBytes32String("NewCode"))

        expect(npc0.marketOrderTimeoutSeconds).to.equal(150)
        expect(npc0.limitOrderTimeoutSeconds).to.equal(86400 * 3)
        expect(npc0.fundingAssetId).to.equal(2)

        await proxy1.updateConfigs()
        const npc1 = await proxy0.getProjectConfigs()
        expect(npc1.vault).to.equal(VaultAddress)
        expect(npc1.positionRouter).to.equal(PositionRouterAddress)
        expect(npc1.orderBook).to.equal(OrderBookAddress)
        expect(npc1.router).to.equal(weth.address)
        expect(npc1.referralCode).to.equal(ethers.utils.formatBytes32String("NewCode"))

        expect(npc1.marketOrderTimeoutSeconds).to.equal(150)
        expect(npc1.limitOrderTimeoutSeconds).to.equal(86400 * 3)
        expect(npc1.fundingAssetId).to.equal(2)

        const ac0 = await proxy0.getTokenConfigs()
        expect(ac0.boostFeeRate).to.equal(toUnit("0.005", 5))
        expect(ac0.initialMarginRate).to.equal(toUnit("0.006", 5))
        expect(ac0.maintenanceMarginRate).to.equal(toUnit("0.005", 5))
        expect(ac0.liquidationFeeRate).to.equal(toUnit("0.002", 5))
        expect(ac0.referrenceOracle).to.equal(zAddress)
        expect(ac0.referenceDeviation).to.equal(toUnit("0.001", 5))

        await factory.setProjectAssetConfig(PROJECT_GMX, weth.address, [
            toUnit("0.01", 5),
            toUnit("0.03", 5),
            toUnit("0.05", 5),
            toUnit("0.07", 5),
            pad32r(weth.address),
            toUnit("0.09", 5),
        ]);
        await proxy0.updateConfigs()
        const nac0 = await proxy0.getTokenConfigs()
        expect(nac0.boostFeeRate).to.equal(toUnit("0.01", 5))
        expect(nac0.initialMarginRate).to.equal(toUnit("0.03", 5))
        expect(nac0.maintenanceMarginRate).to.equal(toUnit("0.05", 5))
        expect(nac0.liquidationFeeRate).to.equal(toUnit("0.07", 5))
        expect(nac0.referrenceOracle).to.equal(weth.address)
        expect(nac0.referenceDeviation).to.equal(toUnit("0.09", 5))

        await factory.setProjectAssetConfig(PROJECT_GMX, usdc.address, [
            toUnit("0.02", 5),
            toUnit("0.04", 5),
            toUnit("0.06", 5),
            toUnit("0.08", 5),
            0,
            toUnit("0.10", 5),
        ]);
        await proxy1.updateConfigs()
        const nac1 = await proxy1.getTokenConfigs()
        expect(nac1.boostFeeRate).to.equal(toUnit("0.02", 5))
        expect(nac1.initialMarginRate).to.equal(toUnit("0.04", 5))
        expect(nac1.maintenanceMarginRate).to.equal(toUnit("0.06", 5))
        expect(nac1.liquidationFeeRate).to.equal(toUnit("0.08", 5))
        expect(nac1.referrenceOracle).to.equal(zAddress)
        expect(nac1.referenceDeviation).to.equal(toUnit("0.10", 5))
    })

    const zeroBytes32 = "0x0000000000000000000000000000000000000000000000000000000000000000"

    it("change position router", async () => {
        // recover snapshot
        const [_, trader1] = await ethers.getSigners()
        const { weth, usdc, priceUpdater, gmxFastPriceFeed, gmxPositionRouter, gmxOrderBook, gmxRouter, gmxVault } = await loadFixture(deployTokenFixture)

        const setGmxPrice = async (price: any) => {
            const blockTime = await getBlockTime()
            await gmxFastPriceFeed.connect(priceUpdater).setPricesWithBits(getPriceBits([price, price, price, price]), blockTime)
        }

        // give me some token
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
        const executionFee = await gmxPositionRouter.minExecutionFee()


        const libGmx = await createContract("LibGmx")
        const aggregator = await createContract("TestGmxAdapter", [wethAddress], { LibGmx: libGmx })
        const factory = await createContract("ProxyFactory")
        await factory.initialize(weth.address, liquidityPool.address)
        await factory.setProjectConfig(PROJECT_GMX, defaultProjectConfig)
        await factory.setProjectAssetConfig(PROJECT_GMX, usdc.address, defaultAssetConfig());
        await factory.setProjectAssetConfig(PROJECT_GMX, weth.address, defaultAssetConfig());
        await factory.setBorrowConfig(PROJECT_GMX, usdc.address, 0, toWei("1000"))
        await factory.setBorrowConfig(PROJECT_GMX, weth.address, 1, toWei("1000"))
        await factory.upgradeTo(PROJECT_GMX, aggregator.address)
        await factory.setKeeper(priceUpdater.address, true);

        await weth.connect(trader1).approve(factory.address, toWei("10000"))
        await usdc.connect(trader1).approve(factory.address, toWei("10000"))

        await setGmxPrice("1295.9")
        await factory.connect(trader1).openPosition(
            {
                projectId: 1,
                collateralToken: weth.address,
                assetToken: weth.address,
                isLong: true,
                tokenIn: weth.address,
                amountIn: toWei("0.011117352"), // 1
                minOut: toWei("0.011117352"),
                borrow: toWei("0.023333333333333334"),
                sizeUsd: toWei("1296.5"),
                priceUsd: toWei("1296.5"),
                flags: 0x40,
                referralCode: zeroBytes32,
            },
            { value: executionFee.add(toWei("0.011117352")) }
        )
        const [_proxy] = await factory.getProxiesOf(trader1.address)
        const proxy = await ethers.getContractAt("TestGmxAdapter", _proxy)

        var keys = await proxy.getPendingGmxOrderKeys()
        expect(keys.length).to.equal(1)

        await factory.setProjectConfig(
            PROJECT_GMX,
            [
                pad32r(VaultAddress),
                pad32r(zAddress), // <-- changed
                pad32r(OrderBookAddress),
                pad32r(RouterAddress),
                ethers.utils.formatBytes32String(""),
                120,
                86400 * 2,
                1, // weth
            ])

        await proxy.updateConfigs()
        var keys = await proxy.getPendingGmxOrderKeys()
        expect(keys.length).to.equal(0)
    })
})
