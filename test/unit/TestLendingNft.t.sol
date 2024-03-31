//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {LendingNft} from "../../contracts/lending.sol";
import {DeployLendingNft} from "../../script/DeployLendingNft.s.sol";

contract TestLendingNft is Test {
    LendingNft public lendingNft;
    address user1 = makeAddr("user1");

    function setUp() external {
        DeployLendingNft dl = new DeployLendingNft();
        dl.run();
    }
}

// 0x4197abCfbc708Bb011488E175d2131bC366aabC4 - address NFT contract

// function testRequestDepositNft() public {}
