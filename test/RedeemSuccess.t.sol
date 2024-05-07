// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import { console } from "forge-std/Test.sol";
import { ContractTest } from "./Contract.t.sol";

contract RedeemTest is ContractTest {
    function setUp() public {
        deploy();
        create_pool();
        pool_buy();
        pool_close_success();
    }

    function test_redeem() public {
        pool_redeem();
    }

    function test_redeemBalance() public {
        vm.startPrank(user);
        uint256 beforeBalanceOf = pepe.balanceOf(user);
        uint256 shares = pool.redeem(user);
        uint256 afterBalanceOf = pepe.balanceOf(user);
        vm.stopPrank();

        console.log("beforeBalanceOf:%d", beforeBalanceOf);
        console.log("shares:%d", shares);
        console.log("afterBalanceOf:%d", afterBalanceOf);
        assertEq(beforeBalanceOf + shares, afterBalanceOf);
    }
}
