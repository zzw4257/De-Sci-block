# 元数据生成与 IPFS 上传（后端脚本）

本脚本用于动态生成 AchievementNFT 与 IPNFT 的元数据，并上传到 IPFS（支持 Pinata 或 Infura 网关）。

## 依赖安装
在项目根目录安装依赖：
```bash
npm i axios form-data dotenv ipfs-http-client
```

## 环境变量
复制 `.env.example` 为 `.env` 并填写：
```bash
cp scripts/metadata/.env.example scripts/metadata/.env
```

`scripts/metadata/.env` 参数：
- PINATA_JWT：Pinata JWT（可选）
- INFURA_PROJECT_ID：Infura 项目ID（可选）
- INFURA_PROJECT_SECRET：Infura 项目密钥（可选）
- IPFS_GATEWAY：读取元数据的公共网关（默认 `https://ipfs.io/ipfs/`）

两种方式任意选择（Pinata/Infura）。

## 生成与上传（示例）
- 生成“成就”元数据并上传：
```bash
node scripts/metadata/metadata-service.js generate:achievement \
  --owner 0x1234...abcd \
  --type "peer_reviewer" \
  --year 2025 \
  --field "computational-biology" \
  --name "Peer Reviewer" \
  --image ./assets/peer-reviewer.png
```

- 生成“IP”元数据并上传：
```bash
node scripts/metadata/metadata-service.js generate:ip \
  --owner 0x1234...abcd \
  --title "Single-cell ZKP Dataset" \
  --leadResearcher "Alice" \
  --isZKPVerified true \
  --description "ZKP-verified single-cell analysis" \
  --image ./assets/ip-cover.png
```

输出：
- 会打印 `tokenURI`（形如 `ipfs://<CID>/metadata.json` 或 `ipfs://<CID>`），可直接用于合约铸造函数。

## 与合约联动（示例）
- AchievementNFT：
  - `mintAchievement(to, tokenId, amount)` 后，前端/脚本可用 `contract.uri(tokenId)` 获取元数据URI；或将 baseURI 指向 `ipfs://<CID>/`。
- IPNFT：
  - 在 `mintIP(to, tokenURI)` 中传入脚本返回的 `ipfs://...`。 