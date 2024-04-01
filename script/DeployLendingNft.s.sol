//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {LendingNft} from "../contracts/lending.sol";

contract DeployLendingNft is Script {
    function run() external returns (LendingNft) {
        vm.startBroadcast();
        LendingNft lendingNft = new LendingNft(vm.envAddress("ACCEPTOR"));
        vm.stopBroadcast();
        return lendingNft;
    }
}
