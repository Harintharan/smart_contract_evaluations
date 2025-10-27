// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract ProductRegistryImproved {
    struct ProductMeta {
        bytes32 hash;
        uint256 createdAt;
        uint256 updatedAt;
        address createdBy;
        address updatedBy;
        bool exists;
    }

    mapping(bytes16 => ProductMeta) public products;

    event ProductRegistered(bytes16 indexed productId, bytes32 hash, address createdBy, uint256 createdAt);
    event ProductUpdated(bytes16 indexed productId, bytes32 newHash, address updatedBy, uint256 updatedAt);

    error NotAuthorized(bytes16 productId, address caller);
    error AlreadyExists(bytes16 productId);
    error DoesNotExist(bytes16 productId);

    modifier onlyOwner(bytes16 productId) {
        if (products[productId].createdBy != msg.sender) {
            revert NotAuthorized(productId, msg.sender);
        }
        _;
    }

    function registerProduct(bytes16 productId, bytes calldata canonicalPayload)
        external
        returns (bytes16)
    {
        if (products[productId].exists) revert AlreadyExists(productId);

        bytes32 hash = keccak256(canonicalPayload);
        products[productId] = ProductMeta({
            hash: hash,
            createdAt: block.timestamp,
            updatedAt: 0,
            createdBy: msg.sender,
            updatedBy: address(0),
            exists: true
        });

        emit ProductRegistered(productId, hash, msg.sender, block.timestamp);
        return productId;
    }

    function updateProduct(bytes16 productId, bytes calldata canonicalPayload)
        external
        onlyOwner(productId)
    {
        if (!products[productId].exists) revert DoesNotExist(productId);

        bytes32 newHash = keccak256(canonicalPayload);
        ProductMeta storage prod = products[productId];
        prod.hash = newHash;
        prod.updatedAt = block.timestamp;
        prod.updatedBy = msg.sender;

        emit ProductUpdated(productId, newHash, msg.sender, block.timestamp);
    }

    function getProduct(bytes16 productId) external view returns (ProductMeta memory) {
        if (!products[productId].exists) revert DoesNotExist(productId);
        return products[productId];
    }
}
