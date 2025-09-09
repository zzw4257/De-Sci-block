## ZKP 模块一览（通俗版）

本文件合并并精炼了 `ZKP_MODULE_README.md` 与 `ZKP_MODULES_REPORT.md`，用更易懂的方式说明：系统做什么、有哪些模块、能完成哪些具体任务、以及如何快速上手测试。

---

### 1. 这套系统做什么
- 保护科研数据隐私的前提下，证明并验证“数据确实满足某些属性/规则”。
- 流程：提交数据 → 提取特征/统计指标 → 绑定并校验约束 → 通过 ZKP 在链上验证 → 记录验证结果。

简化示意：
```
数据提交 → 特征提取 → 约束检查 → 生成/提供ZKP → 链上验证 → 结果可查询/可用
```

---

### 2. 核心模块与职责（最重要）

- ZKPVerifier.sol（ZKP验证器）
  - 作用：统一管理/验证 ZK 证明（如 Groth16）的链上入口。
  - 关键能力：
    - 注册证明类型与参数：`registerProofType(...)`
    - 验证证明（单个/批量）：`verifyGroth16Proof(...)`、`verifyMultipleProofs(...)`
  - 能做的事：对“公开输入 + 证明”进行可信校验，为上层业务提供“已验证”的信号。

- ZKProof.sol（证明数据结构/工具）
  - 作用：规范证明与公开输入的数据结构，帮助各模块对齐格式。
  - 能做的事：让不同业务在提交/验证 ZKP 时使用同一种数据格式，方便集成。

- ResearchDataVerifier.sol（科研数据验证主合约）
  - 作用：把“数据提交、特征提取、约束绑定、ZKP 验证”串起来的协调者。
  - 关键能力：
    - 数据：`submitResearchData(...)`、`getResearchData(...)`、`getUserDataIds(...)`
    - 特征：`extractDataFeatures(...)`、`getDataFeatures(...)`
    - 约束：`addDataConstraint(...)`、`getDataConstraints(...)`、`validateDataConstraints(...)` → 返回 `(isValid, score, status)`
    - ZKP：与 `ZKPVerifier` 对接进行链上验证
  - 能做的事：形成“提交 → 校验 → 验证 → 记录”的完整闭环，为后续操作（发证、权限）提供依据。

- DataFeatureExtractor.sol（数据特征提取）
  - 作用：生成统计指标与质量分数。
  - 关键能力：授权计算器、`calculateDataFeatures(...)`、`updateStatisticalMetrics(...)`、`calculateDataQualityScore(...)`、`getDataFeatures(...)`
  - 能做的事：输出均值、标准差、分位点等指标与质量评分，常作为 ZKP 的公开输入或规则检查依据。

- ConstraintManager.sol（约束条件管理）
  - 作用：定义并管理“质量/格式/范围/统计”等规则，可组合成“约束组”。
  - 关键能力：`createConstraint(...)`、`createConstraintGroup(...)`、分类检索（按类别/字段）。
  - 能做的事：实现“至少满足 N 个”的柔性规则，用于数据合规性判定。

外围相关：
- `Dataset.sol`（数据集）、`DeSciPlatform.sol`（平台整合）、`DeSciNFTSimple.sol`（验证凭证NFT）、`UserProfile.sol`（用户画像）等，可与验证结果联动。

---

### 3. 重要功能清单（保留重点）
- 科研数据管理：IPFS 哈希与元数据登记、按用户查询。
- 特征提取与统计：均值、标准差、方差、分位点、质量评分，支持批量。
- 约束与规则：统计/格式/范围/质量等类型；权重/优先级/最少满足数；按类别/字段检索。
- ZKP 验证：支持 Groth16；单笔与批量验证；证明类型可注册/查询；验证结果可追溯。

---

### 4. 端到端流程（一句话版）
1) 提交数据拿到 `dataId` → 2) 特征与指标计算拿到 `featureId` → 3) 绑定并校验约束（得到是否有效/得分/状态）→ 4) 提交 ZKP 证明给验证器 → 5) 链上验证并记录。

---

### 5. 快速开始（最短路径）
- 编译合约：
```bash
npx hardhat compile
```
- 启动本地链：
```bash
npx hardhat node
```
- 部署 ZKP 相关：
```bash
npx hardhat run scripts/deployZKPModule.js --network localhost
```
- 仅运行 ZKP 测试：
```bash
npx hardhat test test/ZKPModule.test.js
```
- 定点运行某描述块：
```bash
npx hardhat test test/ZKPModule.test.js --grep "ZKP验证器合约测试"
```

---

### 6. 最常见的具体任务
- 我想验证一条“均值=300、标准差=158”的声明但不泄露原始数据：
  - 用 `DataFeatureExtractor` 得到统计指标；
  - 用 ZKP 生成电路证明（链下）；
  - 在链上通过 `ZKPVerifier.verifyGroth16Proof(...)` 校验；
  - 在 `ResearchDataVerifier` 中记录状态并对外查询。

- 我想给数据设“误差阈值≤5%”的规则：
  - 用 `ConstraintManager.createConstraint(...)` 建立规则；
  - 在 `ResearchDataVerifier` 绑定并 `validateDataConstraints(...)`；
  - 若通过，再配合 ZKP 验证增强可信度。

---

### 7. 简要前端集成（极简示例）
```javascript
import { ethers } from 'ethers';
const provider = new ethers.BrowserProvider(window.ethereum);
const signer = await provider.getSigner();
const researchDataVerifier = new ethers.Contract(address, abi, signer);
// 提交数据
await researchDataVerifier.submitResearchData("experiment", "QmHash123", "QmMetadata456");
```

---

如需更详尽的参数/事件/存储结构表或时序图（Mermaid），可以在此文档基础上继续扩展。

---

### 8. 使用说明（一步步）

- 环境要求：
  - Node.js ≥ 18，npm ≥ 8
  - Hardhat（项目已内置脚本）

- 安装与编译：
```bash
npm ci --no-audit --no-fund
npx hardhat compile
```

- 启动本地链（保持此终端不关）：
```bash
npx hardhat node
```

- 另开一终端，部署 ZKP 模块：
```bash
npx hardhat run scripts/deployZKPModule.js --network localhost
```

- 运行测试（建议先仅跑 ZKP 测试）：
```bash
npx hardhat test test/ZKPModule.test.js
# 或按描述块筛选
npx hardhat test test/ZKPModule.test.js --grep "ZKP验证器合约测试"
```

- 控制台交互（连接本地链）
```bash
npx hardhat console --network localhost
```
进入后示例：
```javascript
// 账户
const [deployer, user1] = await ethers.getSigners();

// 使用已知地址连接合约（示例）
const zkpAddr = "0x..."; // 部署日志中的地址
const ZKPVerifier = await ethers.getContractFactory("ZKPVerifier");
const zkp = ZKPVerifier.attach(zkpAddr);

// 调用：注册证明类型（仅示例参数）
await zkp.registerProofType(
  "research_data_verification",
  [1,2], [[1,2],[3,4]], [[5,6],[7,8]], [[9,10],[11,12]], [[1,2],[3,4]]
);

// 调用：验证单个 Groth16 证明（示例）
const proof = { a: [1,2], b: [[1,2],[3,4]], c: [5,6] };
const publicInputs = [300, 158];
await (await zkp.verifyGroth16Proof("research_data_verification", proof, publicInputs)).wait();
```

- 常见问题：
  - 部署/调用报 chainId 不一致：确保 `hardhat.config.js` 的 `localhost.chainId` 为 31337，且使用 `--network localhost`。
  - 没有地址可用：先部署脚本，或在控制台使用 `await ethers.deployContract("ContractName")` 部署后再 `attach`。
  - Gas 报错或交易失败：检查输入参数（尤其数组长度与范围），或先在测试中复现实例再迁移到交互。 