// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {MockV3Aggregator} from "test/mock/MockV3Aggregator.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";
import {FundFundMe, WithdrawFundMe} from "../../script/Interactions.s.sol";
import {FundMe} from "../../src/FundMe.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {ZkSyncChainChecker} from "lib/foundry-devops/src/ZkSyncChainChecker.sol";

contract InteractionsTest is ZkSyncChainChecker, StdCheats, Test {
    FundMe public fundMe;
    HelperConfig public helperConfig;

    uint256 public constant SEND_VALUE = 0.1 ether; // just a value to make sure we are sending enough!
    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    uint256 public constant GAS_PRICE = 1;

    address public constant USER = address(1);

    // uint256 public constant SEND_VALUE = 1e18;
    // uint256 public constant SEND_VALUE = 1_000_000_000_000_000_000;
    // uint256 public constant SEND_VALUE = 1000000000000000000;

    function setUp() external skipZkSync {
        if (!isZkSyncChain()) {
            DeployFundMe deployer = new DeployFundMe();
            (fundMe, helperConfig) = deployer.deployFundMe();
        } else {
            helperConfig = new HelperConfig();
            fundMe = new FundMe(
                helperConfig.getConfigByChainId(block.chainid).priceFeed
            );
        }
        vm.deal(USER, STARTING_USER_BALANCE);
    }

    function testUserCanFundAndOwnerWithdraw() public skipZkSync {
        // 1. Estimate gas cost for fundMe.fund
        uint256 gasStart = gasleft();
        fundMe.fund{value: SEND_VALUE}();
        uint256 expectedGasCost = gasStart - gasleft();

        // 2. Get initial balances
        uint256 preUserBalance = address(USER).balance;
        uint256 preOwnerBalance = address(fundMe.getOwner()).balance;

        // 3. Simulate funding with vm.prank
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();

        // 4. Withdraw funds using WithdrawFundMe
        WithdrawFundMe withdrawFundMe = new WithdrawFundMe();
        withdrawFundMe.withdrawFundMe(address(fundMe));

        // 5. Get final balances
        uint256 afterUserBalance = address(USER).balance;
        uint256 afterOwnerBalance = address(fundMe.getOwner()).balance;

        // 6. Assert fundMe balance is zero
        assert(address(fundMe).balance == 0);

        // 7. Assert user balance considering gas
        assertEq(
            afterUserBalance + SEND_VALUE,
            preUserBalance - expectedGasCost
        );

        // 8. Assert owner balance considering gas
        assertEq(
            afterOwnerBalance,
            preOwnerBalance + SEND_VALUE - expectedGasCost
        );
    }

    // function testUserCanFundAndOwnerWithdraw() public skipZkSync {
    //     uint256 preUserBalance = address(USER).balance;
    //     uint256 preOwnerBalance = address(fundMe.getOwner()).balance;

    //     // Using vm.prank to simulate funding from the USER address
    //     vm.prank(USER);
    //     fundMe.fund{value: SEND_VALUE}();

    //     WithdrawFundMe withdrawFundMe = new WithdrawFundMe();
    //     withdrawFundMe.withdrawFundMe(address(fundMe));

    //     uint256 afterUserBalance = address(USER).balance;
    //     uint256 afterOwnerBalance = address(fundMe.getOwner()).balance;

    //     assert(address(fundMe).balance == 0);
    //     assertEq(afterUserBalance + SEND_VALUE, preUserBalance);
    //     assertEq(preOwnerBalance + SEND_VALUE, afterOwnerBalance);
    // }
}
