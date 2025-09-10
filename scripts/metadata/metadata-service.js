#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const axios = require('axios');
const FormData = require('form-data');
require('dotenv').config({ path: path.join(__dirname, 'env') });

const IPFS_GATEWAY = process.env.IPFS_GATEWAY || 'https://ipfs.io/ipfs/';
const PINATA_JWT = process.env.PINATA_JWT || '';
const INFURA_PROJECT_ID = process.env.INFURA_PROJECT_ID || '';
const INFURA_PROJECT_SECRET = process.env.INFURA_PROJECT_SECRET || '';
const LOCAL_IPFS_API = process.env.LOCAL_IPFS_API || ''; // e.g. http://127.0.0.1:5001

function parseArgs() {
	const args = process.argv.slice(2);
	const cmd = args.shift() || '';
	const opts = {};
	for (let i = 0; i < args.length; i++) {
		if (args[i].startsWith('--')) {
			const key = args[i].slice(2);
			const val = args[i + 1] && !args[i + 1].startsWith('--') ? args[++i] : 'true';
			opts[key] = val;
		}
	}
	return { cmd, opts };
}

function sha256Hex(data) {
	return crypto.createHash('sha256').update(JSON.stringify(data)).digest('hex');
}

async function uploadToPinata(content, fileName = 'metadata.json') {
	if (!PINATA_JWT) throw new Error('PINATA_JWT not set');
	const form = new FormData();
	form.append('file', Buffer.from(JSON.stringify(content)), fileName);
	const res = await axios.post('https://api.pinata.cloud/pinning/pinFileToIPFS', form, {
		headers: {
			Authorization: `Bearer ${PINATA_JWT}`,
			...form.getHeaders(),
		},
		timeout: 60000,
	});
	return res.data.IpfsHash; // CID
}

async function uploadToInfura(content, fileName = 'metadata.json') {
	if (!INFURA_PROJECT_ID || !INFURA_PROJECT_SECRET) throw new Error('Infura creds not set');
	const url = 'https://ipfs.infura.io:5001/api/v0/add?pin=true';
	const form = new FormData();
	form.append('file', Buffer.from(JSON.stringify(content)), fileName);
	const res = await axios.post(url, form, {
		auth: { username: INFURA_PROJECT_ID, password: INFURA_PROJECT_SECRET },
		headers: form.getHeaders(),
		timeout: 60000,
	});
	return res.data.Hash; // CID
}

async function uploadToLocalIpfs(content, fileName = 'metadata.json') {
	if (!LOCAL_IPFS_API) throw new Error('LOCAL_IPFS_API not set');
	const url = `${LOCAL_IPFS_API.replace(/\/$/, '')}/api/v0/add?pin=true`;
	const form = new FormData();
	form.append('file', Buffer.from(JSON.stringify(content)), fileName);
	const res = await axios.post(url, form, {
		headers: form.getHeaders(),
		timeout: 60000,
	});
	return res.data.Hash; // CID
}

async function upload(content, fileName) {
	try {
		if (PINATA_JWT) return await uploadToPinata(content, fileName);
		if (INFURA_PROJECT_ID && INFURA_PROJECT_SECRET) return await uploadToInfura(content, fileName);
		if (LOCAL_IPFS_API) return await uploadToLocalIpfs(content, fileName);
		throw new Error('No IPFS uploader configured');
	} catch (e) {
		console.error('Upload failed:', e.message);
		throw e;
	}
}

function achievementMetadata(opts) {
	const name = opts.name || 'Achievement';
	const image = opts.image || '';
	const attributes = [
		{ trait_type: 'type', value: opts.type || 'unknown' },
		{ trait_type: 'year', value: Number(opts.year || 0) },
		{ trait_type: 'field', value: opts.field || 'general' },
		{ trait_type: 'owner', value: (opts.owner || '').toLowerCase() },
	];
	return {
		name,
		description: opts.description || `${name} achievement badge`,
		image,
		attributes,
	};
}

function ipMetadata(opts) {
	const title = opts.title || 'Research IP';
	const image = opts.image || '';
	const isZKPVerified = String(opts.isZKPVerified || 'false') === 'true';
	return {
		name: title,
		description: opts.description || title,
		image,
		attributes: [
			{ trait_type: 'isZKPVerified', value: isZKPVerified },
			{ trait_type: 'leadResearcher', value: opts.leadResearcher || '' },
			{ trait_type: 'owner', value: (opts.owner || '').toLowerCase() },
		],
	};
}

async function main() {
	const { cmd, opts } = parseArgs();
	if (cmd !== 'generate:achievement' && cmd !== 'generate:ip') {
		console.log('Usage:');
		console.log('  node scripts/metadata/metadata-service.js generate:achievement --owner 0x.. --type peer_reviewer --year 2025 --field bio --name "Peer Reviewer" --image ./img.png');
		console.log('  node scripts/metadata/metadata-service.js generate:ip --owner 0x.. --title "ZKP Paper" --leadResearcher Alice --isZKPVerified true --description "desc" --image ./cover.png');
		console.log('  env options: PINATA_JWT | INFURA_PROJECT_ID+INFURA_PROJECT_SECRET | LOCAL_IPFS_API=http://127.0.0.1:5001');
		process.exit(1);
	}

	const meta = cmd === 'generate:achievement' ? achievementMetadata(opts) : ipMetadata(opts);

	const localHash = sha256Hex(meta);
	console.log('Local SHA256:', localHash);

	const cid = await upload(meta, 'metadata.json');
	const tokenURI = `ipfs://${cid}/metadata.json`;
	console.log('IPFS CID:', cid);
	console.log('tokenURI:', tokenURI);
	console.log('Gateway URL:', IPFS_GATEWAY + cid + '/metadata.json');
}

main().catch((e) => {
	console.error(e);
	process.exit(1);
}); 