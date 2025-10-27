// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract ShipmentRegistryImproved {
    uint256 public nextShipmentId = 1;

    struct ShipmentMeta {
        bytes32 hash;
        uint256 createdAt;
        uint256 updatedAt;
        address createdBy;
        address updatedBy;
        bool exists;
    }

    mapping(uint256 => ShipmentMeta) public shipments;

    event ShipmentRegistered(uint256 indexed shipmentId, bytes32 hash, address createdBy, uint256 createdAt);
    event ShipmentUpdated(uint256 indexed shipmentId, bytes32 newHash, address updatedBy, uint256 updatedAt);

    error NotAuthorized(uint256 shipmentId, address caller);
    error DoesNotExist(uint256 shipmentId);
    error AlreadyExists(uint256 shipmentId);

    modifier onlyOwner(uint256 shipmentId) {
        if (shipments[shipmentId].createdBy != msg.sender) {
            revert NotAuthorized(shipmentId, msg.sender);
        }
        _;
    }

    function registerShipment(bytes32 dbHash) external returns (uint256) {
        uint256 shipmentId = nextShipmentId++;
        if (shipments[shipmentId].exists) revert AlreadyExists(shipmentId);

        shipments[shipmentId] = ShipmentMeta({
            hash: dbHash,
            createdAt: block.timestamp,
            updatedAt: 0,
            createdBy: msg.sender,
            updatedBy: address(0),
            exists: true
        });

        emit ShipmentRegistered(shipmentId, dbHash, msg.sender, block.timestamp);
        return shipmentId;
    }

    function updateShipment(uint256 shipmentId, bytes32 newHash)
        external
        onlyOwner(shipmentId)
    {
        if (!shipments[shipmentId].exists) revert DoesNotExist(shipmentId);

        ShipmentMeta storage sh = shipments[shipmentId];
        sh.hash = newHash;
        sh.updatedAt = block.timestamp;
        sh.updatedBy = msg.sender;

        emit ShipmentUpdated(shipmentId, newHash, msg.sender, block.timestamp);
    }

    function getShipment(uint256 shipmentId)
        external
        view
        returns (ShipmentMeta memory)
    {
        if (!shipments[shipmentId].exists) revert DoesNotExist(shipmentId);
        return shipments[shipmentId];
    }
}

