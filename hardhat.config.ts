import "@nomiclabs/hardhat-waffle";
import "@nomicfoundation/hardhat-toolbox";
import { HardhatUserConfig } from "hardhat/config";

const config: HardhatUserConfig = {
  solidity: "0.8.9",
  networks: {
    sepolia: {
      url: "https://ethereum-sepolia-rpc.allthatnode.com/CmkQu3zpCPWJYSkU41aF9NuRwOpLXuA9",
      accounts: ["ea6332a256548623f504c3faaaa7a094a57000f89c4ca909747ed1f084a1782d"]
    }
  },
  etherscan: {
    apiKey: "BCUNR29266X9YKHC4QBVUUKPWSZXU6FJ8J"
  }
};

export default config;
