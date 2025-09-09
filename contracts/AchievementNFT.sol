// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title AchievementNFT
 * @dev ERC-1155 based soulbound achievement NFTs with MINTER_ROLE control and base URI management
 */
contract AchievementNFT is ERC1155, AccessControl {
	using Strings for uint256;

	bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

	// Optional: name and symbol for off-chain UIs
	string public name;
	string public symbol;

	// Base URI like ipfs://<CID>/{id}.json
	string private _baseMetadataURI;

	event BaseURIUpdated(string newBaseURI);

	constructor(string memory _name, string memory _symbol, string memory baseURI) ERC1155("") {
		name = _name;
		symbol = _symbol;
		_baseMetadataURI = baseURI;
		_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_grantRole(MINTER_ROLE, msg.sender);
	}

	function setBaseURI(string memory newBaseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
		_baseMetadataURI = newBaseURI;
		emit BaseURIUpdated(newBaseURI);
	}

	function uri(uint256 id) public view override returns (string memory) {
		// If base is ipfs://CID/, return ipfs://CID/{id}.json
		return string(abi.encodePacked(_baseMetadataURI, id.toString(), ".json"));
	}

	function mintAchievement(address to, uint256 tokenId, uint256 amount) external onlyRole(MINTER_ROLE) {
		_requireValidRecipient(to);
		_requireValidAmount(amount);
		_mint(to, tokenId, amount, "");
	}

	function mintBatchAchievements(address to, uint256[] memory ids, uint256[] memory amounts) external onlyRole(MINTER_ROLE) {
		_requireValidRecipient(to);
		require(ids.length == amounts.length && ids.length > 0, "Invalid batch args");
		for (uint256 i = 0; i < amounts.length; i++) {
			_requireValidAmount(amounts[i]);
		}
		_mintBatch(to, ids, amounts, "");
	}

	function _requireValidRecipient(address to) internal pure {
		require(to != address(0), "Invalid recipient");
	}

	function _requireValidAmount(uint256 amount) internal pure {
		require(amount > 0, "Amount must be > 0");
	}

	// OZ v5 hook: enforce soulbound by reverting on transfers where both from and to are non-zero
	function _update(
		address from,
		address to,
		uint256[] memory ids,
		uint256[] memory amounts
	) internal override {
		if (from != address(0) && to != address(0)) {
			revert("Soulbound: non-transferable");
		}
		super._update(from, to, ids, amounts);
	}

	function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
		return super.supportsInterface(interfaceId);
	}
} 