//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";

contract lnedingNft is IERC721Receiver {

    event invested(address indexed _from, uint amount, uint256 _timestamp);
    event withdrew(address indexed _from, uint amount, uint256 _timestamp);

    

    //Owns a market, Liquidate and moderate the lends
    address owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyModerator(address _to){
        require(msg.sender == owner, "You are not an owner!");
        require(_to != address(0), "Error! Incorrect adress");
        _;
    }


    struct invInfo{
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address investor => invInfo) investors;

    struct NftInfo {
        uint128 id;
        uint128 price;
    }

    mapping(address user => mapping(address nftContract => NftInfo)) users;

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {}

    function deposit() public payable{
        emit invested(msg.sender, msg.value, block.timestamp);

        //?Timestamp? 
        invInfo memory newInv = invInfo(
            msg.value,
            block.timestamp
        );

        investors[msg.sender] = newInv;
    }

    // payable для вызова msg.value
    function withdraw(address payable _to) payable public{
        emit withdrew(msg.sender, msg.value, block.timestamp);

        //TODO Проверка на то что тот кто отправляет запрос на снятие - инвестор
        //require(msg.sender == investors());

        _to.transfer(investors[_to].amount);
    }

    function checkHealthFactor(address _to) internal onlyModerator(_to){
        
    }

    function liquidate(address _to) internal onlyModerator(_to){

    }

    receive() external payable {
        deposit();
    }

    fallback() external payable {}

}
