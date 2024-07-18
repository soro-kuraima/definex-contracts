// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/AlysNFTP2PMarket.sol";
import "../src/AlysNFT.sol";

contract AlysNFTP2PMarketTest is Test {
    AlysNFTP2PMarket public market;
    AlysNFT public nft;
    address public owner;
    address public user1;
    address public user2;
    address public user3;

    uint256 constant MINT_PRICE = 1 ether;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        user3 = address(0x3);

        nft = new AlysNFT(owner);
        market = new AlysNFTP2PMarket(address(nft));

        vm.deal(user1, 1000 ether);
        vm.deal(user2, 1000 ether);
        vm.deal(user3, 1000 ether);
        vm.deal(address(this), 1000 ether);
    }

    function testListNFT() public {
        uint256 tokenId = nft.createNFT{value: MINT_PRICE}(user1, "uri", MINT_PRICE, "TICKER", 100);
        vm.startPrank(user1);
        nft.approve(address(market), tokenId);
        market.listNFT(tokenId, 2 ether);
        vm.stopPrank();

        AlysNFTP2PMarket.Listing memory listing = market.getActiveListing(tokenId);
        assertEq(listing.seller, user1);
        assertEq(listing.price, 2 ether);
        assertTrue(listing.isActive);
    }

    function testUnlistNFT() public {
        uint256 tokenId = nft.createNFT{value: MINT_PRICE}(user1, "uri", MINT_PRICE, "TICKER", 100);
        vm.startPrank(user1);
        nft.approve(address(market), tokenId);
        market.listNFT(tokenId, 2 ether);
        market.unlistNFT(tokenId);
        vm.stopPrank();

        vm.expectRevert("NFT not listed");
        market.getActiveListing(tokenId);
    }

    function testMakeOffer() public {
        uint256 tokenId = nft.createNFT{value: MINT_PRICE}(user1, "uri", MINT_PRICE, "TICKER", 100);
        vm.startPrank(user1);
        nft.approve(address(market), tokenId);
        market.listNFT(tokenId, 2 ether);
        vm.stopPrank();

        vm.prank(user2);
        market.makeOffer{value: 1.5 ether}(tokenId);

        AlysNFTP2PMarket.Offer memory offer = market.getActiveOffer(tokenId);
        assertEq(offer.buyer, user2);
        assertEq(offer.amount, 1.5 ether);
    }

    function testAcceptOffer() public {
        uint256 tokenId = nft.createNFT{value: MINT_PRICE}(user1, "uri", MINT_PRICE, "TICKER", 100);
        vm.startPrank(user1);
        nft.approve(address(market), tokenId);
        market.listNFT(tokenId, 2 ether);
        vm.stopPrank();

        vm.prank(user2);
        market.makeOffer{value: 1.5 ether}(tokenId);

        uint256 initialBalance = user1.balance;
        vm.prank(user1);
        market.acceptOffer(tokenId);

        assertEq(nft.ownerOf(tokenId), user2);
        assertGt(user1.balance, initialBalance);
    }

    function testRejectOffer() public {
        uint256 tokenId = nft.createNFT{value: MINT_PRICE}(user1, "uri", MINT_PRICE, "TICKER", 100);
        vm.startPrank(user1);
        nft.approve(address(market), tokenId);
        market.listNFT(tokenId, 2 ether);
        vm.stopPrank();

        vm.prank(user2);
        uint256 user2initialBalance = user2.balance;
        market.makeOffer{value: 1.5 ether}(tokenId);

        AlysNFTP2PMarket.Offer memory offer = market.getActiveOffer(tokenId);
        assertEq(offer.buyer, user2);
        assertEq(offer.amount, 1.5 ether);
        assertTrue(offer.expirationTime > block.timestamp);

        vm.startPrank(user1);
        market.rejectOffer(tokenId);

        // Verify that the offer has been deleted
        vm.expectRevert("No active offer");
        offer = market.getActiveOffer(tokenId);
        //vm.expectRevert("revert: No active offer");
        assertEq(offer.buyer, address(0));
        assertEq(offer.amount, 0);
        assertEq(offer.expirationTime, 0);

        // Verify that the funds have been returned to the buyer
        // Assuming you have a function to get the balance of user2
        uint256 balanceAfter = address(user2).balance;
        assertEq(balanceAfter, user2initialBalance); // Adjust according to initial balance setup

        vm.stopPrank();
    }

    function testCreateLoanRequest() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = nft.createNFT{value: MINT_PRICE}(user1, "uri", MINT_PRICE, "TICKER", 100);

        vm.startPrank(user1);
        nft.approve(address(market), tokenIds[0]);
        console.log(msg.sender);
        console.log(user1);
        market.createLoanRequest(tokenIds, 1 ether, 2 ether);
        vm.stopPrank();

        AlysNFTP2PMarket.LoanRequest memory request = market.getLoanRequest(0);
        assertEq(request.borrower, user1);
        assertEq(request.principal, 1 ether);
        assertEq(request.totalValue, 2 ether);
        assertTrue(request.isActive);
    }

    function testMakeLoanOffer() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = nft.createNFT{value: MINT_PRICE}(user1, "uri", MINT_PRICE, "TICKER", 100);

        vm.startPrank(user1);
        nft.approve(address(market), tokenIds[0]);
        market.createLoanRequest(tokenIds, 1 ether, 2 ether);
        vm.stopPrank();
        vm.prank(user2);
        market.makeLoanOffer{value: 1 ether}(0, 1 ether, 500, 30 days);

        AlysNFTP2PMarket.LoanOffer memory offer = market.getLoanOffer(0);
        assertEq(offer.lender, user2);
        assertEq(offer.principal, 1 ether);
        assertEq(offer.interestRate, 500);
        assertEq(offer.duration, 30 days);
    }

    function testAcceptLoanOffer() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = nft.createNFT{value: MINT_PRICE}(user1, "uri", MINT_PRICE, "TICKER", 100);

        vm.startPrank(user1);
        nft.approve(address(market), tokenIds[0]);
        market.createLoanRequest(tokenIds, 1 ether, 2 ether);
        vm.stopPrank();

        vm.prank(user2);
        market.makeLoanOffer{value: 1 ether}(0, 1 ether, 500, 30 days);

        uint256 initialBalance = user1.balance;
        vm.prank(user1);
        market.acceptLoanOffer(0);

        assertEq(nft.ownerOf(tokenIds[0]), address(market));
        assertEq(user1.balance, initialBalance + 1 ether);

        AlysNFTP2PMarket.ActiveLoan memory loan = market.getActiveLoan(0);
        assertEq(loan.borrower, user1);
        assertEq(loan.lender, user2);
    }

    function testRejectLoanOffer() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = nft.createNFT{value: MINT_PRICE}(user1, "uri", MINT_PRICE, "TICKER", 100);

        vm.startPrank(user1);
        nft.approve(address(market), tokenIds[0]);
        market.createLoanRequest(tokenIds, 1 ether, 2 ether);
        vm.stopPrank();

        vm.prank(user2);
        market.makeLoanOffer{value: 1 ether}(0, 1 ether, 500, 30 days);

        AlysNFTP2PMarket.LoanOffer memory offer = market.getLoanOffer(0);
        assertEq(offer.lender, user2);
        assertEq(offer.principal, 1 ether);
        assertEq(offer.interestRate, 500);
        assertEq(offer.duration, 30 days);
        assertTrue(offer.expirationTime > block.timestamp);

        // Check initial balance of lender (user2)
        uint256 initialBalance = address(user2).balance;

        vm.startPrank(user1);
        market.rejectLoanOffer(0);
        vm.stopPrank();

        // Verify that the loan offer has been deleted
        offer = market.getLoanOffer(0);
        assertEq(offer.lender, address(0));
        assertEq(offer.principal, 0);
        assertEq(offer.interestRate, 0);
        assertEq(offer.duration, 0);
        assertEq(offer.expirationTime, 0);

        // Verify that the funds have been returned to the lender
        uint256 balanceAfter = address(user2).balance;
        assertEq(balanceAfter, initialBalance + 1 ether); // Adjust according to initial balance setup
    }

    function testRepayLoan() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = nft.createNFT{value: MINT_PRICE}(user1, "uri", MINT_PRICE, "TICKER", 100);

        vm.startPrank(user1);
        nft.approve(address(market), tokenIds[0]);
        market.createLoanRequest(tokenIds, 1 ether, 2 ether);
        vm.stopPrank();

        vm.prank(user2);
        market.makeLoanOffer{value: 1 ether}(0, 1 ether, 500, 30 days);

        vm.prank(user1);
        market.acceptLoanOffer(0);

        // Fast forward 15 days
        vm.warp(block.timestamp + 15 days);

        uint256 repaymentAmount = 1.02 ether; // Approximate repayment amount
        vm.prank(user1);
        market.repayLoan{value: repaymentAmount}(0);

        assertEq(nft.ownerOf(tokenIds[0]), user1);
        AlysNFTP2PMarket.ActiveLoan memory loan = market.getActiveLoan(0);
        assertTrue(loan.isRepaid);
    }

    function testClaimCollateral() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = nft.createNFT{value: MINT_PRICE}(user1, "uri", MINT_PRICE, "TICKER", 100);

        vm.startPrank(user1);
        nft.approve(address(market), tokenIds[0]);
        market.createLoanRequest(tokenIds, 1 ether, 2 ether);
        vm.stopPrank();

        vm.prank(user2);
        market.makeLoanOffer{value: 1 ether}(0, 1 ether, 500, 30 days);

        vm.prank(user1);
        market.acceptLoanOffer(0);

        // Fast forward 31 days
        vm.warp(block.timestamp + 31 days);

        vm.prank(user2);
        market.claimCollateral(0);

        assertEq(nft.ownerOf(tokenIds[0]), user2);
        AlysNFTP2PMarket.ActiveLoan memory loan = market.getActiveLoan(0);
        assertTrue(loan.isRepaid);
    }

    function testFailListNFTNotOwner() public {
        uint256 tokenId = nft.createNFT{value: MINT_PRICE}(user1, "uri", MINT_PRICE, "TICKER", 100);
        vm.prank(user2);
        market.listNFT(tokenId, 2 ether);
    }

    function testFailMakeOfferInsufficientFunds() public {
        uint256 tokenId = nft.createNFT{value: MINT_PRICE}(user1, "uri", MINT_PRICE, "TICKER", 100);
        vm.prank(user1);
        nft.approve(address(market), tokenId);
        market.listNFT(tokenId, 2 ether);

        vm.prank(user2);
        market.makeOffer{value: 0.5 ether}(tokenId);
    }

    function testFailAcceptOfferNotSeller() public {
        uint256 tokenId = nft.createNFT{value: MINT_PRICE}(user1, "uri", MINT_PRICE, "TICKER", 100);
        vm.prank(user1);
        nft.approve(address(market), tokenId);
        market.listNFT(tokenId, 2 ether);

        vm.prank(user2);
        market.makeOffer{value: 1.5 ether}(tokenId);

        vm.prank(user3);
        market.acceptOffer(tokenId);
    }

    function testFailCreateLoanRequestInvalidLTV() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = nft.createNFT{value: MINT_PRICE}(user1, "uri", MINT_PRICE, "TICKER", 100);

        vm.startPrank(user1);
        nft.approve(address(market), tokenIds[0]);
        market.createLoanRequest(tokenIds, 2 ether, 2 ether);
        vm.stopPrank();
    }

    function testFailAcceptLoanOfferNotBorrower() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = nft.createNFT{value: MINT_PRICE}(user1, "uri", MINT_PRICE, "TICKER", 100);

        vm.startPrank(user1);
        nft.approve(address(market), tokenIds[0]);
        market.createLoanRequest(tokenIds, 1 ether, 2 ether);
        vm.stopPrank();

        vm.prank(user2);
        market.makeLoanOffer{value: 1 ether}(0, 1 ether, 500, 30 days);

        vm.prank(user3);
        market.acceptLoanOffer(0);
    }

    function testFailRepayLoanNotBorrower() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = nft.createNFT{value: MINT_PRICE}(user1, "uri", MINT_PRICE, "TICKER", 100);

        vm.startPrank(user1);
        nft.approve(address(market), tokenIds[0]);
        market.createLoanRequest(tokenIds, 1 ether, 2 ether);
        vm.stopPrank();

        vm.prank(user2);
        market.makeLoanOffer{value: 1 ether}(0, 1 ether, 500, 30 days);

        vm.prank(user1);
        market.acceptLoanOffer(0);

        vm.prank(user3);
        market.repayLoan{value: 1.02 ether}(0);
    }

    function testFailClaimCollateralNotLender() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = nft.createNFT{value: MINT_PRICE}(user1, "uri", MINT_PRICE, "TICKER", 100);

        vm.startPrank(user1);
        nft.approve(address(market), tokenIds[0]);
        market.createLoanRequest(tokenIds, 1 ether, 2 ether);
        vm.stopPrank();

        vm.prank(user2);
        market.makeLoanOffer{value: 1 ether}(0, 1 ether, 500, 30 days);

        vm.prank(user1);
        market.acceptLoanOffer(0);

        vm.warp(block.timestamp + 31 days);

        vm.prank(user3);
        market.claimCollateral(0);
    }
}
