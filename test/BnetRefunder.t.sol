// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {BnetRefunder} from "../src/BnetRefunder.sol";

contract BnetRefunderTest is Test {
    BnetRefunder public refunder;

    function setUp() public {
        refunder = new BnetRefunder();
    }

    function test_basic() public {}
}
