// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Explicit imports that work on Windows/WSL
import {StdInvariant} from "lib/forge-std/src/StdInvariant.sol";
import "forge-std/Test.sol";

import "../contracts/RegistrationRegistry.sol";
import "../contracts/RegistrationRegistryImproved.sol";

contract Invariants is StdInvariant, Test {

    RegistrationRegistry rrBase;
    RegistrationRegistryImproved rrImp;

    address ownerA   = address(0xA11CE);
    address attacker = address(0xBEEF);
    bytes16 uuid = 0x11111111111111111111111111111111;

    function setUp() public {
        rrBase = new RegistrationRegistry();
        rrImp  = new RegistrationRegistryImproved();

        // ownerA registers the first time on both contracts
        vm.startPrank(ownerA);
        rrBase.submit(uuid, 0, "{\"id\":\"seed\"}", false);
        rrImp.submit(uuid, 0, "{\"id\":\"seed\"}", false);
        vm.stopPrank();

        // target both contracts for invariant fuzzing
        targetContract(address(rrBase));
        targetContract(address(rrImp));

        // CORRECTED SYNTAX: Declare and initialize the selectors array
        bytes4[] memory sels = new bytes4[](1);
        sels[0] = rrBase.submit.selector;

        // register the selectors for each target contract using the correct structure
        targetSelector(FuzzSelector({addr: address(rrBase), selectors: sels}));
        targetSelector(FuzzSelector({addr: address(rrImp),  selectors: sels}));
    }

    // Baseline: attacker should be able to overwrite (demonstrates the gap)
    function invariant_Baseline_Allows_Attacker_Update() public {
        vm.startPrank(attacker);
        string memory j = "{\"id\":\"evil\"}";
        (bool ok,) = address(rrBase).call(
            abi.encodeWithSelector(rrBase.submit.selector, uuid, uint8(0), j, true)
        );
        vm.stopPrank();
        // Baseline expected to allow attacker update; require to show exposure
        require(ok, "Expected baseline to allow attacker update");
    }

    // Intentionally failing invariant to quantify Time-to-Exposure (TTE)
    // This asserts the submitter remains the original owner; the baseline
    // contract is vulnerable, so after the attacker update, this will FAIL.
    function invariant_Baseline_Fails_On_Attacker_Update() public {
        vm.startPrank(attacker);
        string memory j = "{\"id\":\"evil\"}";
        (bool ok,) = address(rrBase).call(
            abi.encodeWithSelector(rrBase.submit.selector, uuid, uint8(0), j, true)
        );
        vm.stopPrank();
        require(ok, "Expected baseline to allow attacker update");

        (, , address submitter, ) = rrBase.getRegistration(uuid);
        // Intentionally fail once vulnerability is exposed
        assertEq(submitter, ownerA, "TTE reached: attacker overwrote baseline registration");
    }

    // Improved: attacker should NOT be able to overwrite (should remain passing)
    function invariant_Improved_Blocks_Attacker_Update() public {
        vm.startPrank(attacker);
        string memory j = "{\"id\":\"evil\"}";
        (bool ok,) = address(rrImp).call(
            abi.encodeWithSelector(rrImp.submit.selector, uuid, uint8(0), j, true)
        );
        vm.stopPrank();
        // Require the call to fail (i.e., improved contract blocks attacker)
        require(!ok, "Improved should block attacker update");
    }
}
