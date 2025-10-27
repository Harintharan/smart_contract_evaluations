// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract ShipmentSegmentAcceptanceImproved {
    uint256 public nextAcceptanceId = 1;

    struct AcceptanceMeta {
        bytes32 hash;
        uint256 shipmentId;
        uint256 createdAt;
        uint256 updatedAt;
        address createdBy;
        address updatedBy;
        bool exists;
    }

    mapping(uint256 => AcceptanceMeta) public acceptances;

    event SegmentAccepted(
        uint256 indexed acceptanceId,
        uint256 shipmentId,
        bytes32 hash,
        address createdBy,
        uint256 createdAt
    );

    event SegmentUpdated(
        uint256 indexed acceptanceId,
        bytes32 newHash,
        address updatedBy,
        uint256 updatedAt
    );

    error NotAuthorized(uint256 acceptanceId, address caller);
    error AlreadyExists(uint256 acceptanceId);
    error DoesNotExist(uint256 acceptanceId);

    modifier onlyOwner(uint256 acceptanceId) {
        if (acceptances[acceptanceId].createdBy != msg.sender) {
            revert NotAuthorized(acceptanceId, msg.sender);
        }
        _;
    }

    /// 🔹 Register new acceptance
    function registerSegmentAcceptance(uint256 shipmentId, bytes32 dbHash)
        external
        returns (uint256)
    {
        uint256 acceptanceId = nextAcceptanceId++;

        if (acceptances[acceptanceId].exists) revert AlreadyExists(acceptanceId);

        acceptances[acceptanceId] = AcceptanceMeta({
            hash: dbHash,
            shipmentId: shipmentId,
            createdAt: block.timestamp,
            updatedAt: 0,
            createdBy: msg.sender,
            updatedBy: address(0),
            exists: true
        });

        emit SegmentAccepted(acceptanceId, shipmentId, dbHash, msg.sender, block.timestamp);
        return acceptanceId;
    }

    /// 🔹 Update existing acceptance
    function updateSegmentAcceptance(uint256 acceptanceId, bytes32 newHash)
        external
        onlyOwner(acceptanceId)
    {
        if (!acceptances[acceptanceId].exists) revert DoesNotExist(acceptanceId);

        AcceptanceMeta storage acc = acceptances[acceptanceId];
        acc.hash = newHash;
        acc.updatedAt = block.timestamp;
        acc.updatedBy = msg.sender;

        emit SegmentUpdated(acceptanceId, newHash, msg.sender, block.timestamp);
    }

    /// 🔹 Get acceptance
    function getSegmentAcceptance(uint256 acceptanceId)
        external
        view
        returns (AcceptanceMeta memory)
    {
        if (!acceptances[acceptanceId].exists) revert DoesNotExist(acceptanceId);
        return acceptances[acceptanceId];
    }
}
