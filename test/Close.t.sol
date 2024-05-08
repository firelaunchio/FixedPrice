// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import { ContractTest } from "./Contract.t.sol";

contract CloseTest is ContractTest {
    function setUp() public {
        deploy();
        create_pool();
        pool_buy();
    }

    function test_close() public {
        pool_close();
    }

    function test_closeShares() public {
        vm.warp(pool.saleEnd());
        uint256 shares = pool.hardCap();
        pepe.mint(address(pool), shares);

        uint256 beforeBalanceOf = pepe.balanceOf(create);
        pool.close();

        uint256 afterBalanceOf = pepe.balanceOf(create);
        uint256 poolBalanceOf = pepe.balanceOf(address(pool));
        assertEq(beforeBalanceOf + shares, afterBalanceOf);
        assertEq(0, poolBalanceOf);
    }

    function test_closeSuccess() public {
        pool_close_success();
    }

    function test_closeSharesBalanceOf() public {
        pool_buy(owner);
        pool_buy(create);
        vm.startPrank(operator);
        vm.warp(pool.saleEnd());
        uint256 shares = pool.hardCap();
        pepe.mint(address(pool), shares);
        pool.close();
        vm.stopPrank();
    }

    function test_closeSuccessShareBalanceOf() public {
        pool_buy(owner);
        pool_buy(create);
        vm.startPrank(operator);
        vm.warp(pool.saleEnd());
        uint256 shares = pool.hardCap();
        pepe.mint(address(pool), shares);
        uint256 beforeBalanceOf = pepe.balanceOf(create);

        pool.close();
        uint256 afterBalanceOf = pepe.balanceOf(create);
        uint256 poolBalanceOf = pepe.balanceOf(address(pool));
        vm.stopPrank();
        assertEq(beforeBalanceOf + shares - pool.totalSales(), afterBalanceOf);
        assertEq(pool.totalSales(), poolBalanceOf);
    }

    function test_closeSuccessAssetBalanceOf() public {
        pool_buy(owner);
        pool_buy(create);
        vm.startPrank(operator);
        vm.warp(pool.saleEnd());
        uint256 shares = pool.hardCap();
        pepe.mint(address(pool), shares);
        uint256 beforeCreate = usdt.balanceOf(create);
        uint256 beforeOwner = usdt.balanceOf(owner);
        uint256 saleUsdt = usdt.balanceOf(address(pool));

        pool.close();
        uint256 afterCreate = usdt.balanceOf(create);
        uint256 afterOwner = usdt.balanceOf(owner);
        uint256 poolBalanceOf = usdt.balanceOf(address(pool));
        vm.stopPrank();
        uint256 fee = saleUsdt * pool.platformFee() / 1e18;

        assertEq(0, poolBalanceOf);
        assertEq(beforeOwner + fee, afterOwner);
        assertEq(beforeCreate + saleUsdt - fee, afterCreate);
    }

    function testFail_closeSharesBalanceOf() public {
        pool_buy(owner);
        pool_buy(create);
        vm.startPrank(operator);
        vm.warp(pool.saleEnd());
        pool.close();
        vm.stopPrank();
    }

    function testFail_closeTime() public {
        pool.close();
    }

    function testFail_Redeem() public {
        pool_redeem();
    }
}
