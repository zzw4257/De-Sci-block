/**
 * DeSci智能合约技术详情 - 专业展示
 */

let provider = null;
let userProfileContract = null;
let datasetContract = null;
let platformContract = null;

// 合约地址配置
const CONTRACT_ADDRESSES = {
    UserProfile: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
    Dataset: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
    DeSciPlatform: '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9'
};

// 简化版ABI
const USER_PROFILE_ABI = [
    "function getTotalUsers() external view returns (uint256)",
    "function getUserProfile(address _user) external view returns (string fullName, uint256 age, string email, string bio, bool isVerified)"
];

const DATASET_ABI = [
    "function getTotalDatasets() external view returns (uint256)",
    "function datasets(uint256) external view returns (string name, string description, address owner, string dataHash, bool isPublic, uint256 accessPrice, uint256 downloadCount)"
];

const PLATFORM_ABI = [
    "function getPlatformStats() external view returns (uint256 users, uint256 datasets, uint256 totalTransactions, uint256 totalValueLocked)"
];

// 初始化
async function initTechDetails() {
    console.log('🔧 初始化技术详情页面...');

    try {
        await initBlockchainConnection();
        await initContracts();
        await loadRealtimeData();
        setupNavigation();
        startRealtimeUpdates();

        console.log('✅ 技术详情页面初始化完成');
    } catch (error) {
        console.error('❌ 初始化失败:', error);
        updateStatus('blockchainStatus', '连接失败', 'error');
    }
}

// 区块链连接
async function initBlockchainConnection() {
    try {
        provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');
        await provider.getNetwork();

        updateStatus('blockchainStatus', '已连接', 'success');

        // 监听区块
        provider.on('block', async (blockNumber) => {
            document.getElementById('currentBlock').textContent = blockNumber;

            const gasPrice = await provider.getGasPrice();
            const gasPriceGwei = ethers.utils.formatUnits(gasPrice, 'gwei');
            document.getElementById('gasPrice').textContent = gasPriceGwei.substring(0, 4) + ' Gwei';
        });

    } catch (error) {
        updateStatus('blockchainStatus', '未连接', 'error');
        throw error;
    }
}

// 合约初始化
async function initContracts() {
    try {
        const signer = provider.getSigner();

        userProfileContract = new ethers.Contract(CONTRACT_ADDRESSES.UserProfile, USER_PROFILE_ABI, signer);
        datasetContract = new ethers.Contract(CONTRACT_ADDRESSES.Dataset, DATASET_ABI, signer);
        platformContract = new ethers.Contract(CONTRACT_ADDRESSES.DeSciPlatform, PLATFORM_ABI, signer);

    } catch (error) {
        console.error('合约初始化失败:', error);
    }
}

// 加载实时数据
async function loadRealtimeData() {
    try {
        const totalUsers = await userProfileContract.getTotalUsers();
        document.getElementById('activeUsers').textContent = totalUsers.toString();

        const totalDatasets = await datasetContract.getTotalDatasets();
        document.getElementById('totalTx').textContent = totalDatasets.toString();

    } catch (error) {
        console.error('加载实时数据失败:', error);
    }
}

// 导航切换
function setupNavigation() {
    document.querySelectorAll('.nav-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            // 移除所有活动状态
            document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
            document.querySelectorAll('.tech-section').forEach(s => s.classList.remove('active'));

            // 设置当前活动状态
            btn.classList.add('active');
            const sectionId = btn.dataset.section;
            document.getElementById(sectionId).classList.add('active');
        });
    });
}

// 实时更新
function startRealtimeUpdates() {
    setInterval(async () => {
        await loadRealtimeData();
    }, 5000); // 每5秒更新一次
}

// 状态更新工具函数
function updateStatus(elementId, text, status = 'normal') {
    const element = document.getElementById(elementId);
    if (element) {
        element.textContent = text;
        element.className = `value status-${status}`;
    }
}

// 页面加载完成初始化
document.addEventListener('DOMContentLoaded', initTechDetails);

// 错误处理
window.addEventListener('unhandledrejection', (event) => {
    console.error('未处理的Promise错误:', event.reason);
});

window.addEventListener('error', (event) => {
    console.error('页面错误:', event.error);
});
