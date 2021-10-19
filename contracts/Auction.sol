// SPDX-License-Identifier: MIT
pragma solidity ^0.5.0;

import "./interfaces/IKIP7.sol";
import "./interfaces/IKIP17.sol";
import "./library/SafeMath.sol";
import "./interfaces/IWKLAY.sol";

contract Auction {
    using SafeMath for uint;

    bytes4 internal constant ON_ERC721_RECEIVED = 0x150b7a02;
    bytes4 private constant _KIP7_RECEIVED = 0x9d188c22;

    address public wklay = 0xf223E26B018AE1917E84DD73b515620e36a75596;

    address public admin;

    uint public maxAuctionIndex;

    struct AuctionInfo {
        IKIP17 bidNft;
        address beneficiary;
        address currentBidAddress;
        uint bidTokenId;
        uint32 endBlock;
        uint224 currentBidAmount;
    }

    mapping(address => mapping(uint => uint)) public bidAmounts;
    AuctionInfo[] public auctionInfos;

    mapping(uint => uint) public auctionIdToIndex;

    event NewAuction(
        uint indexed auctionIndex,
        uint indexed auctionId,
        address indexed bidNftAddress,
        address beneficiary,
        uint bidTokenId,
        uint endBlock,
        uint minimumBidAmount);

    event Bid(
        uint indexed auctionIndex,
        uint indexed auctionId,
        address indexed account,
        uint amount);

    event Claim(
        uint indexed auctionIndex,
        uint indexed auctionId,
        address indexed account);

    event NewAdmin(address newAdmin);

    constructor () public {
        admin = msg.sender;
        maxAuctionIndex = 1;

        auctionInfos.push(AuctionInfo(
            IKIP17(address(0)),
            address(0),
            address(0),
            0,
            0,
            0));
    }

    function setAdmin(address newAdmin) public {
        require(msg.sender == admin, "admin");
        admin = newAdmin;
        emit NewAdmin(admin);
    }

    function addAuctionIndex() public {
        require(msg.sender == admin, "admin");
        maxAuctionIndex++;
    }

    function createAuction(
        uint auctionIndex,
        address bidNftAddress,
        address beneficiary,
        uint bidTokenId,
        uint endBlock,
        uint minimumBidAmount
    ) public {

        require(auctionIndex <= maxAuctionIndex, "index");

        IKIP17 bidNft = IKIP17(bidNftAddress);
        bidNft.safeTransferFrom(msg.sender, address(this), bidTokenId);

        auctionInfos.push(AuctionInfo(
            bidNft,
            beneficiary,
            address(0),
            bidTokenId,
            safe32(endBlock),
            safe224(minimumBidAmount)));

        uint currentAuctionId = auctionInfos.length - 1;
        bidAmounts[beneficiary][currentAuctionId] = 1;
        auctionIdToIndex[currentAuctionId] = auctionIndex;

        emit NewAuction(
            auctionIndex,
            currentAuctionId,
            bidNftAddress,
            beneficiary,
            bidTokenId,
            endBlock,
            minimumBidAmount);

    }

    function bid(
        uint auctionId,
        uint bidAmount
    ) public payable {
        AuctionInfo storage auctionInfo = auctionInfos[auctionId];
        require(msg.sender != auctionInfo.beneficiary, "beneficiary");
        require(block.number < auctionInfo.endBlock, "over");
        uint payAmount = bidAmount.sub(bidAmounts[msg.sender][auctionId]);
        require(auctionInfo.currentBidAmount < bidAmount && msg.value == payAmount, "bid amount");

        IWKLAY(wklay).deposit.value(payAmount)();

        bidAmounts[msg.sender][auctionId] = bidAmount;

        auctionInfo.currentBidAmount = safe224(bidAmount);
        auctionInfo.currentBidAddress = msg.sender;

        emit Bid(
            auctionIdToIndex[auctionId],
            auctionId,
            msg.sender,
            bidAmount);
    }

    function claim(
        uint auctionId
    ) public {
        AuctionInfo storage auctionInfo = auctionInfos[auctionId];
        require(bidAmounts[msg.sender][auctionId] > 0, "only once");

        emit Claim(
            auctionIdToIndex[auctionId],
            auctionId,
            msg.sender);

        if(msg.sender != auctionInfo.currentBidAddress && msg.sender != auctionInfo.beneficiary) {

            uint bidAmount = bidAmounts[msg.sender][auctionId];
            delete bidAmounts[msg.sender][auctionId];

            IWKLAY(wklay).withdraw(bidAmount);
            msg.sender.transfer(bidAmount);
            return;
        }

        require(block.number >= auctionInfo.endBlock, "not over");
        delete bidAmounts[msg.sender][auctionId];

        if(msg.sender == auctionInfo.beneficiary && auctionInfo.currentBidAddress != address(0)) {

            IWKLAY(wklay).withdraw(auctionInfo.currentBidAmount);
            msg.sender.transfer(auctionInfo.currentBidAmount);

            return;
        }

        auctionInfo.bidNft.safeTransferFrom(address(this), msg.sender, auctionInfo.bidTokenId);

    }

    function safe224(uint amount) internal pure returns (uint112) {
        require(amount < 2**224, "224");
        return uint112(amount);
    }

    function safe32(uint amount) internal pure returns (uint32) {
        require(amount < 2**32, "32");
        return uint32(amount);
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4) {
        return ON_ERC721_RECEIVED;
    }

    function onKIP7Received(address _operator, address _from, uint256 _amount, bytes calldata _data) external returns (bytes4) {
        return _KIP7_RECEIVED;
    }

    function () external payable {
        assert(msg.sender == wklay);
    }
}