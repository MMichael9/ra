// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

// Foreclosure Lane contract is purposed for NFT's / Properties that have been liquidated.

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RAACForclosureLane is Ownable, IERC721Receiver {
    using SafeERC20 for IERC20;

    //token interface for RAAC NFTs
    IERC721 public raacInterface;
    IERC20 token;

    enum TokenStatus {
        Auction,
        Sold,
        BoughtBack
    }

    struct TokenData {
        address originalOwner;
        uint256 time;
        uint256 price;
        uint256 buyPrice;
        bool listed;
        uint256 auctionDuration;
        address highestBidder;
        uint256 lastBidTime;
        uint256 totalBids;
        TokenStatus tokenStatus;
    }
    
    mapping(uint256 => TokenData) public tokens;

    constructor(address _raacAddress, address _token) {
        raacInterface = IERC721(_raacAddress);
        token = IERC20(_token);
    }

    function sendForclosure(uint256 _tokenId, address _originalOwner, uint256 _startingPrice) external {
        
        tokens[_tokenId] = TokenData({
            originalOwner: _originalOwner,
            time: block.timestamp,
            price: _startingPrice,
            buyPrice: 100 ether,
            listed: true,
            auctionDuration: 3 days,
            highestBidder: address(0),
            lastBidTime: 0,
            totalBids: 0,
            tokenStatus: TokenStatus.Auction
        });

        //transfer nft to forclosure lane contract       
        raacInterface.safeTransferFrom(msg.sender, address(this), _tokenId);
    }

    function bid(uint256 _tokenId, uint256 _amount) external {
        require(tokens[_tokenId].tokenStatus == TokenStatus.Auction, "Auction Not Live");
        require(tokens[_tokenId].listed, "Token Not Listed");
        require(_amount > tokens[_tokenId].price * 101 / 100, "LowBid");
        uint256 endTime = tokens[_tokenId].time + tokens[_tokenId].auctionDuration;
        require(block.timestamp <= endTime, "Auction Ended");

        //check if bid occurs in last 5 mins
        bool last5 = block.timestamp >= endTime - 5 minutes;

        if(last5) {
            tokens[_tokenId].auctionDuration += 10 minutes;
        }

        tokens[_tokenId].price = _amount;
        tokens[_tokenId].highestBidder = msg.sender;
        tokens[_tokenId].lastBidTime = block.timestamp;
        tokens[_tokenId].totalBids++;
    }


    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}