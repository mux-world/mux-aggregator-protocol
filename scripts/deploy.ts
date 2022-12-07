import hre, { ethers } from "hardhat"
import { Deployer, DeploymentOptions } from "./deployer/deployer"
import { restorableEnviron } from "./deployer/environ"
import {
    toWei,
    PositionRouterAddress,
    OrderBookAddress,
    RouterAddress,
    VaultAddress,
    PositionManagerAddress,
    USDGAddress,
    toUnit
} from "./deployUtils"

const ENV: DeploymentOptions = {
    network: hre.network.name,
    artifactDirectory: "./artifacts/contracts",
    addressOverride: {},
}

const zeroBytes32 = "0x0000000000000000000000000000000000000000000000000000000000000000"
const padding = "00000000000000000000000000000000000000000000000000000000"

const pad32r = (s: string) => {
    if (s.length > 66) {
        return s
    } else if (s.startsWith("0x") || s.startsWith("0X")) {
        return s + "0".repeat(66 - s.length)
    } else {
        return s + "0".repeat(64 - s.length)
    }
}

async function deploy(deployer: Deployer) {
    const factoryImplementation = await deployer.deployOrSkip("ProxyFactory", "ProxyFactory")
}

async function init(deployer: Deployer) {
    const usdcAddress = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8"
    const usdtAddress = "0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9"
    const daiAddress = "0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1"
    const wethAddress = "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1"
    const wbtcAddress = "0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f"
    const uniAddress = "0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0"
    const linkAddress = "0xf97f4df75117a78c1A5a0DBb814Af92458539FB4"

    const liquidityPoolAddress = "0x3e0199792Ce69DC29A0a36146bFa68bd7C8D6633"

    const proxyAdminAddress = "0x73c5955dbB7a667e05da5fE7b8798c0fd4cE8E16" // hardwallet, temp
    // const factory = await deployer.deployUpgradeableOrSkip("ProxyFactory", "ProxyFactory", proxyAdminAddress)
    const factory = await deployer.getDeployedContract("ProxyFactory", "ProxyFactory")

    const aggregatorImp = await deployer.deployOrSkip("GmxAdapter", "GmxAdapter", wethAddress)
    const reader = await deployer.deployOrSkip("Reader", "Reader", factory.address, VaultAddress, wethAddress, USDGAddress)

    const PROJECT_GMX = 1

    console.log("init factory")
    await factory.initialize(wethAddress, liquidityPoolAddress)

    console.log("set imp")
    await factory.upgradeTo(PROJECT_GMX, aggregatorImp.address)

    console.log("set project")
    await factory.setProjectConfig(PROJECT_GMX, [
        pad32r(VaultAddress),
        pad32r(PositionRouterAddress),
        pad32r(OrderBookAddress),
        pad32r(RouterAddress),
        ethers.utils.formatBytes32String(""),
        120,
        86400 * 2,
        3, // weth
    ])

    console.log("set assets")
    await factory.setProjectAssetConfig(
        PROJECT_GMX,
        usdcAddress,
        [toUnit("0.02", 5), toUnit("0.006", 5), toUnit("0.005", 5), toUnit("0.00", 5), 0, toUnit("0.001", 5)]
    );
    await factory.setProjectAssetConfig(
        PROJECT_GMX,
        usdtAddress,
        [toUnit("0.02", 5), toUnit("0.006", 5), toUnit("0.005", 5), toUnit("0.00", 5), 0, toUnit("0.001", 5)]
    );
    await factory.setProjectAssetConfig(
        PROJECT_GMX,
        daiAddress,
        [toUnit("0.02", 5), toUnit("0.006", 5), toUnit("0.005", 5), toUnit("0.00", 5), 0, toUnit("0.001", 5)]
    );
    await factory.setProjectAssetConfig(
        PROJECT_GMX,
        wethAddress,
        [toUnit("0.02", 5), toUnit("0.006", 5), toUnit("0.005", 5), toUnit("0.00", 5), 0, toUnit("0.001", 5)]
    );
    await factory.setProjectAssetConfig(
        PROJECT_GMX,
        wbtcAddress,
        [toUnit("0.02", 5), toUnit("0.006", 5), toUnit("0.005", 5), toUnit("0.00", 5), 0, toUnit("0.001", 5)]
    );
    await factory.setProjectAssetConfig(
        PROJECT_GMX,
        uniAddress,
        [toUnit("0.02", 5), toUnit("0.006", 5), toUnit("0.005", 5), toUnit("0.00", 5), 0, toUnit("0.001", 5)]
    );
    await factory.setProjectAssetConfig(
        PROJECT_GMX,
        linkAddress,
        [toUnit("0.02", 5), toUnit("0.006", 5), toUnit("0.005", 5), toUnit("0.00", 5), 0, toUnit("0.001", 5)]
    );

    await factory.setBorrowConfig(PROJECT_GMX, usdcAddress, 0, toUnit("100000", 6))
    await factory.setBorrowConfig(PROJECT_GMX, usdtAddress, 1, toUnit("100000", 6))
    await factory.setBorrowConfig(PROJECT_GMX, wethAddress, 3, toWei("85"))
    await factory.setBorrowConfig(PROJECT_GMX, wbtcAddress, 4, toUnit("4", 8))

    await factory.setBorrowConfig(PROJECT_GMX, daiAddress, 2, toWei("0"))
    await factory.setBorrowConfig(PROJECT_GMX, uniAddress, 255, toWei("0"))
    await factory.setBorrowConfig(PROJECT_GMX, linkAddress, 255, toWei("0"))
}


async function main(deployer: Deployer) {
    // await deploy(deployer)
    await init(deployer)
}

restorableEnviron(ENV, main)
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
