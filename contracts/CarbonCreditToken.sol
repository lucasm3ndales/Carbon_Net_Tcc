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
    }

    mapping(uint256 => CarbonCreditTokenData) private _tokenMetadata;

    event CarbonCreditUpdates(address operator, string func, uint256[] tokenIds, string[] creditCodes);

    function initialize(string memory baseURI, address initialOwner) public initializer {
        require(bytes(baseURI).length > 0, "Base URI empty");
        require(initialOwner != address(0), "Owner zero");
        __ERC1155_init(baseURI);
        __Ownable_init(initialOwner);
    }

    function _validStatusForUpdate(CarbonCreditStatus status) internal pure returns (bool) {
        return status != CarbonCreditStatus.RETIRED &&
               status != CarbonCreditStatus.CANCELLED &&
               status != CarbonCreditStatus.PENDING_ISSUANCE;
    }

    function batchMintCarbonCredits(address to, CarbonCreditTokenData[] calldata credits) external onlyOwner returns (bool, string memory) {
        require(credits.length > 0, "No credits");

        uint256[] memory ids = new uint256[](credits.length);
        uint256[] memory values = new uint256[](credits.length);

        for (uint256 i = 0; i < credits.length; i++) {
            CarbonCreditTokenData calldata data = credits[i];
            require(bytes(data.creditCode).length > 0, "Credit code required");
            require(data.tonCO2Quantity > 0, "CO2 qty > 0");

            uint256 tokenId = uint256(keccak256(abi.encodePacked(data.creditCode)));
            CarbonCreditTokenData storage existing = _tokenMetadata[tokenId];

            if (bytes(existing.creditCode).length == 0) {
                CarbonCreditTokenData memory newData = data;
                newData.createdAt = block.timestamp;
                newData.updatedAt = block.timestamp;
                _tokenMetadata[tokenId] = newData;
                _mint(to, tokenId, 1, "");
            } else {
                require(_validStatusForUpdate(existing.status), "Invalid status");
                existing.vintageYear = data.vintageYear;
                existing.tonCO2Quantity = data.tonCO2Quantity;
                existing.status = data.status;
                existing.ownerName = data.ownerName;
                existing.ownerDocument = data.ownerDocument;
                existing.updatedAt = block.timestamp;
                existing.projectCode = data.projectCode;
            }
            ids[i] = tokenId;
            values[i] = 1;
        }

        emit TransferBatch(msg.sender, address(0), to, ids, values);
        return (true, "Batch processed");
    }

    function getCarbonCredit(string calldata creditCode) external view returns (CarbonCreditTokenData memory) {
        uint256 tokenId = uint256(keccak256(abi.encodePacked(creditCode)));
        require(bytes(_tokenMetadata[tokenId].creditCode).length > 0, "Token not exist");
        return _tokenMetadata[tokenId];
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(tokenId), Strings.toHexString(tokenId, 32), ".json"));
    }

    function _batchUpdateStatus(string[] calldata creditCodes, CarbonCreditStatus newStatus, string memory funcName) internal returns (bool, string memory) {
        require(creditCodes.length > 0, "No credits");

        uint256[] memory ids = new uint256[](creditCodes.length);
        uint256[] memory values = new uint256[](creditCodes.length);

        for (uint256 i = 0; i < creditCodes.length; i++) {
            uint256 tokenId = uint256(keccak256(abi.encodePacked(creditCodes[i])));
            CarbonCreditTokenData storage data = _tokenMetadata[tokenId];
            require(bytes(data.creditCode).length > 0, "Token not exist");

            if (_validStatusForUpdate(data.status)) {
                data.status = newStatus;
                data.updatedAt = block.timestamp;
                ids[i] = tokenId;
                values[i] = 1;
            }
        }

        emit TransferBatch(msg.sender, address(0), address(0), ids, values);
        emit CarbonCreditUpdates(msg.sender, funcName, ids, creditCodes);
        return (true, "Batch status updated");
    }

    function batchTransferCarbonCredits(address from, address to, string[] calldata creditCodes) external onlyOwner returns (bool, string memory) {
        require(to != address(0), "Invalid recipient");
        require(creditCodes.length > 0, "No credits");
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "Not owner/approved");

        uint256[] memory ids = new uint256[](creditCodes.length);
        uint256[] memory values = new uint256[](creditCodes.length);

        for (uint256 i = 0; i < creditCodes.length; i++) {
            uint256 tokenId = uint256(keccak256(abi.encodePacked(creditCodes[i])));
            CarbonCreditTokenData storage data = _tokenMetadata[tokenId];
            require(bytes(data.creditCode).length > 0, "Token not exist");
            require(balanceOf(from, tokenId) > 0, "Sender no token");
            require(_validStatusForUpdate(data.status), "Invalid status");

            _safeTransferFrom(from, to, tokenId, 1, "");
            data.status = CarbonCreditStatus.TRANSFERRED;
            data.updatedAt = block.timestamp;

            ids[i] = tokenId;
            values[i] = 1;
        }

        emit TransferBatch(msg.sender, from, to, ids, values);
        emit CarbonCreditUpdates(msg.sender, "batchTransferCarbonCredits", ids, creditCodes);
        return (true, "Batch transfer done");
    }

    function batchRetireCarbonCredits(string[] calldata creditCodes) external onlyOwner returns (bool, string memory) {
        return _batchUpdateStatus(creditCodes, CarbonCreditStatus.RETIRED, "batchRetireCarbonCredits");
    }

    function batchAvailableCarbonCredits(string[] calldata creditCodes) external onlyOwner returns (bool, string memory) {
        return _batchUpdateStatus(creditCodes, CarbonCreditStatus.AVAILABLE, "batchAvailableCarbonCredits");
    }

    function batchCancelCarbonCredits(string[] calldata creditCodes) external onlyOwner returns (bool, string memory) {
        return _batchUpdateStatus(creditCodes, CarbonCreditStatus.CANCELLED, "batchCancelCarbonCredits");
    }

    function batchGetCarbonCredits(string[] calldata creditCodes) external view returns (CarbonCreditTokenData[] memory) {
        require(creditCodes.length > 0, "No credits");
        CarbonCreditTokenData[] memory credits = new CarbonCreditTokenData[](creditCodes.length);

        for (uint256 i = 0; i < creditCodes.length; i++) {
            uint256 tokenId = uint256(keccak256(abi.encodePacked(creditCodes[i])));
            require(bytes(_tokenMetadata[tokenId].creditCode).length > 0, "Token not exist");
            credits[i] = _tokenMetadata[tokenId];
        }
        return credits;
    }
}