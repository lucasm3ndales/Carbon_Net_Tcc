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

    event CarbonCreditMinted(
        uint256 indexed tokenId,
        string creditCode,
        bool minted
    );

    event CarbonCreditTransferred(
        uint256 indexed tokenId,
        address from,
        address to
    );

    event CarbonCreditRetired(
        uint256 indexed tokenId,
        string creditCode,
        address retiredBy
    );

    event CarbonCreditAvailable(
        uint256 indexed tokenId, 
        string creditCode, 
        address setBy);

    event CarbonCreditCancelled(
        uint256 indexed tokenId, 
        string creditCode, 
        address setBy);

    function initialize(
        string memory baseURI,
        address initialOwner
    ) public initializer {
        require(bytes(baseURI).length > 0, "Base URI cannot be empty");
        require(initialOwner != address(0), "Owner address cannot be zero");
        __ERC1155_init(baseURI);
        __Ownable_init(initialOwner);
    }

    function batchMintCarbonCredits(
        address to,
        CarbonCreditTokenData[] calldata credits
    ) external onlyOwner returns (bool, string memory) {
        require(credits.length > 0, "No credits provided");
        for (uint256 i = 0; i < credits.length; i++) {
            CarbonCreditTokenData calldata data = credits[i];

            require(bytes(data.creditCode).length > 0, "Credit code required");
            require(data.tonCO2Quantity > 0, "CO2 quantity must be > 0");

            uint256 tokenId = uint256(
                keccak256(abi.encodePacked(data.creditCode))
            );
            bool minted = false;

            if (bytes(_tokenMetadata[tokenId].creditCode).length == 0) {
                CarbonCreditTokenData memory newData = data;
                newData.createdAt = block.timestamp;
                newData.updatedAt = block.timestamp;
                _tokenMetadata[tokenId] = newData;
                _mint(to, tokenId, 1, "");
                minted = true;
            } else {
                require(
                    _tokenMetadata[tokenId].status != CarbonCreditStatus.RETIRED,
                    "Token is retired"
                );
                require(
                    _tokenMetadata[tokenId].status != CarbonCreditStatus.CANCELLED,
                    "Token is cancelled"
                );
                require(
                    _tokenMetadata[tokenId].status != CarbonCreditStatus.PENDING_ISSUANCE,
                    "Token is pending issuance"
                );
                require(data.tonCO2Quantity > 0, "CO2 quantity must be > 0");

                CarbonCreditTokenData storage existing = _tokenMetadata[tokenId];
                existing.vintageYear = data.vintageYear;
                existing.tonCO2Quantity = data.tonCO2Quantity;
                existing.status = data.status;
                existing.ownerName = data.ownerName;
                existing.ownerDocument = data.ownerDocument;
                existing.updatedAt = block.timestamp;
                existing.projectCode = data.projectCode;
            }

            emit CarbonCreditMinted(tokenId, data.creditCode, minted);
        }

        return (true, "Batch processed successfully");
    }

    function getCarbonCredit(
        string calldata creditCode
    ) external view returns (CarbonCreditTokenData memory) {
        uint256 tokenId = uint256(keccak256(abi.encodePacked(creditCode)));
        require(
            bytes(_tokenMetadata[tokenId].creditCode).length > 0,
            "Token does not exist"
        );
        return _tokenMetadata[tokenId];
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return
            string(
                abi.encodePacked(
                    super.uri(tokenId),
                    tokenId.toString(),
                    ".json"
                )
            );
    }

    function batchTransferCarbonCredits(
        address from,
        address to,
        string[] calldata creditCodes
    ) external onlyOwner returns (bool, string memory) {
        require(to != address(0), "Invalid recipient");
        require(creditCodes.length > 0, "No credit codes provided");
        
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "Caller is not owner nor approved"
        );

        for (uint256 i = 0; i < creditCodes.length; i++) {
            uint256 tokenId = uint256(keccak256(abi.encodePacked(creditCodes[i])));
            require(
                bytes(_tokenMetadata[tokenId].creditCode).length > 0,
                "Token does not exist"
            );
            require(
                balanceOf(from, tokenId) > 0,
                "Sender does not own the token"
            );

            CarbonCreditTokenData storage data = _tokenMetadata[tokenId];
            require(
                data.status != CarbonCreditStatus.RETIRED,
                "Token is retired"
            );
            require(
                data.status != CarbonCreditStatus.CANCELLED,
                "Token is cancelled"
            );
            require(
                data.status != CarbonCreditStatus.PENDING_ISSUANCE,
                "Token is pending issuance"
            );

            _safeTransferFrom(from, to, tokenId, 1, "");

            data.status = CarbonCreditStatus.TRANSFERRED;
            data.updatedAt = block.timestamp;

            emit CarbonCreditTransferred(tokenId, from, to);
        }

        return (true, "Batch transfer successful");
    }

    function batchRetireCarbonCredits(
        string[] calldata creditCodes
    ) external onlyOwner returns (bool, string memory) {
        require(creditCodes.length > 0, "No credit codes provided");

        for (uint256 i = 0; i < creditCodes.length; i++) {
            uint256 tokenId = uint256(keccak256(abi.encodePacked(creditCodes[i])));
            require(
                bytes(_tokenMetadata[tokenId].creditCode).length > 0,
                "Token does not exist"
            );

            CarbonCreditTokenData storage data = _tokenMetadata[tokenId];
            require(
                data.status != CarbonCreditStatus.PENDING_ISSUANCE,
                "Token is pending issuance"
            );
            require(
                data.status != CarbonCreditStatus.CANCELLED,
                "Token is cancelled"
            );
            require(
                data.status != CarbonCreditStatus.RETIRED,
                "Token already retired"
            );

            data.status = CarbonCreditStatus.RETIRED;
            data.updatedAt = block.timestamp;

            emit CarbonCreditRetired(tokenId, creditCodes[i], msg.sender);
        }

        return (true, "Batch retirement successful");
    }

     function batchAvailableCarbonCredits(
        string[] calldata creditCodes
    ) external onlyOwner returns (bool, string memory) {
        require(creditCodes.length > 0, "No credit codes provided");

        for (uint256 i = 0; i < creditCodes.length; i++) {
            uint256 tokenId = uint256(keccak256(abi.encodePacked(creditCodes[i])));
            require(
                bytes(_tokenMetadata[tokenId].creditCode).length > 0,
                "Token does not exist"
            );

            CarbonCreditTokenData storage data = _tokenMetadata[tokenId];
            
            require(
                data.status != CarbonCreditStatus.RETIRED,
                "Token is retired"
            );
            require(
                data.status != CarbonCreditStatus.CANCELLED,
                "Token is cancelled"
            );
            require(
                data.status != CarbonCreditStatus.PENDING_ISSUANCE,
                "Token is pending issuance"
            );

            data.status = CarbonCreditStatus.AVAILABLE;
            data.updatedAt = block.timestamp;

            emit CarbonCreditAvailable(tokenId, creditCodes[i], msg.sender);
        }

        return (true, "Tokens made available successfully");
    }

    function batchCancelCarbonCredits(
        string[] calldata creditCodes
    ) external onlyOwner returns (bool, string memory) {
        require(creditCodes.length > 0, "No credit codes provided");

        for (uint256 i = 0; i < creditCodes.length; i++) {
            uint256 tokenId = uint256(keccak256(abi.encodePacked(creditCodes[i])));
            require(
                bytes(_tokenMetadata[tokenId].creditCode).length > 0,
                "Token does not exist"
            );

            CarbonCreditTokenData storage data = _tokenMetadata[tokenId];
            
            require(
                data.status != CarbonCreditStatus.RETIRED,
                "Token is retired"
            );
            require(
                data.status != CarbonCreditStatus.CANCELLED,
                "Token is already cancelled"
            );

            data.status = CarbonCreditStatus.CANCELLED;
            data.updatedAt = block.timestamp;

            emit CarbonCreditCancelled(tokenId, creditCodes[i], msg.sender);
        }

        return (true, "Tokens cancelled successfully");
    }
}
