// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract BatchRegistryImproved {
    struct BatchMeta {
        bytes32 hash;
        uint256 createdAt;
        uint256 updatedAt;
        address createdBy;
        address updatedBy;  
        bool exists;
    }

    mapping(bytes16 => BatchMeta) public batches;

    event BatchRegistered(bytes16 indexed batchId, bytes32 hash, address createdBy, uint256 createdAt);
    event BatchUpdated(bytes16 indexed batchId, bytes32 newHash, address updatedBy, uint256 updatedAt);

    error NotAuthorized(bytes16 batchId, address caller);
    error AlreadyExists(bytes16 batchId);
    error DoesNotExist(bytes16 batchId);

    modifier onlyOwner(bytes16 batchId) {
        if (batches[batchId].createdBy != msg.sender) {
            revert NotAuthorized(batchId, msg.sender);
        }
        _;
    }

    function registerBatch(bytes16 batchId, bytes calldata canonicalPayload)
        external
        returns (bytes16)
    {
        if (batches[batchId].exists) revert AlreadyExists(batchId);

        bytes32 hash = keccak256(canonicalPayload);
        batches[batchId] = BatchMeta({
            hash: hash,
            createdAt: block.timestamp,
            updatedAt: 0,
            createdBy: msg.sender,
            updatedBy: address(0),
            exists: true
        });

        emit BatchRegistered(batchId, hash, msg.sender, block.timestamp);
        return batchId;
    }

    function updateBatch(bytes16 batchId, bytes calldata canonicalPayload)
        external
        onlyOwner(batchId)
    {
        if (!batches[batchId].exists) revert DoesNotExist(batchId);

        bytes32 newHash = keccak256(canonicalPayload);
        BatchMeta storage meta = batches[batchId];
        meta.hash = newHash;
        meta.updatedAt = block.timestamp;
        meta.updatedBy = msg.sender;

        emit BatchUpdated(batchId, newHash, msg.sender, block.timestamp);
    }

    function getBatch(bytes16 batchId) external view returns (BatchMeta memory) {
        if (!batches[batchId].exists) revert DoesNotExist(batchId);
        return batches[batchId];
    }
}
