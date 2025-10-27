// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "lib/forge-std/src/StdInvariant.sol";

import "../contracts/ShipmentRegistry.sol";
import "../contracts/ShipmentRegistryImproved.sol";

contract ShipmentRegistryTest is Test {
    function test_Baseline_Register() public {
        ShipmentRegistry s = new ShipmentRegistry();
        bytes32 h = keccak256("seed");
        uint256 id = s.registerShipment(h);
        assertGt(id, 0);
        ShipmentRegistry.ShipmentMeta memory m = s.getShipment(id);
        assertEq(m.hash, h);
        assertEq(m.createdBy, address(this));
    }

    function test_Baseline_Update() public {
        ShipmentRegistry s = new ShipmentRegistry();
        uint256 id = s.registerShipment(keccak256("seed"));
        bytes32 h2 = keccak256("evil");
        s.updateShipment(id, h2);
        ShipmentRegistry.ShipmentMeta memory m = s.getShipment(id);
        assertEq(m.hash, h2);
        assertEq(m.updatedBy, address(this));
    }

    function test_Improved_Register() public {
        ShipmentRegistryImproved s = new ShipmentRegistryImproved();
        bytes32 h = keccak256("seed");
        uint256 id = s.registerShipment(h);
        assertGt(id, 0);
        ShipmentRegistryImproved.ShipmentMeta memory m = s.getShipment(id);
        assertEq(m.hash, h);
    }

    function test_Improved_Update() public {
        ShipmentRegistryImproved s = new ShipmentRegistryImproved();
        uint256 id;
        {
            vm.startPrank(address(0xA11CE));
            id = s.registerShipment(keccak256("seed"));
            vm.stopPrank();
        }
        vm.startPrank(address(0xA11CE));
        s.updateShipment(id, keccak256("ok"));
        vm.stopPrank();
        ShipmentRegistryImproved.ShipmentMeta memory m = s.getShipment(id);
        assertEq(m.updatedBy, address(0xA11CE));
    }

    function test_Baseline_Allows_Attacker_Update() public {
        ShipmentRegistry s = new ShipmentRegistry();
        address ownerA = address(0xA11CE);
        uint256 id;
        vm.prank(ownerA);
        id = s.registerShipment(keccak256("seed"));

        address attacker = address(0xBEEF);
        vm.prank(attacker);
        s.updateShipment(id, keccak256("evil"));
        ShipmentRegistry.ShipmentMeta memory m = s.getShipment(id);
        assertEq(m.updatedBy, attacker, "Baseline unexpectedly blocked attacker");
    }

    function test_Improved_Blocks_Attacker_Update() public {
        ShipmentRegistryImproved s = new ShipmentRegistryImproved();
        address ownerA = address(0xA11CE);
        uint256 id;
        vm.prank(ownerA);
        id = s.registerShipment(keccak256("seed"));

        address attacker = address(0xBEEF);
        vm.prank(attacker);
        vm.expectRevert();
        s.updateShipment(id, keccak256("evil"));
    }
}

contract ShipmentInvariants is StdInvariant, Test {
    ShipmentRegistry base;
    ShipmentRegistryImproved imp;

    address ownerA   = address(0xA11CE);
    address attacker = address(0xBEEF);
    uint256 sid;

    function setUp() public {
        base = new ShipmentRegistry();
        imp  = new ShipmentRegistryImproved();
        vm.prank(ownerA);
        sid = base.registerShipment(keccak256("seed"));
        vm.prank(ownerA);
        imp.registerShipment(keccak256("seed"));
    }

    function invariant_Baseline_Allows_Attacker_Update() public {
        vm.startPrank(attacker);
        (bool ok,) = address(base).call(
            abi.encodeWithSelector(base.updateShipment.selector, sid, keccak256("evil"))
        );
        vm.stopPrank();
        require(ok, "Expected baseline to allow attacker update");
    }

    function invariant_Baseline_Fails_On_Attacker_Update() public {
        vm.startPrank(attacker);
        (bool ok,) = address(base).call(
            abi.encodeWithSelector(base.updateShipment.selector, sid, keccak256("evil"))
        );
        vm.stopPrank();
        require(ok, "Expected baseline to allow attacker update");
        ShipmentRegistry.ShipmentMeta memory m = base.getShipment(sid);
        assertEq(m.updatedBy, ownerA, "TTE reached: attacker overwrote baseline shipment");
    }

    function invariant_Improved_Blocks_Attacker_Update() public {
        vm.startPrank(attacker);
        (bool ok,) = address(imp).call(
            abi.encodeWithSelector(imp.updateShipment.selector, sid, keccak256("evil"))
        );
        vm.stopPrank();
        require(!ok, "Improved should block attacker update");
    }
}

