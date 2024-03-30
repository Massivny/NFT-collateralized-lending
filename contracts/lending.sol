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
    error LendingNft__NotEnoughEth();
    error LendingNft__NotABorrower();
    error LendingNft__AlreadyRepay();

    event UserRequest(
        address indexed user,
        address indexed token,
        uint256 indexed id,
        uint256 requestedPrice,
        uint256 floorPrice
    );

    event Accept(uint256 indexed requestId, uint256 indexed price);

    event ReceiveNft(
        address indexed from,
        address indexed token,
        uint256 tokenId
    );

    event WithdrawNft(
        address indexed to,
        address indexed token,
        uint256 indexed tokenId
    );

    event BorrowEth(
        address indexed user,
        uint256 amount,
        uint256 indexed borrowId
    );

    event RepayLoan(
        address indexed user,
        uint256 indexed borrowId,
        uint256 totalRepay
    );

    enum RequestStatus {
        Pending,
        Accepted,
        Rejected
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

    struct BorrowInstance {
        address user;
        uint256 amount;
        uint256 loanStart;
        uint256 loanEnd;
    }

    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_TRESHOLD = 2e18;
    uint256 private constant DEBT_FEE_PER_DAY = 5e15;
    uint256 private constant DURATION = 1 days;

    address private s_acceptor;

    // mapping(address user => mapping(address nftContract => NftInfo)) users;
    mapping(address user => mapping(address nftContract => mapping(uint256 id => uint256 price))) depositedNfts;
    Request[] private s_requests;
    mapping(address user => Collateral) s_collaterals;
    BorrowInstance[] private s_borrows;
    mapping(address user => uint256[] ids) private s_borrowIds;

    constructor(address acceptor) payable {
        s_acceptor = acceptor;
    }

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

    function withdrawNft(address token, uint256 tokenId) external {
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

    function borrowEth(uint256 _amount) public returns (uint256) {
        if (address(this).balance < _amount) revert LendingNft__NotEnoughEth();

        s_collaterals[msg.sender].borrow += _amount;
        if (checkHealthFactor(msg.sender) < LIQUIDATION_TRESHOLD)
            revert LendingNft__IllHealthFactor();

        s_borrows.push(
            BorrowInstance({
                user: msg.sender,
                amount: _amount,
                loanStart: block.timestamp,
                loanEnd: 0
            })
        );

        uint256 borrowId = s_borrows.length - 1;

        s_borrowIds[msg.sender].push(borrowId);

        emit BorrowEth(msg.sender, _amount, borrowId);

        payable(msg.sender).transfer(_amount);

        return borrowId;
    }

    function repayLoan(uint256 id) external payable {
        if (s_borrows[id].user != msg.sender) revert LendingNft__NotABorrower();
        if (s_borrows[id].loanEnd != 0) revert LendingNft__AlreadyRepay();
        uint256 totalToRepay = needToRepay(id);
        if (totalToRepay > msg.value) revert LendingNft__NotEnoughEth();

        s_collaterals[msg.sender].borrow -= s_borrows[id].amount;
        s_borrows[id].loanEnd = block.timestamp;
        _delete(id);

        emit RepayLoan(msg.sender, id, totalToRepay);
    }

    function needToRepay(uint256 id) public view returns (uint256) {
        uint256 totalDays = ((block.timestamp - s_borrows[id].loanStart) /
            DURATION) + 1;
        uint256 dayFee = (s_borrows[id].amount * DEBT_FEE_PER_DAY) / PRECISION;
        return totalDays * dayFee;
    }

    //  mapping(address user => uint256[] ids) private s_borrowIds;

    function _delete(uint256 _id) private {
        uint256[] storage arr = s_borrowIds[msg.sender];
        uint256 i;
        uint256 len = arr.length;
        for (i = 0; i < len; ++i) {
            if (arr[i] == _id) {
                arr[i] = arr[len - 1];
                arr.pop();
                break;
            }
        }
    }

    function getActualBorrows() external view returns (uint256[]) {
        return s_borrowIds[msg.sender];
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        emit ReceiveNft(from, msg.sender, tokenId);
    }
}
