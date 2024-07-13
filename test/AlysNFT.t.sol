// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "../src/AlysNFT.sol";

contract AlysNFTTest is Test {
    AlysNFT public alysNFT;
    address public owner;
    address public user1;
    address public user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x149989584);
        user2 = address(0x23534553);
        alysNFT = new AlysNFT(owner);
    }

    function testCreateNFT() public {
        uint256 price = 1 ether;
        string memory uri = "https://example.com/token/1";
        string memory ticker = "TKN1";
        uint32 units = 100;

        vm.deal(user1, 2 ether);
        vm.prank(user1);
        uint256 tokenId = alysNFT.createNFT{value: price}(user1, uri, price, ticker, units);

        assertEq(alysNFT.ownerOf(tokenId), user1);
        assertEq(alysNFT.tokenURI(tokenId), uri);
        assertEq(alysNFT.getTokenUnits(tokenId), units);
        assertEq(alysNFT.getTokenTicker(tokenId), ticker);
    }

    function testTransferNFT() public {
        uint256 price = 1 ether;
        string memory uri = "https://example.com/token/1";
        string memory ticker = "TKN1";
        uint32 units = 100;

        vm.deal(user1, 2 ether);
        vm.prank(user1);
        uint256 tokenId = alysNFT.createNFT{value: price}(user1, uri, price, ticker, units);

        vm.prank(user1);
        alysNFT.transferNFT(user2, tokenId);

        assertEq(alysNFT.ownerOf(tokenId), user2);
    }

    function testGetNFTsOwnedBy() public {
        uint256 price = 1 ether;
        string memory uri = "https://example.com/token/";
        string memory ticker = "TKN";
        uint32 units = 100;

        vm.deal(user1, 5 ether);
        vm.startPrank(user1);

        for (uint256 i = 0; i < 3; i++) {
            alysNFT.createNFT{value: price}(
                user1, string(abi.encodePacked(uri, Strings.toString(i))), price, ticker, units
            );
        }

        vm.stopPrank();

        uint256[] memory ownedTokens = alysNFT.getNFTsOwnedBy(user1);
        assertEq(ownedTokens.length, 3);
    }

    function testGetAllNFTs() public {
        uint256 price = 1 ether;
        string memory uri = "https://example.com/token/";
        string memory ticker = "TKN";
        uint32 units = 100;

        vm.deal(user1, 5 ether);
        vm.startPrank(user1);

        for (uint256 i = 0; i < 3; i++) {
            alysNFT.createNFT{value: price}(
                user1, string(abi.encodePacked(uri, Strings.toString(i))), price, ticker, units
            );
        }

        vm.stopPrank();

        uint256[] memory allNFTs = alysNFT.getAllNFTs();
        assertEq(allNFTs.length, 3);
    }

    function testBurn() public {
        uint256 price = 1 ether;
        string memory uri = "https://example.com/token/1";
        string memory ticker = "TKN1";
        uint32 units = 100;

        vm.deal(user1, 2 ether);
        vm.prank(user1);
        uint256 tokenId = alysNFT.createNFT{value: price}(user1, uri, price, ticker, units);

        vm.prank(user1);
        alysNFT.burn(tokenId);

        // Check that the token no longer exists
        vm.expectRevert();
        alysNFT.ownerOf(tokenId);

        // Check that the token price is no longer available
        vm.expectRevert();
        alysNFT.getTokenUnits(tokenId);

        vm.expectRevert();
        alysNFT.getTokenTicker(tokenId);

        // Additional checks to ensure the token is truly burned
        assertEq(alysNFT.balanceOf(user1), 0);

        vm.expectRevert();
        alysNFT.tokenURI(tokenId);
    }

    function testFailUnauthorizedBurn() public {
        uint256 price = 1 ether;
        string memory uri = "https://example.com/token/1";
        string memory ticker = "TKN1";
        uint32 units = 100;

        vm.deal(user1, 2 ether);
        vm.prank(user1);
        uint256 tokenId = alysNFT.createNFT{value: price}(user1, uri, price, ticker, units);

        vm.prank(user2);
        alysNFT.burn(tokenId);
    }

    function testFailCreateNFTInsufficientPayment() public {
        uint256 price = 1 ether;
        string memory uri = "https://example.com/token/1";
        string memory ticker = "TKN1";
        uint32 units = 100;

        vm.deal(user1, 0.5 ether);
        vm.prank(user1);
        alysNFT.createNFT{value: 0.5 ether}(user1, uri, price, ticker, units);
    }

    function testFailUnauthorizedTransfer() public {
        uint256 price = 1 ether;
        string memory uri = "https://example.com/token/1";
        string memory ticker = "TKN1";
        uint32 units = 100;

        vm.deal(user1, 2 ether);
        vm.prank(user1);
        uint256 tokenId = alysNFT.createNFT{value: price}(user1, uri, price, ticker, units);

        vm.prank(user2);
        alysNFT.transferNFT(user2, tokenId);
    }
}
