import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(
    "Deploying contracts with account:",
    deployer.address
  );

  const Factory = await ethers.getContractFactory("Factory");
  const contract = await Factory.deploy();

  const HYToken = await ethers.getContractFactory("Token");
  const contract2 = await HYToken.deploy("HYToken", "HY", 1000);

  const exchange = await ethers.getContractFactory("Exchange");
  const contract3 = await exchange.deploy(contract2.address);


  console.log("Contract deployed at:" , contract.address);
  console.log("Contract2 deployed at:" , contract2.address);
  console.log("Contract3 deployed at:" , contract3.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});