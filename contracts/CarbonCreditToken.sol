// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CarbonCreditToken is Initializable, ERC1155Upgradeable, OwnableUpgradeable {
    uint256 private _tokenIds;

    struct CarbonCreditMetadata {
        string creditCode;
        uint256 vintageYear;
        uint256 tonCO2Quantity;
        string status;
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
        string projectType;
        string projectStatus;
    }

    mapping(uint256 => CarbonCreditMetadata) private _tokenMetadata;
    mapping(string => bool) private _existingCreditCodes;

    event CarbonCreditMintedWithMessage(
        uint256 indexed tokenId,
        address indexed to,
        string message
    );

    event MetadataUpdated(
        uint256 indexed tokenId,
        string newOwnerName,
        string newOwnerDocument
    );

    function initialize(string memory baseURI, address initialOwner) public initializer {
        require(bytes(baseURI).length > 0, "BaseURI nao pode ser vazio");
        require(initialOwner != address(0), "Endereco do proprietario nao pode ser o endereco zero");
        __ERC1155_init(baseURI);
        __Ownable_init(initialOwner);
    }

    function mintCarbonCredit(
        address to,
        CarbonCreditMetadata memory data,
        string memory message
    ) external onlyOwner returns (uint256) {
        require(!_existingCreditCodes[data.creditCode], "CreditCode already tokenized");
        require(data.tonCO2Quantity > 0, "Quantidade deve ser > 0");
        require(data.vintageYear <= block.timestamp, "Ano invalido");
        require(bytes(data.ownerName).length > 0, "Nome do dono obrigatorio");

        _tokenIds += 1;
        uint256 tokenId = _tokenIds;

        data.createdAt = block.timestamp;
        data.updatedAt = block.timestamp;

        _tokenMetadata[tokenId] = data;
        _existingCreditCodes[data.creditCode] = true;
        _mint(to, tokenId, 1, "");

        emit CarbonCreditMintedWithMessage(tokenId, to, message);
        return tokenId;
    }

    function updateOwnerInfo(
        uint256 tokenId,
        string memory newOwnerName,
        string memory newOwnerDocument
    ) external {
        require(balanceOf(msg.sender, tokenId) > 0, "Nao eh dono do token");
        require(bytes(newOwnerName).length > 0, "Nome invalido");

        CarbonCreditMetadata storage metadata = _tokenMetadata[tokenId];
        metadata.ownerName = newOwnerName;
        metadata.ownerDocument = newOwnerDocument;
        metadata.updatedAt = block.timestamp;

        emit MetadataUpdated(tokenId, newOwnerName, newOwnerDocument);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(
            abi.encodePacked(super.uri(tokenId), Strings.toString(tokenId), ".json")
        );
    }

    function getMetadata(uint256 tokenId) external view returns (CarbonCreditMetadata memory) {
        return _tokenMetadata[tokenId];
    }
}
