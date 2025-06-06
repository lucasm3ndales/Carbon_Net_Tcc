require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");

module.exports = {
  solidity: "0.8.28",
  networks: {
    carbonNet: {
      url: "http://127.0.0.1:8545",
      chainId: 1337,
      accounts: [
        "0xc87509a1c067bbde78beb793e6fa76530b6382a4c0241e5e4a9ec0a0f44dc0d3"
      ],
    },
  },
};
