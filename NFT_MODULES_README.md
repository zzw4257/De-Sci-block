## NFT 模块简要说明

本项目新增两类 NFT 合约，当前阶段只覆盖后端与测试，前端集成暂缓。

### 1) AchievementNFT.sol（ERC-1155，灵魂绑定）
- 用途：颁发“论文作者/评审员/数据贡献者”等成就徽章。
- 特点：
  - MINTER_ROLE 控制铸造（默认部署者拥有）。
  - 灵魂绑定：禁止账户之间转移（仅允许铸造与销毁）。
  - URI 管理：`ipfs://<CID>/{id}.json` 形式，支持 `setBaseURI` 更新。
- 关键函数：
  - `mintAchievement(address to, uint256 tokenId, uint256 amount)`
  - `mintBatchAchievements(address to, uint256[] ids, uint256[] amounts)`

### 2) IPNFT.sol（ERC-721，知识产权）
- 用途：为科研成果/IP 资产铸造唯一、可转移的 NFT。
- 特点：
  - MINTER_ROLE 控制铸造。
  - 支持自由转移。
  - 铸造时设置 `tokenURI` 指向 IPFS 元数据。
- 关键函数：
  - `mintIP(address to, string tokenURI)`

### 编译与测试（仅后端）
```bash
npx hardhat compile
npx hardhat test test/NFTModules.test.js
```

### 后续建议
- 在 `DeSciPlatform.sol` 中加入对 `AchievementNFT` / `IPNFT` 的 MINTER_ROLE 配置与铸造流程。
- 增加部署脚本与 IPFS 元数据生成脚本。
- 规划 The Graph 子图以索引 NFT 铸造与持有关系。 