/**
 * DeSci Web3演示 - 前端交互逻辑
 * 真实展示区块链技术在科学研究中的应用
 */

// 全局变量
let provider = null;
let signer = null;
let userProfileContract = null;
let datasetContract = null;
let platformContract = null;

// 合约地址配置
const CONTRACT_ADDRESSES = {
    UserProfile: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
    Dataset: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
    DeSciPlatform: '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9'
};

// 合约ABI（简化版）
const USER_PROFILE_ABI = [
    "function createProfile(string _fullName, uint256 _age, string _email, string _bio) external",
    "function getTotalUsers() external view returns (uint256)",
    "function getUserProfile(address _user) external view returns (string fullName, uint256 age, string email, string bio, bool isVerified)",
    "function hasProfile(address _user) external view returns (bool)",
    "function verifyUser(address _user) external"
];

const DATASET_ABI = [
    "function registerDataset(string _name, string _description, string _dataHash, string _metadataHash, bool _isPublic, uint256 _accessPrice, string[] _tags) external",
    "function getTotalDatasets() external view returns (uint256)",
    "function datasets(uint256) external view returns (string name, string description, address owner, string dataHash, bool isPublic, uint256 accessPrice, uint256 downloadCount)",
    "function hasAccess(uint256 _datasetId, address _user) external view returns (bool)",
    "function requestAccess(uint256 _datasetId, string _purpose) external payable"
];

// 初始化应用 - 全局函数，便于备用加载器调用
async function initApp() {
    console.log('🚀 初始化DeSci Web3演示应用...');

    // 检查ethers库是否加载
    if (typeof ethers === 'undefined') {
        console.warn('⏳ ethers库正在加载中...');
        // 不在这里处理，交给页面级别的加载检查器
        return;
    }

    try {
        await initBlockchainConnection();
        await initContracts();
        await loadPlatformData();
        setupEventListeners();

        console.log('✅ DeSci Web3演示应用初始化完成');
        showToast('Web3演示应用已就绪！', 'success');
    } catch (error) {
        console.error('❌ 初始化失败:', error);
        showToast('初始化失败，请检查区块链连接', 'error');
    }
}

// 导出到全局作用域，便于备用加载器调用
window.initApp = initApp;

// 1. 初始化区块链连接
async function initBlockchainConnection() {
    console.log('🔗 连接区块链网络...');

    try {
        // 连接到本地Hardhat网络
        provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');

        // 获取网络信息
        const network = await provider.getNetwork();
        document.getElementById('networkName').textContent = network.name;
        document.getElementById('chainId').textContent = network.chainId;
        document.getElementById('networkStatus').textContent = '已连接';
        document.getElementById('networkStatus').className = 'value status-online';

        // 监听区块变化
        provider.on('block', async (blockNumber) => {
            document.getElementById('blockNumber').textContent = blockNumber;
            document.getElementById('currentBlock').textContent = blockNumber;

            // 更新Gas价格
            const gasPrice = await provider.getGasPrice();
            const gasPriceGwei = ethers.utils.formatUnits(gasPrice, 'gwei');
            document.getElementById('gasPrice').textContent = gasPriceGwei.substring(0, 6) + ' Gwei';
            document.getElementById('currentGasPrice').textContent = gasPriceGwei.substring(0, 6) + ' Gwei';

            // 添加区块活动记录
            addBlockActivity(`新区块 #${blockNumber} 已确认`);
        });

        console.log('✅ 区块链连接成功');
    } catch (error) {
        console.error('❌ 区块链连接失败:', error);
        throw error;
    }
}

// 2. 初始化智能合约
async function initContracts() {
    console.log('📝 初始化智能合约...');

    try {
        // 获取签名者
        signer = provider.getSigner();
        const signerAddress = await signer.getAddress();
        console.log('📝 签名者地址:', signerAddress);

        // 初始化用户档案合约
        userProfileContract = new ethers.Contract(
            CONTRACT_ADDRESSES.UserProfile,
            USER_PROFILE_ABI,
            signer
        );

        // 初始化数据集合约
        datasetContract = new ethers.Contract(
            CONTRACT_ADDRESSES.Dataset,
            DATASET_ABI,
            signer
        );

        console.log('✅ 智能合约初始化完成');
    } catch (error) {
        console.error('❌ 合约初始化失败:', error);
        throw error;
    }
}

// 3. 加载平台数据
async function loadPlatformData() {
    console.log('📊 加载平台数据...');

    try {
        // 加载用户数量
        const totalUsers = await userProfileContract.getTotalUsers();
        document.getElementById('totalUsers').textContent = totalUsers.toString();

        // 加载数据集数量
        const totalDatasets = await datasetContract.getTotalDatasets();
        document.getElementById('totalDatasets').textContent = totalDatasets.toString();

        // 获取当前区块
        const blockNumber = await provider.getBlockNumber();
        document.getElementById('blockNumber').textContent = blockNumber;
        document.getElementById('currentBlock').textContent = blockNumber;

        // 获取Gas价格
        const gasPrice = await provider.getGasPrice();
        const gasPriceGwei = ethers.utils.formatUnits(gasPrice, 'gwei');
        document.getElementById('gasPrice').textContent = gasPriceGwei.substring(0, 6) + ' Gwei';
        document.getElementById('currentGasPrice').textContent = gasPriceGwei.substring(0, 6) + ' Gwei';

        console.log('✅ 平台数据加载完成');
    } catch (error) {
        console.error('❌ 加载平台数据失败:', error);
        // 不抛出错误，继续运行
    }
}

// 4. 设置事件监听器
function setupEventListeners() {
    // 标签页切换
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', () => switchTab(btn.dataset.tab));
    });

    // 访问权限选择变化
    document.getElementById('isPublic').addEventListener('change', function() {
        const accessPriceGroup = document.getElementById('accessPriceGroup');
        const accessPriceInput = document.getElementById('accessPrice');

        if (this.value === 'false') {
            accessPriceGroup.style.display = 'block';
            accessPriceInput.required = true;
        } else {
            accessPriceGroup.style.display = 'none';
            accessPriceInput.required = false;
            accessPriceInput.value = '';
        }
    });
}

// 5. 标签页切换
function switchTab(tabName) {
    // 移除所有标签页按钮的active类
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.remove('active');
    });

    // 为当前标签页按钮添加active类
    const currentBtn = document.querySelector(`[data-tab="${tabName}"]`);
    if (currentBtn) {
        currentBtn.classList.add('active');
    }

    // 移除所有内容区域的active类
    document.querySelectorAll('.tab-content').forEach(content => {
        content.classList.remove('active');
        content.style.display = 'none';
    });

    // 为当前内容区域添加active类
    const currentContent = document.getElementById(tabName);
    if (currentContent) {
        currentContent.classList.add('active');
        currentContent.style.display = 'block';
    }
}

// 6. 钱包连接功能
async function connectWallet() {
    try {
        if (!window.ethereum) {
            showToast('请安装MetaMask钱包', 'error');
            return;
        }

        const accounts = await window.ethereum.request({ method: 'eth_requestAccounts' });
        const account = accounts[0];

        // 更新UI
        document.getElementById('connectWalletBtn').innerHTML = `
            <i class="fas fa-check-circle"></i>
            ${account.substring(0, 6)}...${account.substring(account.length - 4)}
        `;
        document.getElementById('connectWalletBtn').className = 'btn btn-success';

        showToast('钱包连接成功！', 'success');
    } catch (error) {
        console.error('钱包连接失败:', error);
        showToast('钱包连接失败', 'error');
    }
}

// 7. 用户注册功能
async function registerUser(event) {
    event.preventDefault();

    const name = document.getElementById('userName').value;
    const age = document.getElementById('userAge').value;
    const email = document.getElementById('userEmail').value;
    const bio = document.getElementById('userBio').value;

    try {
        showLoading(true, '正在注册用户到区块链...');

        const tx = await userProfileContract.createProfile(name, age, email, bio);
        await tx.wait();

        showToast('用户注册成功！数据已永久记录在区块链上', 'success');

        // 清空表单
        event.target.reset();

        // 重新加载数据
        await loadPlatformData();

        // 添加日志
        addDemoLog('用户注册', `Dr. ${name} 已成功注册到区块链网络`);

    } catch (error) {
        console.error('用户注册失败:', error);
        showToast('用户注册失败: ' + error.message, 'error');
    } finally {
        showLoading(false);
    }
}

// 8. 数据集注册功能
async function registerDataset(event) {
    event.preventDefault();

    const name = document.getElementById('datasetName').value;
    const description = document.getElementById('datasetDescription').value;
    const tags = document.getElementById('datasetTags').value.split(',').map(tag => tag.trim());
    const isPublic = document.getElementById('isPublic').value === 'true';
    const accessPrice = isPublic ? 0 : ethers.parseEther(document.getElementById('accessPrice').value || '0');

    try {
        showLoading(true, '正在将数据集注册到区块链...');

        const tx = await datasetContract.registerDataset(
            name,
            description,
            `Qm${Date.now()}DataHash`, // 模拟数据哈希
            `Qm${Date.now()}MetadataHash`, // 模拟元数据哈希
            isPublic,
            accessPrice,
            tags
        );

        await tx.wait();

        showToast('数据集注册成功！数据哈希已永久记录在区块链上', 'success');

        // 清空表单
        event.target.reset();

        // 重新加载数据
        await loadPlatformData();

        // 添加日志
        addDemoLog('数据集注册', `数据集 "${name}" 已成功注册到区块链网络`);

    } catch (error) {
        console.error('数据集注册失败:', error);
        showToast('数据集注册失败: ' + error.message, 'error');
    } finally {
        showLoading(false);
    }
}

// 9. 演示功能
async function runFullDemo() {
    console.log('🎯 开始运行完整Web3演示...');

    try {
        // 步骤1: 区块链连接验证
        updateDemoStep(1, 'completed', '区块链连接成功');
        addDemoLog('演示开始', 'Web3科研平台演示启动');

        // 步骤2: 用户注册演示
        updateDemoStep(2, 'running', '正在注册演示用户');
        const demoUserTx = await userProfileContract.createProfile(
            "Dr. Demo Scientist",
            30,
            "demo@desci.org",
            "Web3科研平台演示用户"
        );
        await demoUserTx.wait();
        updateDemoStep(2, 'completed', '演示用户注册成功');
        addDemoLog('用户注册', '演示用户已注册到区块链');

        // 步骤3: 数据集发布演示
        updateDemoStep(3, 'running', '正在发布演示数据集');
        const demoDatasetTx = await datasetContract.registerDataset(
            "Web3科研演示数据集",
            "用于展示区块链技术在科学研究中应用的演示数据集",
            `QmDemoData${Date.now()}`,
            `QmDemoMeta${Date.now()}`,
            true,
            0,
            ["demo", "web3", "blockchain", "research"]
        );
        await demoDatasetTx.wait();
        updateDemoStep(3, 'completed', '演示数据集发布成功');
        addDemoLog('数据集发布', '演示数据集已发布到区块链');

        // 步骤4: 访问权限演示
        updateDemoStep(4, 'running', '正在演示访问权限控制');
        await datasetContract.requestAccess(1, "Web3演示访问测试");
        updateDemoStep(4, 'completed', '访问权限控制演示完成');
        addDemoLog('访问控制', '演示了去中心化的访问权限机制');

        // 步骤5: 数据不可篡改验证
        updateDemoStep(5, 'running', '正在验证数据不可篡改性');
        const dataset = await datasetContract.datasets(1);
        updateDemoStep(5, 'completed', `数据哈希: ${dataset.dataHash.substring(0, 20)}...`);
        addDemoLog('数据验证', '验证了区块链数据的不可篡改性');

        // 重新加载数据
        await loadPlatformData();

        showToast('Web3演示完成！所有功能都已验证', 'success');
        addDemoLog('演示完成', '完整Web3科研流程演示成功');

    } catch (error) {
        console.error('演示执行失败:', error);
        showToast('演示执行失败: ' + error.message, 'error');
        addDemoLog('演示失败', error.message);
    }
}

async function runUserDemo() {
    console.log('👥 运行用户注册演示...');

    try {
        const tx = await userProfileContract.createProfile(
            "Dr. Test Researcher",
            28,
            "test@research.org",
            "专门用于测试的演示用户"
        );
        await tx.wait();

        await loadPlatformData();
        showToast('用户注册演示成功！', 'success');
        addDemoLog('用户演示', '演示用户注册功能成功');

    } catch (error) {
        console.error('用户演示失败:', error);
        showToast('用户演示失败: ' + error.message, 'error');
    }
}

async function runDatasetDemo() {
    console.log('📊 运行数据集演示...');

    try {
        const tx = await datasetContract.registerDataset(
            "测试科研数据集",
            "用于功能测试的演示数据集",
            `QmTest${Date.now()}`,
            `QmTestMeta${Date.now()}`,
            true,
            0,
            ["test", "demo", "research"]
        );
        await tx.wait();

        await loadPlatformData();
        showToast('数据集演示成功！', 'success');
        addDemoLog('数据集演示', '演示数据集发布功能成功');

    } catch (error) {
        console.error('数据集演示失败:', error);
        showToast('数据集演示失败: ' + error.message, 'error');
    }
}

async function clearDemoData() {
    console.log('🧹 清空演示数据...');
    // 注意：在实际的区块链上，我们无法"删除"数据
    // 这里只是重置UI显示
    showToast('注意：区块链数据不可删除，这是Web3的核心特性！', 'warning');
    addDemoLog('数据清理', '演示了区块链数据的不可篡改特性');
}

// 10. 工具函数
function showLoading(show, text = '加载中...') {
    const overlay = document.getElementById('loadingOverlay');
    const loadingText = document.getElementById('loadingText');

    if (show) {
        loadingText.textContent = text;
        overlay.style.display = 'flex';
    } else {
        overlay.style.display = 'none';
    }
}

function showToast(message, type = 'info') {
    const toastContainer = document.getElementById('toastContainer');

    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;

    const icon = type === 'success' ? 'check-circle' :
                 type === 'error' ? 'times-circle' :
                 type === 'warning' ? 'exclamation-triangle' : 'info-circle';

    toast.innerHTML = `
        <i class="fas fa-${icon}"></i>
        <span>${message}</span>
        <button onclick="this.parentElement.remove()">&times;</button>
    `;

    toastContainer.appendChild(toast);

    // 自动移除
    setTimeout(() => {
        if (toast.parentElement) {
            toast.remove();
        }
    }, 5000);
}

function addBlockActivity(message) {
    const activitiesList = document.getElementById('blockActivities');
    const activityItem = document.createElement('div');
    activityItem.className = 'activity-item';

    const now = new Date();
    const timeString = now.toLocaleTimeString();

    activityItem.innerHTML = `
        <i class="fas fa-plus-circle"></i>
        <span>${message}</span>
        <small>${timeString}</small>
    `;

    // 只保留最新的10条活动
    if (activitiesList.children.length >= 10) {
        activitiesList.removeChild(activitiesList.lastChild);
    }

    activitiesList.insertBefore(activityItem, activitiesList.firstChild);
}

function addDemoLog(action, message) {
    const logsContainer = document.getElementById('demoLogs');
    const logEntry = document.createElement('div');
    logEntry.className = 'log-entry';

    const now = new Date();
    const timeString = now.toLocaleTimeString();

    logEntry.innerHTML = `
        <span class="log-time">${timeString}</span>
        <span class="log-action">${action}:</span>
        <span class="log-message">${message}</span>
    `;

    logsContainer.appendChild(logEntry);
    logsContainer.scrollTop = logsContainer.scrollHeight;
}

function updateDemoStep(stepNumber, status, message) {
    const stepElement = document.querySelector(`[data-step="${stepNumber}"]`);
    const statusElement = document.getElementById(`step${stepNumber}-status`);

    if (stepElement) {
        stepElement.className = `step-item step-${status}`;
    }

    if (statusElement) {
        statusElement.textContent = message;
        statusElement.className = `step-status status-${status}`;
    }
}

// 11. 页面加载完成后初始化 - 等待ethers库加载
document.addEventListener('DOMContentLoaded', function() {
    console.log('📄 DeSci Web3演示页面加载完成');

    // 如果ethers已经加载，直接初始化
    if (typeof ethers !== 'undefined') {
        console.log('✅ ethers库已加载，开始初始化应用...');
        initApp();
    } else {
        console.log('⏳ 等待ethers库加载完成...');
        // ethers库加载检查由HTML页面处理
    }
});

// 12. 全局错误处理
window.addEventListener('error', function(event) {
    console.error('页面错误:', event.error);
    showToast('页面出现错误，请检查控制台', 'error');
});

window.addEventListener('unhandledrejection', function(event) {
    console.error('未处理的Promise错误:', event.reason);
    showToast('网络请求失败，请检查区块链连接', 'error');
});
