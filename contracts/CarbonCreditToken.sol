// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CarbonCreditToken is
    Initializable,
    ERC1155Upgradeable,
    OwnableUpgradeable
{
    struct CarbonCreditTokenData {
        string creditCode;
        uint32 vintageYear;
        uint32 tonCO2Quantity;
        string status;
        string ownerName;
        string ownerDocument;
        uint64 createdAt;
        uint64 updatedAt;
        string projectCode;
    }

    mapping(uint256 => CarbonCreditTokenData) private _tokenMetadata;

    event CarbonCreditUpdates(
        address indexed operator,
        string func,
        uint256[] tokenIds,
        string[] creditCodes
    );

    function initialize(
        string memory baseURI,
        address initialOwner
    ) public initializer {
        require(bytes(baseURI).length > 0, "Base URI empty");
        require(initialOwner != address(0), "Owner zero");
        __ERC1155_init(baseURI);
        __Ownable_init(initialOwner);
    }

    function _validStatusForUpdate(
        string memory status
    ) internal pure returns (bool) {
        return
            !Strings.equal(status, "RETIRED") &&
            !Strings.equal(status, "CANCELLED") &&
            !Strings.equal(status, "PENDING_ISSUANCE");
    }

    function batchMintCarbonCredits(
        address to,
        CarbonCreditTokenData[] calldata credits
    ) external onlyOwner returns (bool, string memory) {
        require(credits.length > 0, "No credits");

        uint256[] memory ids = new uint256[](credits.length);
        uint256[] memory values = new uint256[](credits.length);

        for (uint256 i = 0; i < credits.length; i++) {
            CarbonCreditTokenData calldata data = credits[i];
            require(bytes(data.creditCode).length > 0, "Credit code required");
            require(data.tonCO2Quantity > 0, "CO2 qty > 0");

            uint256 tokenId = uint256(
                keccak256(abi.encodePacked(data.creditCode))
            );
            CarbonCreditTokenData storage existing = _tokenMetadata[tokenId];

            if (bytes(existing.creditCode).length == 0) {
                CarbonCreditTokenData memory newData = data;
                newData.createdAt = uint64(block.timestamp);
                newData.updatedAt = uint64(block.timestamp);
                _tokenMetadata[tokenId] = newData;
                _mint(to, tokenId, 1, "");
            } else {
                existing.vintageYear = data.vintageYear;
                existing.tonCO2Quantity = data.tonCO2Quantity;
                existing.status = data.status;
                existing.ownerName = data.ownerName;
                existing.ownerDocument = data.ownerDocument;
                existing.updatedAt = uint64(block.timestamp);
                existing.projectCode = data.projectCode;
            }
            ids[i] = tokenId;
            values[i] = 1;
        }

        emit TransferBatch(msg.sender, address(0), to, ids, values);
        return (true, "Batch processed");
    }

    function getCarbonCredit(
        string calldata creditCode
    )
        external
        view
        returns (
            string memory creditCodeOut,
            uint32 vintageYear,
            uint32 tonCO2Quantity,
            string memory status,
            string memory ownerName,
            string memory ownerDocument,
            uint64 createdAt,
            uint64 updatedAt,
            string memory projectCode
        )
    {
        uint256 tokenId = uint256(keccak256(abi.encodePacked(creditCode)));
        CarbonCreditTokenData storage data = _tokenMetadata[tokenId];
        require(bytes(data.creditCode).length > 0, "Token not exist");

        return (
            data.creditCode,
            data.vintageYear,
            data.tonCO2Quantity,
            data.status,
            data.ownerName,
            data.ownerDocument,
            data.createdAt,
            data.updatedAt,
            data.projectCode
        );
    }

    function _batchUpdateStatus(
        string[] calldata creditCodes,
        string memory newStatus,
        string memory funcName
    ) internal returns (bool, string memory) {
        require(creditCodes.length > 0, "No credits");

        uint256[] memory ids = new uint256[](creditCodes.length);
        uint256[] memory values = new uint256[](creditCodes.length);

        for (uint256 i = 0; i < creditCodes.length; i++) {
            uint256 tokenId = uint256(
                keccak256(abi.encodePacked(creditCodes[i]))
            );
            CarbonCreditTokenData storage data = _tokenMetadata[tokenId];
            require(bytes(data.creditCode).length > 0, "Token not exist");

            if (_validStatusForUpdate(data.status)) {
                data.status = newStatus;
                data.updatedAt = uint64(block.timestamp);
                ids[i] = tokenId;
                values[i] = 1;
            }
        }

        emit TransferBatch(msg.sender, address(0), address(0), ids, values);
        emit CarbonCreditUpdates(msg.sender, funcName, ids, creditCodes);
        return (true, "Batch status updated");
    }

    function batchTransferCarbonCredits(
        address from,
        address to,
        string[] calldata creditCodes,
        string calldata ownerName,
        string calldata ownerDocument
    ) external returns (bool, string memory) {
        require(to != address(0), "Invalid recipient");
        require(creditCodes.length > 0, "No credits");
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "Not owner or approved"
        );

        uint256[] memory ids = new uint256[](creditCodes.length);
        uint256[] memory values = new uint256[](creditCodes.length);

        for (uint256 i = 0; i < creditCodes.length; i++) {
            uint256 tokenId = uint256(
                keccak256(abi.encodePacked(creditCodes[i]))
            );
            CarbonCreditTokenData storage data = _tokenMetadata[tokenId];
            require(bytes(data.creditCode).length > 0, "Token not exist");
            require(balanceOf(from, tokenId) > 0, "Sender no token");
            require(_validStatusForUpdate(data.status), "Invalid status");

            _safeTransferFrom(from, to, tokenId, 1, "");
            data.status = "TRANSFERRED";
            data.updatedAt = uint64(block.timestamp);
            data.ownerName = ownerName;
            data.ownerDocument = ownerDocument;

            ids[i] = tokenId;
            values[i] = 1;
        }

        emit TransferBatch(msg.sender, from, to, ids, values);
        emit CarbonCreditUpdates(
            msg.sender,
            "batchTransferCarbonCredits",
            ids,
            creditCodes
        );
        return (true, "Batch transfer done");
    }

    function batchRetireCarbonCredits(
        string[] calldata creditCodes
    ) external onlyOwner returns (bool, string memory) {
        return
            _batchUpdateStatus(
                creditCodes,
                "RETIRED",
                "batchRetireCarbonCredits"
            );
    }

    function batchAvailableCarbonCredits(
        string[] calldata creditCodes
    ) external onlyOwner returns (bool, string memory) {
        return
            _batchUpdateStatus(
                creditCodes,
                "AVAILABLE",
                "batchAvailableCarbonCredits"
            );
    }

    function batchCancelCarbonCredits(
        string[] calldata creditCodes
    ) external onlyOwner returns (bool, string memory) {
        return
            _batchUpdateStatus(
                creditCodes,
                "CANCELLED",
                "batchCancelCarbonCredits"
            );
    }

    function batchGetCarbonCredits(
        string[] calldata creditCodes
    )
        external
        view
        returns (
            string[] memory creditCodesOut,
            uint32[] memory vintageYears,
            uint32[] memory tonCO2Quantities,
            string[] memory statuses,
            string[] memory ownerNames,
            string[] memory ownerDocuments,
            uint64[] memory createdAts,
            uint64[] memory updatedAts,
            string[] memory projectCodes
        )
    {
        uint256 length = creditCodes.length;
        creditCodesOut = new string[](length);
        vintageYears = new uint32[](length);
        tonCO2Quantities = new uint32[](length);
        statuses = new string[](length);
        ownerNames = new string[](length);
        ownerDocuments = new string[](length);
        createdAts = new uint64[](length);
        updatedAts = new uint64[](length);
        projectCodes = new string[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = uint256(
                keccak256(abi.encodePacked(creditCodes[i]))
            );
            CarbonCreditTokenData storage data = _tokenMetadata[tokenId];
            require(bytes(data.creditCode).length > 0, "Token not exist");

            creditCodesOut[i] = data.creditCode;
            vintageYears[i] = data.vintageYear;
            tonCO2Quantities[i] = data.tonCO2Quantity;
            statuses[i] = data.status;
            ownerNames[i] = data.ownerName;
            ownerDocuments[i] = data.ownerDocument;
            createdAts[i] = data.createdAt;
            updatedAts[i] = data.updatedAt;
            projectCodes[i] = data.projectCode;
        }
    }

    function balanceOf(
        address account,
        string calldata creditCode
    ) public view returns (uint256) {
        require(account != address(0), "Balance query for zero address");
        uint256 tokenId = uint256(keccak256(abi.encodePacked(creditCode)));
        return super.balanceOf(account, tokenId);
    }
}
