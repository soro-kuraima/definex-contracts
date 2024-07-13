// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./AlysNFT.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract AlysNFTMarketplace is ReentrancyGuard {
    using Math for uint256;

    AlysNFT public nftContract;
    address public constant platformFeeRecipient = 0xD7609082E71F01C3B178269C76dF76E087307aAE;

    struct Listing {
        uint256 tokenId;
        address seller;
        uint256 price;
        bool isActive;
    }

    struct Offer {
        address buyer;
        uint256 amount;
        uint256 expirationTime;
    }

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Offer) public offers;

    uint256 public constant OFFER_DURATION = 24 hours;
    uint256 public constant PLATFORM_FEE_PERCENTAGE = 250; // 2.5%
    uint256 public constant PERCENTAGE_BASE = 10000;

    event NFTListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event NFTUnlisted(uint256 indexed tokenId, address indexed seller);
    event OfferMade(uint256 indexed tokenId, address indexed buyer, uint256 amount);
    event OfferCancelled(uint256 indexed tokenId, address indexed buyer);
    event OfferAccepted(uint256 indexed tokenId, address indexed seller, address indexed buyer, uint256 amount);
    event PlatformFeeRecipientUpdated(address indexed oldRecipient, address indexed newRecipient);

    constructor(address _nftContractAddress) {
        nftContract = AlysNFT(_nftContractAddress);
    }

    function listNFT(uint256 _tokenId, uint256 _price) external {
        require(nftContract.ownerOf(_tokenId) == msg.sender, "You don't own this NFT");
        require(nftContract.getApproved(_tokenId) == address(this), "Marketplace not approved");
        
        listings[_tokenId] = Listing({
            tokenId: _tokenId,
            seller: msg.sender,
            price: _price,
            isActive: true
        });

        emit NFTListed(_tokenId, msg.sender, _price);
    }

    function unlistNFT(uint256 _tokenId) external {
        require(listings[_tokenId].seller == msg.sender, "You're not the seller");
        require(listings[_tokenId].isActive, "NFT not listed");

        delete listings[_tokenId];
        emit NFTUnlisted(_tokenId, msg.sender);
    }

    function makeOffer(uint256 _tokenId) external payable nonReentrant {
        require(listings[_tokenId].isActive, "NFT not listed");
        require(msg.value > 0, "Offer amount must be greater than 0");
        require(offers[_tokenId].buyer == address(0) || block.timestamp > offers[_tokenId].expirationTime, "Active offer exists");

        offers[_tokenId] = Offer({
            buyer: msg.sender,
            amount: msg.value,
            expirationTime: block.timestamp + OFFER_DURATION
        });

        emit OfferMade(_tokenId, msg.sender, msg.value);
    }

    function cancelOffer(uint256 _tokenId) external nonReentrant {
        require(offers[_tokenId].buyer == msg.sender, "You're not the offer maker");
        require(block.timestamp <= offers[_tokenId].expirationTime, "Offer expired");

        uint256 offerAmount = offers[_tokenId].amount;
        delete offers[_tokenId];

        (bool success, ) = payable(msg.sender).call{value: offerAmount}("");
        require(success, "Transfer failed");

        emit OfferCancelled(_tokenId, msg.sender);
    }

    function acceptOffer(uint256 _tokenId) external nonReentrant {
        require(listings[_tokenId].seller == msg.sender, "You're not the seller");
        require(listings[_tokenId].isActive, "NFT not listed");
        require(offers[_tokenId].buyer != address(0), "No active offer");
        require(block.timestamp <= offers[_tokenId].expirationTime, "Offer expired");

        address buyer = offers[_tokenId].buyer;
        uint256 offerAmount = offers[_tokenId].amount;
        uint256 platformFee = offerAmount.mulDiv(PLATFORM_FEE_PERCENTAGE, PERCENTAGE_BASE);
        uint256 sellerProceeds = offerAmount - platformFee;

        delete listings[_tokenId];
        delete offers[_tokenId];

        nftContract.transferNFT(buyer, _tokenId);
        
        (bool successSeller, ) = payable(msg.sender).call{value: sellerProceeds}("");
        require(successSeller, "Transfer to seller failed");

        (bool successPlatform, ) = payable(platformFeeRecipient).call{value: platformFee}("");
        require(successPlatform, "Transfer of platform fee failed");

        emit OfferAccepted(_tokenId, msg.sender, buyer, offerAmount);
    }

    function getActiveListing(uint256 _tokenId) external view returns (Listing memory) {
        require(listings[_tokenId].isActive, "NFT not listed");
        return listings[_tokenId];
    }

    function getActiveOffer(uint256 _tokenId) external view returns (Offer memory) {
        require(offers[_tokenId].buyer != address(0) && block.timestamp <= offers[_tokenId].expirationTime, "No active offer");
        return offers[_tokenId];
    }

    receive() external payable {}
}