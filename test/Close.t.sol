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

    function test_closeSuccess() public {
        pool_close_success();
    }

    function testFail_closeTime() public {
        pool.close();
    }

    function testFail_Redeem() public {
        pool_redeem();
    }
}
