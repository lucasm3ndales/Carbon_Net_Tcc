require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");

module.exports = {
  solidity: "0.8.28",
  networks: {
    carbonNet: {
      url: "http://127.0.0.1:8545",
      chainId: 1337,
      accounts: [
        "0x8f2a55949038a9610f50fb23b5883af3b4ecb3c3bb792cbcefbd1542c692be63",
        "0xc87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3",
        "0xae6ae8e5ccbfb04590405997ee2d52d2b330726137b875053c36d94e974d162f",
        "0x7138cea045f2ded1940a1208331d2fb2fbff298ff272e74c78eae7c21a9c25ac",	
      ],
    },
  },
};
