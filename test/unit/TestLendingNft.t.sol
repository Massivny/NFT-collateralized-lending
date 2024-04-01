//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {LendingNft} from "../../contracts/lending.sol";
import {DeployLendingNft} from "../../script/DeployLendingNft.s.sol";
import {ERC721Mock} from "../mocks/ERC721Mock.sol";

contract TestLendingNft is Test {
    LendingNft public lendingNft;
    address user1 = makeAddr("user1");
    address acceptor = makeAddr("acceptor");

    struct Configs {
        address user;
        uint256 key;
        address nftContract;
    }

    Configs public configs;

    function setUp() external {
        DeployLendingNft dl = new DeployLendingNft();
        lendingNft = dl.run();
        if (block.chainid == 168587773) {
            configs.user = vm.envAddress("USER_ADDRESS_BLAST");
            configs.nftContract = vm.envAddress("NFT_CONTRACT_BLAST");
        } else {
            configs.user = vm.envAddress("USER_ADDRESS_ANVIL");
            ERC721Mock nft = new ERC721Mock(configs.user, "NFTFI", "NFI");
            configs.nftContract = address(nft);
        }
        (bool s, ) = address(lendingNft).call{value: 1 ether}("");
        require(s);
    }

    function testRequestDepositNft() public {
        vm.startPrank(configs.user);
        lendingNft.requestDepositNft(configs.nftContract, 2, 3e15, 1e15);
        vm.stopPrank();
        LendingNft.Request memory rq = lendingNft.getLastRequest();

        assertEq(rq.user, configs.user);
        assertEq(rq.nftContract, configs.nftContract);
        assertEq(rq.id, 2);
        assertEq(rq.requestedPrice, 3e15);
        assertEq(rq.floorPrice, 1e15);
        assertEq(uint(rq.status), uint(LendingNft.RequestStatus.Pending));
    }

    function testAcceptRequest() public {
        uint256 numberOfNfts = ERC721Mock(configs.nftContract).balanceOf(
            configs.user
        );

        vm.startPrank(configs.user);
        ERC721Mock(configs.nftContract).setApprovalForAll(
            address(lendingNft),
            true
        );
        lendingNft.requestDepositNft(configs.nftContract, 2, 3e15, 1e15);
        vm.stopPrank();

        vm.startPrank(acceptor);
        lendingNft.acceptDepositAndTransferNft(0, 1e15);
        vm.stopPrank();

        assertEq(
            ERC721Mock(configs.nftContract).balanceOf(address(lendingNft)),
            1
        );
        assertEq(
            ERC721Mock(configs.nftContract).balanceOf(configs.user),
            numberOfNfts - 1
        );

        vm.startPrank(configs.user);
        uint256 price = lendingNft.getPriceOfDepositedNft(
            configs.nftContract,
            2
        );
        uint256 deposit = lendingNft.detBalances().deposit;
        vm.stopPrank();

        assertEq(price, 1e15);
        assertEq(deposit, 1e15);
    }

    function testWithdrawNft() public {
        uint256 numberOfNfts = ERC721Mock(configs.nftContract).balanceOf(
            configs.user
        );

        vm.startPrank(configs.user);
        ERC721Mock(configs.nftContract).setApprovalForAll(
            address(lendingNft),
            true
        );
        lendingNft.requestDepositNft(configs.nftContract, 2, 3e15, 1e15);
        vm.stopPrank();

        vm.startPrank(acceptor);
        lendingNft.acceptDepositAndTransferNft(0, 1e15);
        vm.stopPrank();

        vm.startPrank(configs.user);
        lendingNft.withdrawNft(configs.nftContract, 2);
        vm.stopPrank();

        assertEq(
            ERC721Mock(configs.nftContract).balanceOf(address(lendingNft)),
            0
        );
        assertEq(
            ERC721Mock(configs.nftContract).balanceOf(configs.user),
            numberOfNfts
        );
    }

    function testBorrowEth() public {
        vm.deal(configs.user, 0);
        vm.startPrank(configs.user);
        ERC721Mock(configs.nftContract).setApprovalForAll(
            address(lendingNft),
            true
        );
        lendingNft.requestDepositNft(configs.nftContract, 2, 3e15, 1e15);
        vm.stopPrank();

        vm.startPrank(acceptor);
        lendingNft.acceptDepositAndTransferNft(0, 1e15);
        vm.stopPrank();

        vm.startPrank(configs.user);
        lendingNft.borrowEth(5e14);
        uint256 borrow = lendingNft.detBalances().borrow;
        vm.stopPrank();

        assertEq(address(lendingNft).balance, 1 ether - 5e14);
        assertEq(configs.user.balance, 5e14);
        assertEq(borrow, 5e14);
    }

    function testRepayLoan() public {
        vm.deal(configs.user, 3e15);

        vm.startPrank(configs.user);
        ERC721Mock(configs.nftContract).setApprovalForAll(
            address(lendingNft),
            true
        );
        lendingNft.requestDepositNft(configs.nftContract, 2, 3e15, 1e15);
        vm.stopPrank();

        vm.startPrank(acceptor);
        lendingNft.acceptDepositAndTransferNft(0, 1e15);
        vm.stopPrank();

        vm.startPrank(configs.user);
        uint256 borrowId = lendingNft.borrowEth(5e14);
        vm.stopPrank();

        uint256 repay = lendingNft.needToRepay(borrowId);

        vm.startPrank(configs.user);
        lendingNft.repayLoan{value: repay}(borrowId);
        uint256 borrow = lendingNft.detBalances().borrow;
        vm.stopPrank();

        assertEq(configs.user.balance, 3e15 - repay + 5e14);
        assertEq(borrow, 0);
    }
}
