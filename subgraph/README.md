# The Graph 子图（NFT 索引）

该子图用于索引 `AchievementNFT` 与 `IPNFT` 的转移/铸造事件，并解析 IPFS 元数据。

## 目录结构（建议）
```
subgraph/
  ├─ subgraph.yaml
  ├─ schema.graphql
  └─ src/
     └─ mapping.ts
```

## 快速开始
1. 全局安装：
```bash
yarn global add @graphprotocol/graph-cli
```
2. 生成并部署（示例，需替换地址与网络）：
```bash
graph codegen
graph build
# graph deploy --product hosted-service <GITHUB_USER>/<SUBGRAPH_NAME>
```

## 注意
- 将 `subgraph.yaml` 中的 `address` 与 `network` 替换为实际部署的 `AchievementNFT` 与 `IPNFT` 地址与网络。
- `mapping.ts` 将在捕获 `TransferSingle`/`Transfer` 事件时，尝试通过 tokenURI 或 baseURI 拼接，拉取 IPFS JSON 并解析属性填充实体。 