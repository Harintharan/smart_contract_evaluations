// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "lib/forge-std/src/StdInvariant.sol";

import "../contracts/ProductRegistry.sol";
import "../contracts/ProductRegistryImproved.sol";

contract ProductRegistryTest is Test {
    function test_Baseline_Allows_Attacker_Update() public {
        ProductRegistry base = new ProductRegistry();
        bytes16 pid = 0x11111111111111111111111111111111;

        address ownerA = address(0xA11CE);
        bytes memory seed = bytes("{\"id\":\"seed\"}");
        vm.prank(ownerA);
        base.registerProduct(pid, seed);

        address attacker = address(0xBEEF);
        bytes memory evil = bytes("{\"id\":\"evil\"}");
        vm.prank(attacker);
        base.updateProduct(pid, evil);

        ProductRegistry.ProductMeta memory m = base.getProduct(pid);
        assertEq(m.updatedBy, attacker, "Baseline unexpectedly blocked attacker");
    }

    function test_Improved_Blocks_Attacker_Update() public {
        ProductRegistryImproved imp = new ProductRegistryImproved();
        bytes16 pid = 0x11111111111111111111111111111111;

        address ownerA = address(0xA11CE);
        bytes memory seed = bytes("{\"id\":\"seed\"}");
        vm.prank(ownerA);
        imp.registerProduct(pid, seed);

        address attacker = address(0xBEEF);
        bytes memory evil = bytes("{\"id\":\"evil\"}");
        vm.prank(attacker);
        vm.expectRevert();
        imp.updateProduct(pid, evil);
    }
}

contract ProductInvariants is StdInvariant, Test {
    ProductRegistry base;
    ProductRegistryImproved imp;

    address ownerA   = address(0xA11CE);
    address attacker = address(0xBEEF);
    bytes16 pid = 0x11111111111111111111111111111111;

    function setUp() public {
        base = new ProductRegistry();
        imp  = new ProductRegistryImproved();

        vm.startPrank(ownerA);
        base.registerProduct(pid, bytes("{\"id\":\"seed\"}"));
        imp.registerProduct(pid,  bytes("{\"id\":\"seed\"}"));
        vm.stopPrank();
    }

    function invariant_Baseline_Allows_Attacker_Update() public {
        vm.startPrank(attacker);
        (bool ok,) = address(base).call(
            abi.encodeWithSelector(base.updateProduct.selector, pid, bytes("{\"id\":\"evil\"}"))
        );
        vm.stopPrank();
        require(ok, "Expected baseline to allow attacker update");
    }

    // Intentionally failing invariant for TTE measurement:
    // After the attacker updates baseline, assert state still owned by original owner.
    // This will FAIL once exposure occurs, allowing TTE to be measured as failure time.
    function invariant_Baseline_Fails_On_Attacker_Update() public {
        vm.startPrank(attacker);
        (bool ok,) = address(base).call(
            abi.encodeWithSelector(base.updateProduct.selector, pid, bytes("{\"id\":\"evil\"}"))
        );
        vm.stopPrank();
        require(ok, "Expected baseline to allow attacker update");

        ProductRegistry.ProductMeta memory m = base.getProduct(pid);
        // This assertion should fail once attacker overwrites the record
        assertEq(m.updatedBy, ownerA, "TTE reached: attacker overwrote baseline product");
    }

    function invariant_Improved_Blocks_Attacker_Update() public {
        vm.startPrank(attacker);
        (bool ok,) = address(imp).call(
            abi.encodeWithSelector(imp.updateProduct.selector, pid, bytes("{\"id\":\"evil\"}"))
        );
        vm.stopPrank();
        require(!ok, "Improved should block attacker update");
    }
}
