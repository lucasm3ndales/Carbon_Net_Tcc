const hre = require("hardhat");
const fs = require("fs");
const { upgrades } = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  const baseURI = "https://127.0.0.1/carbon-credits/metadata/";
  const initialOwner = deployer.address;

  const CarbonCreditToken = await hre.ethers.getContractFactory("CarbonCreditToken");

  const contract = await upgrades.deployProxy(CarbonCreditToken, [baseURI, initialOwner], {
    initializer: "initialize",
  });

  console.log("Aguardando confirmação de deploy...");
  await contract.waitForDeployment();

  const address = await contract.getAddress();
  console.log("Contract (proxy) deployed to:", address);

  const deploymentInfo = {
    contract: "CarbonCreditToken",
    address,
    network: hre.network.name,
    baseURI,
  };

  if (!fs.existsSync("deployments")) {
    fs.mkdirSync("deployments");
  }

  fs.writeFileSync(
    `deployments/${hre.network.name}_CarbonCreditToken.json`,
    JSON.stringify(deploymentInfo, null, 2)
  );

  console.log("Informações de deploy salvas em:", `deployments/${hre.network.name}_CarbonCreditToken.json`);
}

main().catch((error) => {
  console.error("Erro no deploy:", error);
  process.exitCode = 1;
});



