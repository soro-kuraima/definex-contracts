// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @custom:security-contact abhi.asno1@gmail.com
contract AlysNFT is ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Burnable, Ownable {
    uint256 private _nextTokenId;

    address public constant RECIPIENT_WALLET = 0xD7609082E71F01C3B178269C76dF76E087307aAE;

    mapping(uint256 => uint32) private _tokenUnits;
    mapping(uint256 => string) private _tokenTickers;

    constructor(address initialOwner) ERC721("AlysNFT", "ANFT") Ownable(initialOwner) {}

    function createNFT(address recipient, string memory uri, uint256 price, string memory ticker, uint32 units)
        public
        payable
        returns (uint256)
    {
        require(msg.value >= price, "Insufficient payment for minting");

        uint256 tokenId = _nextTokenId++;
        _safeMint(recipient, tokenId);
        _setTokenURI(tokenId, uri);
        _tokenUnits[tokenId] = units;
        _tokenTickers[tokenId] = ticker;

        payable(RECIPIENT_WALLET).transfer(msg.value);

        return tokenId;
    }

    function transferNFT(address to, uint256 tokenId) public returns (address) {
        require(
            _ownerOf(tokenId) == _msgSender() || isApprovedForAll(_ownerOf(tokenId), _msgSender())
                || getApproved(tokenId) == _msgSender(),
            "Caller is not owner nor approved"
        );
        return _update(to, tokenId, _msgSender());
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function getTokenUnits(uint256 tokenId) public view returns (uint256) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");
        return _tokenUnits[tokenId];
    }

    function getTokenTicker(uint256 tokenId) public view returns (string memory) {
        require(ownerOf(tokenId) != address(0), "Token does not exist");
        return _tokenTickers[tokenId];
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function getNFTsOwnedBy(address owner) public view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](balance);
        for (uint256 i = 0; i < balance; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(owner, i);
        }
        return tokenIds;
    }

    function getAllNFTs() public view returns (uint256[] memory) {
        uint256 totalSupply = totalSupply();
        uint256[] memory tokenIds = new uint256[](totalSupply);

        for (uint256 i = 0; i < totalSupply; i++) {
            tokenIds[i] = tokenByIndex(i);
        }

        return tokenIds;
    }

    function burn(uint256 tokenId) public override {
        require(
            ownerOf(tokenId) == _msgSender() || isApprovedForAll(ownerOf(tokenId), _msgSender())
                || getApproved(tokenId) == _msgSender(),
            "ERC721: caller is not token owner or approved"
        );

        // Clear the token price, units, and ticker
        delete _tokenUnits[tokenId];
        delete _tokenTickers[tokenId];

        // Call the internal _burn function
        _burn(tokenId);
    }
}
