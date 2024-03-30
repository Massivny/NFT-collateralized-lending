//SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";

contract LendingNft is IERC721Receiver {
    error LendingNft__NotAnOwnerOfTokenId();
    error LendingNft__NotAnAcceptor();
    error LendingNft__ErrorPrice();
    error LendingNft__NotSuchNft(address token, uint256 tokenId);
    error LendingNft__IllHealthFactor();
    error LendingNft_NotAnInvestor();

    event invested(
        address indexed _from, 
        uint256 indexed amount, 
        uint256 _timestamp
    );
    
    event withdrew(
        address indexed _to,
        uint256 indexed amount, 
        uint256 _timestamp
    );

    event Liquidation(
        uint256 indexed requestId, 
        address indexed liquidator, 
        uint256 collateralAmount,
        uint256 liquidationTime
    );
    
    event UserRequest(
        address indexed user,
        address indexed token,
        uint256 indexed id,
        uint256 duration,
        uint256 requestedPrice,
        uint256 floorPrice
    );

    event Accept(
        uint256 indexed requestId, 
        uint256 indexed price
    );

    event ReceiveNft(
        address indexed from,
        address indexed token,
        uint256 indexed tokenId
    );

    event WithdrawNft(
        address indexed to,
        address indexed token,
        uint256 indexed tokenId
    );

    //Owns a market, Liquidate and moderate the lends
    address owner;
    address private s_acceptor;
    
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_TRESHOLD = 2e18;
    uint256 private constant FEE = 3;

    constructor(address acceptor) payable {
        owner = msg.sender;
        s_acceptor = acceptor;
    }

    modifier onlyModerator(){
        require(msg.sender == s_acceptor, "You are not an acceptor!");
        _;
    }

    struct invInfo{
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => bool) addressInvestorExist;

    mapping(address investor => invInfo) investors;

    struct NftInfo {
        uint128 id;
        uint128 price;
    }

    enum RequestStatus {
        Pending,
        Accepted,
        Rejected,
        Liquidated
    }

    struct Request {
        address user;
        address nftContract;
        uint256 id;
        uint256 requestedPrice;
        uint256 floorPrice;
        RequestStatus status;
    }

    struct Collateral {
        uint256 deposit;
        uint256 borrow;
    }

    // mapping(address user => mapping(address nftContract => NftInfo)) users;
    mapping(address user => mapping(address nftContract => mapping(uint256 id => uint256 price))) depositedNfts;
    Request[] private s_requests;
    mapping(address user => Collateral) s_collaterals;

    function requestDepositNft(
        address tokenAddr,
        uint256 tokenId,
        uint256 _requestedPrice,
        uint256 _floorPrice
    ) external {
        if (IERC721(tokenAddr).ownerOf(tokenId) != msg.sender)
            revert LendingNft__NotAnOwnerOfTokenId();

        s_requests.push(
            Request({
                user: msg.sender,
                nftContract: tokenAddr,
                id: tokenId,
                requestedPrice: _requestedPrice,
                floorPrice: _floorPrice,
                status: RequestStatus.Pending
            })
        );

        emit UserRequest(
            msg.sender,
            tokenAddr,
            tokenId,
            _requestedPrice,
            _floorPrice
        );
    }

    function acceptDepositAndTransferNft(
        uint256 requestId,
        uint256 price
    ) external {
        if (msg.sender != s_acceptor) revert LendingNft__NotAnAcceptor();
        Request memory request = s_requests[requestId];

        if (price < request.floorPrice) revert LendingNft__ErrorPrice();

        request.status = RequestStatus.Accepted;
        depositedNfts[request.user][request.nftContract][request.id] = price;
        s_collaterals[request.user].deposit += price;

        emit Accept(requestId, price);

        IERC721(request.nftContract).safeTransferFrom(
            request.user,
            address(this),
            request.id
        );
    }

    function withdrawNft(address token, uint256 tokenId) public {
        uint256 price = depositedNfts[msg.sender][token][tokenId];
        if (price == 0) revert LendingNft__NotSuchNft(token, tokenId);

        s_collaterals[msg.sender].deposit -= price;
        if (checkHealthFactor(msg.sender) < LIQUIDATION_TRESHOLD)
            revert LendingNft__IllHealthFactor();
        delete depositedNfts[msg.sender][token][tokenId];

        emit WithdrawNft(msg.sender, token, tokenId);

        IERC721(token).transferFrom(address(this), msg.sender, tokenId);
    }

    function checkHealthFactor(
        address user
    ) public view returns (uint256 healthFactor) {
        if (s_collaterals[user].borrow == 0) {
            healthFactor = s_collaterals[user].deposit;
        } else {
            healthFactor =
                (s_collaterals[user].deposit * PRECISION) /
                s_collaterals[user].borrow;
        }
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {}

    function deposit() public payable{
        //?Timestamp? 
        invInfo memory newInv = invInfo(
            msg.value - ((msg.value * FEE) / 100),
            block.timestamp
        );

        investors[msg.sender] = newInv;
        addressInvestorExist[msg.sender] = true;

        emit invested(msg.sender, msg.value, block.timestamp);
    }

    // payable для вызова msg.value
    function withdraw(address payable _to, uint256 amount) payable public{
        if(!(addressInvestorExist[_to])) revert LendingNft_NotAnInvestor();
        if(amount > investors[_to].amount) revert LendingNft__ErrorPrice();
        if(amount >)

        _to.transfer(amount);

        if(investors[_to].amount == 0)
        {
            delete investors[_to];
            delete addressInvestorExist[_to];
        }
        else 
        {
            investors[_to].amount -= amount;
        }
        emit withdrew(msg.sender, amount, block.timestamp);
    }

    function checkInvestitionBalance(
        address _investor
    ) public view returns(uint256 depositWithRewards){
        require(addressInvestorExist[_investor], "You are not an investor!");

        depositWithRewards = investors[_investor].amount;
    }

    function liquidate(
        address liquidator, 
        address user,
        uint256 requestId
        ) internal{
        if (msg.sender != s_acceptor) revert LendingNft__NotAnAcceptor();
        
        Request memory request = s_requests[requestId];

        require(request.status != RequestStatus.Liquidated, "Position is already liquidated");
        require(request.user != liquidator, "Cant liquidate your own position");

        if(checkHealthFactor(user) < LIQUIDATION_TRESHOLD)
        {
            IERC721(request.nftContract).safeTransferFrom(
                address(this),
                msg.sender,
                request.id
            );
            uint256 collaterallAmount = s_collaterals[request.user].deposit;
            s_collaterals[request.user].deposit = 0;
            liquidator.transfer(collaterallAmount)
            request.status = RequestStatus.Liquidated;
            emit Liquidation(requestId, msg.sender, collaterallAmount, block.timestamp);
        }
    }

    receive() external payable {
        deposit();
    }

    fallback() external payable {}

}
