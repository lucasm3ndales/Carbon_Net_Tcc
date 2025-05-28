// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CarbonCreditToken is Initializable, ERC1155Upgradeable, OwnableUpgradeable {
    using Strings for uint256;

    enum CarbonCreditStatus {
        PENDING_ISSUANCE,
        ISSUED,
        AVAILABLE,
        TRANSFERRED,
        RETIRED,
        CANCELLED
    }

    enum CarbonProjectStatus {
        PLANNED,
        ACTIVE,
        CERTIFIED,
        SUSPENDED,
        COMPLETED,
        EXPIRED,
        CANCELLED
    }

    enum CarbonProjectType {
        REFORESTATION,
        FOREST_CONSERVATION,
        RENEWABLE_ENERGY,
        ENERGY_EFFICIENCY,
        WASTE_MANAGEMENT,
        CARBON_CAPTURE_AND_STORAGE,
        AGRICULTURE,
        OTHER
    }

    struct CarbonCreditTokenData {
        string creditCode;
        uint256 vintageYear;
        uint256 tonCO2Quantity;
        CarbonCreditStatus status;
        string ownerName;
        string ownerDocument;
        uint256 createdAt;
        uint256 updatedAt;
        string projectCode;
        string projectName;
        string projectLocation;
        string projectDeveloper;
        uint256 projectCreatedAt;
        uint256 projectUpdatedAt;
        CarbonProjectType projectType;
        CarbonProjectStatus projectStatus;
    }

    mapping(uint256 => CarbonCreditTokenData) private _metadata;
    mapping(string => bool) private _existingCreditCodes;
    uint256[] private _allTokenIds;

    event CarbonCreditMinted(uint256 indexed tokenId, address indexed to);
    event CarbonCreditBatchMinted(uint256[] tokenIds, address indexed to);
    event CarbonCreditUpdated(uint256 indexed tokenId);
    event CarbonCreditBatchUpdated(uint256[] tokenIds);

    function initialize(string memory baseURI, address initialOwner) public initializer {
        require(bytes(baseURI).length > 0, "Base URI cannot be empty");
        require(initialOwner != address(0), "Owner address cannot be zero");
        __ERC1155_init(baseURI);
        __Ownable_init(initialOwner);
    }

    function mintCarbonCredit(address to, CarbonCreditTokenData memory data) public onlyOwner {
        require(!_existingCreditCodes[data.creditCode], "Credit code already exists");
        require(data.tonCO2Quantity > 0, "CO2 quantity must be > 0");

        uint256 tokenId = uint256(keccak256(abi.encodePacked(data.creditCode)));

        data.createdAt = block.timestamp;
        data.updatedAt = block.timestamp;

        _metadata[tokenId] = data;
        _existingCreditCodes[data.creditCode] = true;
        _allTokenIds.push(tokenId);

        _mint(to, tokenId, 1, "");

        emit CarbonCreditMinted(tokenId, to);
    }

    function batchMintCarbonCredits(address to, CarbonCreditTokenData[] memory dataList) public onlyOwner {
        uint256[] memory tokenIds = new uint256[](dataList.length);

        for (uint256 i = 0; i < dataList.length; i++) {
            CarbonCreditTokenData memory data = dataList[i];
            require(!_existingCreditCodes[data.creditCode], "Duplicate creditCode in batch");
            require(data.tonCO2Quantity > 0, "CO2 quantity must be > 0");

            uint256 tokenId = uint256(keccak256(abi.encodePacked(data.creditCode)));

            data.createdAt = block.timestamp;
            data.updatedAt = block.timestamp;

            _metadata[tokenId] = data;
            _existingCreditCodes[data.creditCode] = true;
            _allTokenIds.push(tokenId);

            _mint(to, tokenId, 1, "");
            tokenIds[i] = tokenId;
        }

        emit CarbonCreditBatchMinted(tokenIds, to);
    }

    function getCarbonCredit(uint256 tokenId) external view returns (CarbonCreditTokenData memory) {
        require(bytes(_metadata[tokenId].creditCode).length > 0, "Token does not exist");
        return _metadata[tokenId];
    }

    function getAllTokenIds() external view returns (uint256[] memory) {
        return _allTokenIds;
    }

    function updateCarbonCredit(uint256 tokenId, CarbonCreditTokenData memory newData) public onlyOwner {
        require(bytes(_metadata[tokenId].creditCode).length > 0, "Token does not exist");

        newData.updatedAt = block.timestamp;
        newData.createdAt = _metadata[tokenId].createdAt; 
        _metadata[tokenId] = newData;

        emit CarbonCreditUpdated(tokenId);
    }

    function batchUpdateCarbonCredits(uint256[] calldata tokenIds, CarbonCreditTokenData[] calldata newDataList) public onlyOwner {
        require(tokenIds.length == newDataList.length, "Mismatched input lengths");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(bytes(_metadata[tokenId].creditCode).length > 0, "Token does not exist");

            CarbonCreditTokenData memory newData = newDataList[i];
            newData.updatedAt = block.timestamp;
            newData.createdAt = _metadata[tokenId].createdAt;

            _metadata[tokenId] = newData;
        }

        emit CarbonCreditBatchUpdated(tokenIds);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(tokenId), tokenId.toString(), ".json"));
    }
}
