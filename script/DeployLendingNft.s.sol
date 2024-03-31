//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {LendingNft} from "../contracts/lending.sol";

contract DeployLendingNft is Script {
    function run() external returns (LendingNft) {
        address acceptor = makeAddr("acceptor");
        vm.startBroadcast();
        LendingNft lendingNft = new LendingNft(acceptor);
        vm.stopBroadcast();
        return lendingNft;
    }
}
