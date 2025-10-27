// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "lib/forge-std/src/StdInvariant.sol";

import "../contracts/ShipmentSegmentAcceptance.sol";
import "../contracts/ShipmentSegmentAcceptanceImproved.sol";

contract ShipmentSegmentAcceptanceTest is Test {
    function test_Baseline_Register() public {
        ShipmentSegmentAcceptance s = new ShipmentSegmentAcceptance();
        uint256 id = s.registerSegmentAcceptance(1, keccak256("seed"));
        assertGt(id, 0);
        ShipmentSegmentAcceptance.AcceptanceMeta memory m = s.getSegmentAcceptance(id);
        assertEq(m.shipmentId, 1);
        assertEq(m.hash, keccak256("seed"));
        assertEq(m.createdBy, address(this));
    }

    function test_Baseline_Allows_Attacker_Update() public {
        ShipmentSegmentAcceptance s = new ShipmentSegmentAcceptance();
        address ownerA = address(0xA11CE);
        uint256 id;
        vm.prank(ownerA);
        id = s.registerSegmentAcceptance(42, keccak256("seed"));

        address attacker = address(0xBEEF);
        vm.prank(attacker);
        s.updateSegmentAcceptance(id, keccak256("evil"));
        ShipmentSegmentAcceptance.AcceptanceMeta memory m = s.getSegmentAcceptance(id);
        assertEq(m.updatedBy, attacker, "Baseline unexpectedly blocked attacker");
    }

    function test_Improved_Blocks_Attacker_Update() public {
        ShipmentSegmentAcceptanceImproved s = new ShipmentSegmentAcceptanceImproved();
        address ownerA = address(0xA11CE);
        uint256 id;
        vm.prank(ownerA);
        id = s.registerSegmentAcceptance(42, keccak256("seed"));

        address attacker = address(0xBEEF);
        vm.prank(attacker);
        vm.expectRevert();
        s.updateSegmentAcceptance(id, keccak256("evil"));
    }
}

contract SegmentInvariants is StdInvariant, Test {
    ShipmentSegmentAcceptance base;
    ShipmentSegmentAcceptanceImproved imp;

    address ownerA   = address(0xA11CE);
    address attacker = address(0xBEEF);
    uint256 aid;

    function setUp() public {
        base = new ShipmentSegmentAcceptance();
        imp  = new ShipmentSegmentAcceptanceImproved();
        vm.prank(ownerA);
        aid = base.registerSegmentAcceptance(7, keccak256("seed"));
        vm.prank(ownerA);
        imp.registerSegmentAcceptance(7, keccak256("seed"));
    }

    function invariant_Baseline_Allows_Attacker_Update() public {
        vm.startPrank(attacker);
        (bool ok,) = address(base).call(
            abi.encodeWithSelector(base.updateSegmentAcceptance.selector, aid, keccak256("evil"))
        );
        vm.stopPrank();
        require(ok, "Expected baseline to allow attacker update");
    }

    // Intentionally failing baseline invariant for TTE measurement
    function invariant_Baseline_Fails_On_Attacker_Update() public {
        vm.startPrank(attacker);
        (bool ok,) = address(base).call(
            abi.encodeWithSelector(base.updateSegmentAcceptance.selector, aid, keccak256("evil"))
        );
        vm.stopPrank();
        require(ok, "Expected baseline to allow attacker update");
        ShipmentSegmentAcceptance.AcceptanceMeta memory m = base.getSegmentAcceptance(aid);
        assertEq(m.updatedBy, ownerA, "TTE reached: attacker overwrote baseline acceptance");
    }

    function invariant_Improved_Blocks_Attacker_Update() public {
        vm.startPrank(attacker);
        (bool ok,) = address(imp).call(
            abi.encodeWithSelector(imp.updateSegmentAcceptance.selector, aid, keccak256("evil"))
        );
        vm.stopPrank();
        require(!ok, "Improved should block attacker update");
    }
}

