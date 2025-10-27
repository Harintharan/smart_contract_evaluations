// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract RegistrationRegistryImproved {
    uint256 public constant MAX_PAYLOAD_BYTES = 8192;

    enum RegistrationType { MANUFACTURER, SUPPLIER, WAREHOUSE, CONSUMER }

    struct Registration {
        bytes32 payloadHash;
        uint8 regType;
        address submitter;    // owner
        uint256 updatedAt;
    }

    mapping(bytes16 => Registration) private registrations;
    mapping(bytes16 => bool) private registrationExists;
    mapping(bytes16 => address) private ownerOf; // Tracks the owner address

    event RegistrationSubmitted(
        bytes16 indexed uuid,
        bytes32 payloadHash,
        uint8 regType,
        address indexed submitter,
        uint256 timestamp,
        bool isUpdate
    );

    error InvalidRegistrationType(uint8 regType);
    error RegistrationAlreadyExists(bytes16 uuid);
    error RegistrationDoesNotExist(bytes16 uuid);
    error PayloadTooLarge(uint256 size, uint256 max);
    error NotAuthorized(bytes16 uuid, address caller);

    /// @notice Submit a new registration or update an existing one
    /// @param uuid Unique identifier for the registration
    /// @param regType Registration type as uint8 (see RegistrationType)
    /// @param payloadCanonicalJson Canonical JSON string payload
    /// @param isUpdate True to update existing; false to create new
    function submit(
        bytes16 uuid,
        uint8 regType,
        string calldata payloadCanonicalJson,
        bool isUpdate
    ) external {
        if (regType > uint8(RegistrationType.CONSUMER)) {
            revert InvalidRegistrationType(regType);
        }
        uint256 payloadSize = bytes(payloadCanonicalJson).length;
        if (payloadSize > MAX_PAYLOAD_BYTES) {
            revert PayloadTooLarge(payloadSize, MAX_PAYLOAD_BYTES);
        }

        bool hasExisting = registrationExists[uuid];
        if (hasExisting && !isUpdate) revert RegistrationAlreadyExists(uuid);
        if (!hasExisting && isUpdate) revert RegistrationDoesNotExist(uuid);

        if (hasExisting) {
            // NEW: only owner can update
            if (msg.sender != ownerOf[uuid]) revert NotAuthorized(uuid, msg.sender);
        }

        bytes32 payloadHash = keccak256(bytes(payloadCanonicalJson));
        uint256 timestamp = block.timestamp;

        registrations[uuid] = Registration({
            payloadHash: payloadHash,
            regType: regType,
            submitter: msg.sender,
            updatedAt: timestamp
        });

        if (!hasExisting) {
            registrationExists[uuid] = true;
            ownerOf[uuid] = msg.sender; // Set the initial owner
        }

        emit RegistrationSubmitted(uuid, payloadHash, regType, msg.sender, timestamp, isUpdate);
    }

    function getRegistration(bytes16 uuid)
        external view
        returns (bytes32 payloadHash, uint8 regType, address submitter, uint256 updatedAt)
    {
        if (!registrationExists[uuid]) revert RegistrationDoesNotExist(uuid);
        Registration storage info = registrations[uuid];
        return (info.payloadHash, info.regType, info.submitter, info.updatedAt);
    }

    function exists(bytes16 uuid) external view returns (bool) { return registrationExists[uuid]; }
    function owner(bytes16 uuid) external view returns (address) { return ownerOf[uuid]; }
}
