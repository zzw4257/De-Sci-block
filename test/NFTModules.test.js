const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("NFT 模块测试", function () {
	let deployer, user1, user2, minter;
	let achievement, ipnft;

	beforeEach(async function () {
		[deployer, user1, user2, minter] = await ethers.getSigners();

		const Achievement = await ethers.getContractFactory("AchievementNFT");
		achievement = await Achievement.deploy(
			"DeSci Achievement",
			"DS-ACHV",
			"ipfs://base-cid/"
		);

		const IPNFT = await ethers.getContractFactory("IPNFT");
		ipnft = await IPNFT.deploy("DeSci IP", "DS-IP");

		// grant MINTER_ROLE to minter account
		const MINTER_ROLE = await achievement.MINTER_ROLE();
		await achievement.grantRole(MINTER_ROLE, minter.address);
		await ipnft.grantRole(MINTER_ROLE, minter.address);
	});

	describe("AchievementNFT (ERC-1155, Soulbound)", function () {
		it("应允许具有 MINTER_ROLE 的地址铸造成就NFT", async function () {
			await achievement.connect(minter).mintAchievement(user1.address, 1, 1);
			const bal = await achievement.balanceOf(user1.address, 1);
			expect(bal).to.equal(1);
		});

		it("应阻止非授权地址铸造", async function () {
			await expect(
				achievement.connect(user1).mintAchievement(user1.address, 1, 1)
			).to.be.revertedWithCustomError(achievement, "AccessControlUnauthorizedAccount");
		});

		it("应阻止成就NFT转移（灵魂绑定）", async function () {
			await achievement.connect(minter).mintAchievement(user1.address, 2, 1);
			await expect(
				achievement
					.connect(user1)
					.safeTransferFrom(user1.address, user2.address, 2, 1, "0x")
			).to.be.revertedWith("Soulbound: non-transferable");
		});

		it("应返回正确的元数据URI", async function () {
			await achievement.setBaseURI("ipfs://another-cid/");
			const u = await achievement.uri(3);
			expect(u).to.equal("ipfs://another-cid/3.json");
		});
	});

	describe("IPNFT (ERC-721)", function () {
		it("应允许具有 MINTER_ROLE 的地址铸造IP-NFT并设置tokenURI", async function () {
			const tx = await ipnft.connect(minter).mintIP(user1.address, "ipfs://meta/1.json");
			const receipt = await tx.wait();
			// tokenId should be 1 on first mint
			const tokenId = 1;
			expect(await ipnft.ownerOf(tokenId)).to.equal(user1.address);
			expect(await ipnft.tokenURI(tokenId)).to.equal("ipfs://meta/1.json");
		});

		it("应允许自由转移IP-NFT", async function () {
			await ipnft.connect(minter).mintIP(user1.address, "ipfs://meta/2.json");
			await ipnft.connect(user1).transferFrom(user1.address, user2.address, 1);
			expect(await ipnft.ownerOf(1)).to.equal(user2.address);
		});

		it("应阻止非授权地址铸造", async function () {
			await expect(
				ipnft.connect(user1).mintIP(user1.address, "ipfs://meta/3.json")
			).to.be.revertedWithCustomError(ipnft, "AccessControlUnauthorizedAccount");
		});
	});
}); 