import { BigInt, Address, JSONValue, json, ipfs, Bytes } from "@graphprotocol/graph-ts";
import { Transfer as ERC721Transfer } from "../abis/IPNFT/IPNFT";
import { TransferSingle as ERC1155TransferSingle } from "../abis/AchievementNFT/AchievementNFT";
import { Achievement, IP } from "../generated/schema";

// Helper to parse attribute array
function getAttr(obj: json.Value, key: string): string {
	if (obj.kind != json.ValueKind.OBJECT) return "";
	const o = obj.toObject();
	const attrs = o.get("attributes");
	if (!attrs || attrs.kind != json.ValueKind.ARRAY) return "";
	const arr = attrs.toArray();
	for (let i = 0; i < arr.length; i++) {
		const item = arr[i].toObject();
		const t = item.get("trait_type");
		if (t && t.kind == json.ValueKind.STRING && t.toString() == key) {
			const v = item.get("value");
			return v ? v.toString() : "";
		}
	}
	return "";
}

export function handleTransfer(event: ERC721Transfer): void {
	const tokenId = event.params.tokenId;
	const id = tokenId.toString();
	let entity = IP.load(id);
	if (entity == null) {
		entity = new IP(id);
	}
	entity.owner = event.params.to;
	entity.createdAt = event.block.timestamp;

	// Attempt to fetch tokenURI via call (requires ABI with tokenURI view). Here we rely on offchain ingestion or leave empty.
	// If subgraph includes IPFS hash in some custom event, parse it there. Placeholder only.

	entity.save();
}

export function handleTransferSingle(event: ERC1155TransferSingle): void {
	const id = event.params.id.toString();
	let entity = Achievement.load(id);
	if (entity == null) {
		entity = new Achievement(id);
	}
	entity.owner = event.params.to;
	entity.createdAt = event.block.timestamp;

	// For ERC1155, metadata URI usually is baseURI + {id}.json; subgraph无法直接读取合约 storage，仅留空或由外部脚本回填
	entity.save();
} 