// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../contracts/RegistrationRegistry.sol";
import "../contracts/RegistrationRegistryImproved.sol";

contract RegistrationRegistryTest is Test {
    // ---- Baseline ----
    function test_CreateOnce_Baseline() public {
        RegistrationRegistry rr = new RegistrationRegistry();
        bytes16 uuid = 0x11111111111111111111111111111111;
        string memory j = "{\"id\":\"A\"}";
        rr.submit(uuid, 0, j, false);

        (bytes32 h, uint8 t, address s, uint256 ts) = rr.getRegistration(uuid);
        assertEq(t, 0);
        assertEq(s, address(this));
        assertEq(h, keccak256(bytes(j)));
        assertGt(ts, 0);
    }

    function test_CreateTwiceReverts_Baseline() public {
        RegistrationRegistry rr = new RegistrationRegistry();
        bytes16 uuid = 0x11111111111111111111111111111111;
        string memory j = "{\"id\":\"A\"}";
        rr.submit(uuid, 0, j, false);
        vm.expectRevert(); // RegistrationAlreadyExists
        rr.submit(uuid, 0, j, false);
    }

    function test_UpdateNonExistentReverts_Baseline() public {
        RegistrationRegistry rr = new RegistrationRegistry();
        bytes16 uuid = 0x11111111111111111111111111111111;
        string memory j = "{\"id\":\"A\"}";
        vm.expectRevert(); // RegistrationDoesNotExist
        rr.submit(uuid, 0, j, true);
    }

    // ---- Security gap demo (Baseline allows attacker to update) ----
    function test_AttackerCanUpdate_Baseline() public {
        RegistrationRegistry rr = new RegistrationRegistry();
        bytes16 uuid = 0x11111111111111111111111111111111;

        address ownerA = address(0xA11CE);
        vm.prank(ownerA);
        rr.submit(uuid, 0, "{\"id\":\"seed\"}", false);

        address attacker = address(0xBEEF);
        vm.prank(attacker);
        // Baseline has NO owner check; this update will succeed
        rr.submit(uuid, 0, "{\"id\":\"evil\"}", true);

        (, , address submitter, ) = rr.getRegistration(uuid);
        assertEq(submitter, attacker, "Baseline unexpectedly blocked attacker");
    }

    // ---- Improved should block attacker ----
    function test_AttackerBlocked_Improved() public {
        RegistrationRegistryImproved rr = new RegistrationRegistryImproved();
        bytes16 uuid = 0x11111111111111111111111111111111;

        address ownerA = address(0xA11CE);
        vm.prank(ownerA);
        rr.submit(uuid, 0, "{\"id\":\"seed\"}", false);

        address attacker = address(0xBEEF);
        vm.prank(attacker);
        vm.expectRevert(); // NotAuthorized
        rr.submit(uuid, 0, "{\"id\":\"evil\"}", true);
    }
}
