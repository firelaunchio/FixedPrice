// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import { ContractTest } from "./Contract.t.sol";

contract PoolTest is ContractTest {
    function setUp() public {
        deploy();
    }

    function test_create() public {
        create_pool();
    }

    function testFail_createExist() public {
        uint88 price = 1e18;
        uint88 buyLimit = 100e18;
        uint88 softCap = 200e18;
        uint88 hardCap = 300e18;

        uint40 saleStart = uint40(blockTime);
        uint40 saleEnd = saleStart + 86_400 * 3;
        create_pool(price, buyLimit, softCap, hardCap, saleStart, saleEnd);
        create_pool(price, buyLimit, softCap, hardCap, saleStart, saleEnd);
    }

    function testFail_createTime() public {
        uint88 price = 1e18;
        uint88 buyLimit = 100e18;
        uint88 softCap = 200e18;
        uint88 hardCap = 300e18;

        uint40 saleStart = uint40(blockTime);
        uint40 saleEnd = saleStart + 86_400 - 1;
        create_pool(price, buyLimit, softCap, hardCap, saleStart, saleEnd);
    }
}
