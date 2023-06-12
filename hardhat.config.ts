import { task } from "hardhat/config"
import "@typechain/hardhat"
import "@nomiclabs/hardhat-ethers"
import "@nomiclabs/hardhat-waffle"
import "@nomiclabs/hardhat-etherscan"
import "solidity-coverage"
import { Deployer } from "./scripts/deployer/deployer"
import { retrieveLinkReferences } from "./scripts/deployer/linkReferenceParser"

task("deploy", "Deploy a single contract")
  .addPositionalParam("name", "Name of contract to deploy")
  .addOptionalPositionalParam("args", "Args of contract constructor, separated by common ','")
  .setAction(async (args, hre) => {
    if (typeof args.args != "undefined") {
      args.args = args.args.split(",")
    }
    let nonce = await hre.ethers.provider.getTransactionCount(await hre.ethers.provider.getSigner(0).getAddress(), "pending")
    console.log("nonce", nonce)
    const linkReferences = await retrieveLinkReferences("./artifacts/contracts")
    const links: { [contactName: string]: string } = {}
    const go = async (contractName: string) => {
      const innerLinks: { [contactName: string]: string } = {}
      for (let linkedContractName of linkReferences[contractName] || []) {
        if (linkedContractName in links) {
          innerLinks[linkedContractName] = links[linkedContractName]
        } else {
          const deployed = await go(linkedContractName)
          innerLinks[linkedContractName] = deployed
          links[linkedContractName] = deployed
        }
      }
      const factory = await hre.ethers.getContractFactory(contractName, { libraries: innerLinks })
      const constructArgs = args.args ? args.args : []
      console.log("deploying", contractName, "links:", innerLinks, "ctor:", constructArgs, "nonce:", nonce)
      constructArgs.push({ nonce: nonce++ })
      const deployed = await factory.deploy(...constructArgs)
      console.log(contractName, "deployed at", deployed.address)
      await deployed.deployTransaction.wait()
      return deployed.address
    }
    await go(args.name)
  })

task("upgrade", "Upgrade a single contract")
  .addPositionalParam("contractName", "Implementation contract name")
  .addOptionalPositionalParam("aliasName", "Alias name of Proxy, optional")
  .addOptionalPositionalParam("imp", "Address of deployed implementation, optional")
  .setAction(async (args, hre) => {
    const deployer = new Deployer(hre.ethers, {
      network: hre.network.name,
      artifactDirectory: "./artifacts/contracts",
      addressOverride: {},
    })
    await deployer.initialize()
    if (typeof args.aliasName === "undefined") {
      args.aliasName = args.contractName
    }
    const proxyAdmin = deployer.addressOf("ProxyAdmin")
    try {
      await deployer.upgrade(args.contractName, args.aliasName, proxyAdmin, args.imp)
    } finally {
      deployer.finalize()
    }
  })

task("upgradeGmx", "Upgrade GmxAdapter")
  .addOptionalPositionalParam("imp", "Address of deployed implementation, optional")
  .setAction(async (args, hre) => {
    const deployer = new Deployer(hre.ethers, {
      network: hre.network.name,
      artifactDirectory: "./artifacts/contracts",
      addressOverride: {},
    })
    await deployer.initialize()
    let factory = await deployer.getDeployedContract("ProxyFactory", "ProxyFactory")
    try {
      let aggregator = { address: "" }
      if (args.imp) {
        aggregator.address = args.imp
      } else {
        aggregator = await deployer.deploy("GmxAdapter", "GmxAdapter", "0x82aF49447D8a07e3bd95BD0d56f35241523fBab1")
      }
      console.log(`set GmxAdapter imp to ${aggregator.address}`)
      const tx = await factory.upgradeTo(1, aggregator.address)
      const receipt = await tx.wait()
      if (receipt.status !== 1) {
        throw new Error(`tx failed. hash: ${tx.hash}`)
      }
    } finally {
      deployer.finalize()
    }
  })

task("send", "Send contract function transaction")
  .addPositionalParam("contractName", "Implementation contract name")
  .addPositionalParam("aliasName", "Alias name of Proxy, optional")
  .addPositionalParam("method", "Method name of Proxy, optional")
  .addOptionalPositionalParam("args", "Args of function call, separated by common ','")
  .setAction(async (args, hre) => {
    if (typeof args.args != "undefined") {
      args.args = args.args.split(",")
    } else {
      args.args = []
    }
    if (typeof args.aliasName === "undefined") {
      args.aliasName = args.contractName
    }
    const deployer = new Deployer(hre.ethers, {
      network: hre.network.name,
      artifactDirectory: "./artifacts/contracts",
      addressOverride: {},
    })
    await deployer.initialize()
    const callee = await deployer.getDeployedContract(args.contractName, args.aliasName)
    var result = await callee.functions[args.method](...args.args)
    console.log(result)
  })

task("call", "Call contract function")
  .addPositionalParam("contractName", "Implementation contract name")
  .addPositionalParam("aliasName", "Alias name of Proxy, optional")
  .addPositionalParam("method", "Method name of Proxy, optional")
  .addOptionalPositionalParam("args", "Args of function call, separated by common ','")
  .setAction(async (args, hre) => {
    if (typeof args.args != "undefined") {
      args.args = args.args.split(",")
    } else {
      args.args = []
    }
    if (typeof args.aliasName === "undefined") {
      args.aliasName = args.contractName
    }
    const deployer = new Deployer(hre.ethers, {
      network: hre.network.name,
      artifactDirectory: "./artifacts/contracts",
      addressOverride: {},
    })
    await deployer.initialize()
    const callee = await deployer.getDeployedContract(args.contractName, args.aliasName)
    console.log("calling %s(%s).%s(%s)", args.aliasName, callee.address, args.method, ...args.args)
    var result = await callee.callStatic[args.method](...args.args)
    console.log(result)
  })

task("toBytes32", "Convert string to bytes32")
  .addPositionalParam("text", "Implementation contract name")
  .setAction(async (args, hre) => {
    console.log(hre.ethers.utils.formatBytes32String(args.text))
  })

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  etherscan: {
  },
  mocha: {
    timeout: 3600000,
  },
  gasReporter: {
    currency: "ETH",
    gasPrice: 100,
  },
  typechain: {
    outDir: "typechain",
    target: "./misc/typechain-ethers-v5-mux",
  },
}
