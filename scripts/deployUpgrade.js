const { ethers, upgrades } = require("hardhat");
const fs = require("fs");

async function main() {
  const deploymentPath = `deployments/${hre.network.name}_CarbonCreditToken.json`;
  const { address } = JSON.parse(fs.readFileSync(deploymentPath, "utf8"));

  const CarbonCreditToken = await ethers.getContractFactory("CarbonCreditToken");

  console.log("Upgrading contract at:", address);
  const upgraded = await upgrades.upgradeProxy(address, CarbonCreditToken);
  console.log("Contract upgraded at:", upgraded.target || upgraded.address);
}

main().catch((error) => {
  console.error("Upgrade failed:", error);
  process.exitCode = 1;
});
