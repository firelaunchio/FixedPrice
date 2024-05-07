// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import { console } from "forge-std/Test.sol";
import { ContractTest } from "./Contract.t.sol";

contract BuyTest is ContractTest {
    function setUp() public {
        deploy();
        create_pool();
    }

    function test_buy() public {
        pool_buy();
    }

    function testFail_swapDisallowedStart() public {
        vm.warp(pool.saleStart() - 1);
        vm.startPrank(user);
        uint256 assetsIn = 100e18;
        usdt.mint(user, assetsIn);
        usdt.approve(address(pool), assetsIn);

        pool.buyShares(assetsIn);
        vm.stopPrank();
    }

    function testFail_swapDisallowedEnd() public {
        vm.warp(pool.saleEnd());
        vm.startPrank(user);
        uint256 assetsIn = 100e18;
        usdt.mint(user, assetsIn);
        usdt.approve(address(pool), assetsIn);

        pool.buyShares(assetsIn);
        vm.stopPrank();
    }

    function test_hardCap() public {
        vm.warp(pool.saleStart());
        pool_buy(owner);
        pool_buy(create);
        pool_buy(user);
    }

    function testFail_hardCap() public {
        vm.warp(pool.saleStart());
        pool_buy(owner);
        pool_buy(create);
        pool_buy(user);
        pool_buy(other);
    }

    function testFail_swapBuyLimit() public {
        vm.warp(pool.saleStart());
        vm.startPrank(user);
        uint256 assetsIn = pool.buyLimit() * pool.price() / 1e18 + 1;
        usdt.mint(user, assetsIn);
        usdt.approve(address(pool), assetsIn);

        pool.buyShares(assetsIn);
        vm.stopPrank();
    }

    function test_swapExactAssetsForShares() public {
        vm.startPrank(user);
        uint256 beforeBalanceOf = pepe.balanceOf(user);
        uint256 beforeShares = pool.purchasedShares(user);

        vm.warp(pool.saleStart());
        uint256 assetsIn = 100e18;
        usdt.mint(user, assetsIn);

        usdt.approve(address(pool), assetsIn);

        uint256 sharesOut = pool.buyShares(assetsIn);
        uint256 afterBalanceOf = pepe.balanceOf(user);
        uint256 afterShares = pool.purchasedShares(user);
        vm.stopPrank();

        console.log("beforeShares:%d", beforeShares);
        console.log("sharesOut:%d", sharesOut);
        console.log("afterShares:%d", afterShares);
        assertEq(beforeBalanceOf, afterBalanceOf);
        assertEq(beforeShares + sharesOut, afterShares);
    }
}
