// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/AlysNFT.sol";
import "../src/AlysNFTMarketplace.sol";

contract AlysNFTMarketplaceTest is Test {
    AlysNFT public nft;
    AlysNFTMarketplace public marketplace;
    address public owner;
    address public seller;
    address public buyer;

    uint256 constant INITIAL_BALANCE = 100 ether;
    uint256 constant NFT_PRICE = 1 ether;
    uint256 constant OFFER_AMOUNT = 0.8 ether;

    function setUp() public {
        owner = address(this);
        seller = makeAddr("seller");
        buyer = makeAddr("buyer");

        // Deploy contracts
        nft = new AlysNFT(owner);
        marketplace = new AlysNFTMarketplace(address(nft));

        // Set up initial balances
        vm.deal(seller, INITIAL_BALANCE);
        vm.deal(buyer, INITIAL_BALANCE);

        // Mint an NFT for the seller
        vm.prank(seller);
        nft.createNFT{value: NFT_PRICE}(seller, "ipfs://example", NFT_PRICE, "TEST", 1);

        // Verify NFT ownership
        assertEq(nft.ownerOf(0), seller, "Seller should own the NFT after minting");
    }

    function testListNFT() public {
        uint256 tokenId = 0;
        
        vm.startPrank(seller);
        nft.approve(address(marketplace), tokenId);
        marketplace.listNFT(tokenId, NFT_PRICE);
        vm.stopPrank();

        AlysNFTMarketplace.Listing memory listing = marketplace.getActiveListing(tokenId);
        assertEq(listing.seller, seller);
        assertEq(listing.price, NFT_PRICE);
        assertTrue(listing.isActive);
    }

    function testFailListNFTNotOwner() public {
        uint256 tokenId = 0;
        
        vm.prank(buyer);
        marketplace.listNFT(tokenId, NFT_PRICE);
    }

    function testUnlistNFT() public {
        uint256 tokenId = 0;
        
        vm.startPrank(seller);
        nft.approve(address(marketplace), tokenId);
        marketplace.listNFT(tokenId, NFT_PRICE);
        marketplace.unlistNFT(tokenId);
        vm.stopPrank();

        vm.expectRevert("NFT not listed");
        marketplace.getActiveListing(tokenId);
    }

    function testMakeOffer() public {
        uint256 tokenId = 0;
        
        vm.startPrank(seller);
        nft.approve(address(marketplace), tokenId);
        marketplace.listNFT(tokenId, NFT_PRICE);
        vm.stopPrank();

        vm.prank(buyer);
        marketplace.makeOffer{value: OFFER_AMOUNT}(tokenId);

        AlysNFTMarketplace.Offer memory offer = marketplace.getActiveOffer(tokenId);
        assertEq(offer.buyer, buyer);
        assertEq(offer.amount, OFFER_AMOUNT);
    }

    function testAcceptOffer() public {
        uint256 tokenId = 0;
        
        vm.startPrank(seller);
        nft.approve(address(marketplace), tokenId);
        marketplace.listNFT(tokenId, NFT_PRICE);
        vm.stopPrank();

        vm.prank(buyer);
        marketplace.makeOffer{value: OFFER_AMOUNT}(tokenId);

        uint256 sellerInitialBalance = seller.balance;
        
        vm.prank(seller);
        marketplace.acceptOffer(tokenId);

        assertEq(nft.ownerOf(tokenId), buyer);
        assertGt(seller.balance, sellerInitialBalance);
    }

    function testCancelOffer() public {
        uint256 tokenId = 0;
        
        vm.startPrank(seller);
        nft.approve(address(marketplace), tokenId);
        marketplace.listNFT(tokenId, NFT_PRICE);
        vm.stopPrank();

        uint256 buyerInitialBalance = buyer.balance;

        vm.prank(buyer);
        marketplace.makeOffer{value: OFFER_AMOUNT}(tokenId);

        vm.prank(buyer);
        marketplace.cancelOffer(tokenId);

        assertEq(buyer.balance, buyerInitialBalance);

        vm.expectRevert("No active offer");
        marketplace.getActiveOffer(tokenId);
    }

    function testOfferExpiration() public {
        uint256 tokenId = 0;
        
        vm.startPrank(seller);
        nft.approve(address(marketplace), tokenId);
        marketplace.listNFT(tokenId, NFT_PRICE);
        vm.stopPrank();

        vm.prank(buyer);
        marketplace.makeOffer{value: OFFER_AMOUNT}(tokenId);

        // Fast forward time by 25 hours
        vm.warp(block.timestamp + 25 hours);

        vm.expectRevert("Offer expired");
        vm.prank(seller);
        marketplace.acceptOffer(tokenId);
    }
}