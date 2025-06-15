import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomiclabs/hardhat-ethers";
import "hardhat-deploy";
require('@openzeppelin/hardhat-upgrades');
import dotenv from "dotenv"; 
dotenv.config();

// For WSL2 users, you may need to set a proxy agent to connect to the internet
import { ProxyAgent, setGlobalDispatcher } from 'undici';
const proxyAgent = new ProxyAgent("http://172.29.32.1:55315"); // replace ip with cat /etc/resolv.conf | grep nameserver
setGlobalDispatcher(proxyAgent);

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.26",
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
  },
  networks: {
    // coredao_mainnet: {
    //   //@ts-ignore
    //   accounts: [process.env.PRIVATE_KEY],
    //   url: "https://rpc.coredao.org",
    // },
    // coredao_testnet: {
    //   //@ts-ignore
    //   accounts: [process.env.PRIVATE_KEY],
    //   url: "https://rpc.test.btcs.network",
    // },
    // kakarot_testnet: {
    //   //@ts-ignore
    //   accounts: [process.env.PRIVATE_KEY],
    //   url: "https://sepolia-rpc.kakarot.org",
    // },
    // mode_mainnet: {
    //   //@ts-ignore
    //   accounts: [process.env.PRIVATE_KEY],
    //   url: "https://mainnet.mode.network",
    // },
    // polygon_mumbai: {
    //   //@ts-ignore
    //   accounts: [process.env.PRIVATE_KEY],
    //   url: "https://polygon-mumbai.g.alchemy.com/v2/CcIjayR-uykEFwpAt7sdfBM3swhISWXE",
    // },
    // zetachain_mainnet: {
    //   //@ts-ignore
    //   accounts: [process.env.PRIVATE_KEY],
    //   url: "https://zetachain-evm.blockpi.network:443/v1/rpc/public",
    // },
    zetachain_testnet: {
      chainId: 7001,
      accounts: [process.env.PRIVATE_KEY ?? ""],
      url: "https://zetachain-athens-evm.blockpi.network/v1/rpc/public",
      deploy: ["./deploy/zetachain_testnet/"],
    },
    sepolia: {
      chainId: 11155111,
      accounts: [process.env.PRIVATE_KEY ?? ""],
      url: "https://sepolia.drpc.org",
      deploy: ["./deploy/sepolia/"],
    },
    arb_sepolia: {
      chainId: 421614,
      accounts: [process.env.PRIVATE_KEY ?? ""],
      url: "https://arbitrum-sepolia.drpc.org",
      deploy: ["./deploy/arb_sepolia/"],
    },
    // zircuit_testnet: {
    //   //@ts-ignore
    //   accounts: [process.env.PRIVATE_KEY],
    //   url: "https://zircuit1.p2pify.com",
    // },
    // zklink_mainnet: {
    //   //@ts-ignore
    //   accounts: [process.env.PRIVATE_KEY],
    //   url: "https://rpc.zklink.io",
    // },
  },
  etherscan: {
    apiKey: {
      sepolia: "VV6FB3HDE9FSVBBVMVXGPQX4KSJUJIY3E6",
      arb_sepolia: "8TDWU29I4QA8AW713FK2Y29QABP5AF9FXX",
      zetachain_testnet: "6542100",
    },
    customChains: [
      {
        network: "sepolia",
        chainId: 11155111,
        urls: {
          apiURL: "https://api-sepolia.etherscan.io/api",
          browserURL: "https://sepolia.etherscan.io/",
        },
      },
      {
        network: "arb_sepolia",
        chainId: 421614,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://sepolia.arbiscan.io/",
        },
      },
      {
        network: "zetachain_testnet",
        chainId: 7001,
        urls: {
          apiURL: "https://zetachain-testnet.blockscout.com/api",
          browserURL: "https://zetachain-testnet.blockscout.com",
        },
      },
    ]
  },
};

export default config;
