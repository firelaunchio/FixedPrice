// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import { console } from "forge-std/Test.sol";
import { ContractTest } from "./Contract.t.sol";

contract RedeemTest is ContractTest {
    function setUp() public {
        deploy();
        create_pool();
        pool_buy();
        pool_close();
    }

    function test_redeem() public {
        pool_redeem();
    }

    function test_redeemUsdt() public {
        vm.startPrank(user);
        uint256 beforeBalanceOf = usdt.balanceOf(user);
        uint256 assets = pool.redeem(user);
        uint256 afterBalanceOf = usdt.balanceOf(user);
        vm.stopPrank();

        console.log("beforeBalanceOf:%d", beforeBalanceOf);
        console.log("assets:%d", assets);
        console.log("afterBalanceOf:%d", afterBalanceOf);
        assertEq(beforeBalanceOf + assets, afterBalanceOf);
    }

    function test_redeemZero() public {
        vm.startPrank(other);
        uint256 shares = pool.redeem(user);
        vm.stopPrank();
        console.log("shares:%d", shares);
        assertEq(shares, 0);
    }

    function testFail_closeAlready() public {
        pool_close();
    }
}
