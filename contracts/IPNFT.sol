// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title IPNFT
 * @dev ERC-721 NFT representing intellectual property; minting restricted to MINTER_ROLE
 */
contract IPNFT is ERC721URIStorage, AccessControl {
	bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
	uint256 public nextTokenId = 1;

	constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {
		_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_grantRole(MINTER_ROLE, msg.sender);
	}

	function mintIP(address to, string memory tokenURI_) external onlyRole(MINTER_ROLE) returns (uint256) {
		require(to != address(0), "Invalid recipient");
		require(bytes(tokenURI_).length > 0, "Empty tokenURI");
		uint256 tokenId = nextTokenId++;
		_safeMint(to, tokenId);
		_setTokenURI(tokenId, tokenURI_);
		return tokenId;
	}

	function supportsInterface(bytes4 interfaceId) public view override(ERC721URIStorage, AccessControl) returns (bool) {
		return super.supportsInterface(interfaceId);
	}
} 