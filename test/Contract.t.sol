// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import { Test } from "forge-std/Test.sol";
import { FixedPrice } from "../src/FixedPrice.sol";
import { FixedPriceFactory, FixedSettings } from "../src/FixedPriceFactory.sol";
import { Moon } from "./utils/Moon.sol";

contract ContractTest is Test {
    FixedPrice public pool;
    FixedPriceFactory public factory;

    Moon public usdt;
    Moon public pepe;

    address public owner = address(0x01);
    address public create = address(0x02);
    address public user = address(0x03);
    address public operator = address(0x04);
    address public other = address(0xFF);

    uint256 blockTime = 1_714_521_600; // 2024-05-01 00:00:00

    function deploy() public {
        usdt = new Moon("usdt coin", "USDT");
        pepe = new Moon("pepe coin", "PEPE");

        FixedPrice implementation = new FixedPrice();
        factory = new FixedPriceFactory(address(implementation), owner, owner, 300);
        vm.warp(blockTime);
    }

    function create_pool() internal {
        uint88 price = 1e18;
        uint88 buyLimit = 100e18;
        uint88 softCap = 200e18;
        uint88 hardCap = 300e18;

        uint40 saleStart = uint40(blockTime) + 86_400;
        uint40 saleEnd = saleStart + 86_400 * 3;
        pool = FixedPrice(create_pool(price, buyLimit, softCap, hardCap, saleStart, saleEnd));
    }

    function pool_buy() internal {
        vm.warp((pool.saleStart() + pool.saleEnd()) / 2);
        vm.startPrank(user);

        uint256 assetsIn = 10e18;
        usdt.mint(user, assetsIn);
        usdt.approve(address(pool), assetsIn);
        pool.buyShares(assetsIn);
        vm.stopPrank();
    }

    function pool_buy(address buyer) internal {
        vm.startPrank(buyer);
        uint256 assetsIn = pool.buyLimit() * pool.price() / 1e18;
        usdt.mint(buyer, assetsIn);
        usdt.approve(address(pool), assetsIn);
        pool.buyShares(assetsIn);
        vm.stopPrank();
    }

    function pool_close() internal {
        vm.warp(pool.saleEnd());
        pool.close();
    }

    function pool_close_success() internal {
        vm.warp((pool.saleStart() + pool.saleEnd()) / 2);

        vm.startPrank(owner);
        uint256 assetsIn = 100e18 * pool.price() / 1e18;
        usdt.mint(owner, assetsIn);
        usdt.approve(address(pool), assetsIn);
        pool.buyShares(assetsIn);
        vm.stopPrank();

        vm.startPrank(create);
        usdt.mint(create, assetsIn);
        usdt.approve(address(pool), assetsIn);
        pool.buyShares(assetsIn);
        vm.stopPrank();

        vm.startPrank(operator);
        uint256 shares = pool.hardCap();
        pepe.mint(operator, shares);
        pepe.transfer(address(pool), shares);

        vm.warp(pool.saleEnd());
        pool.close();
        vm.stopPrank();
    }

    function pool_redeem() internal {
        vm.startPrank(user);
        pool.redeem(user);
        vm.stopPrank();
    }

    function create_pool(
        uint88 price,
        uint88 buyLimit,
        uint88 softCap,
        uint88 hardCap,
        uint40 saleStart,
        uint40 saleEnd
    )
        internal
        returns (address iPool)
    {
        vm.startPrank(create);

        FixedSettings memory args = FixedSettings({
            asset: address(usdt),
            share: address(pepe),
            creator: create,
            price: price,
            buyLimit: buyLimit,
            softCap: softCap,
            hardCap: hardCap,
            saleStart: saleStart,
            saleEnd: saleEnd,
            whitelistMerkleRoot: 0
        });

        iPool = factory.createFixedPool(args, 0);
        vm.stopPrank();
    }
}
