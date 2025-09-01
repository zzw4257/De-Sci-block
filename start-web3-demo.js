#!/usr/bin/env node

/**
 * DeSci Web3演示启动脚本
 * 只启动区块链网络和前端演示服务
 */

const { spawn } = require('child_process');
const path = require('path');

console.log('🚀 ============================================');
console.log('🚀      DeSci Web3演示启动系统');
console.log('🚀 ============================================');

const processes = [];
let shuttingDown = false;

// 1. 启动Hardhat本地区块链网络
function startBlockchain() {
    console.log('⛓️  启动区块链网络...');

    return new Promise((resolve, reject) => {
        const blockchainProcess = spawn('npx', ['hardhat', 'node'], {
            cwd: process.cwd(),
            stdio: ['pipe', 'pipe', 'pipe']
        });

        let startupComplete = false;

        blockchainProcess.stdout.on('data', (data) => {
            const output = data.toString();
            console.log('⛓️ ', output.trim());

            // 检测区块链网络启动完成
            if (output.includes('Started HTTP and WebSocket JSON-RPC server') && !startupComplete) {
                startupComplete = true;
                console.log('✅ 区块链网络启动成功!');
                setTimeout(() => resolve(blockchainProcess), 2000);
            }
        });

        blockchainProcess.stderr.on('data', (data) => {
            console.error('⛓️ 区块链错误:', data.toString().trim());
        });

        blockchainProcess.on('error', (error) => {
            console.error('❌ 区块链网络启动失败:', error.message);
            reject(error);
        });

        blockchainProcess.on('exit', (code) => {
            if (!shuttingDown && code !== 0) {
                console.log(`🔴 区块链网络退出 (代码: ${code})`);
            }
        });

        processes.push(blockchainProcess);
    });
}

// 2. 部署智能合约
function deployContracts() {
    console.log('📝 部署智能合约...');

    return new Promise((resolve, reject) => {
        const deployProcess = spawn('npx', ['hardhat', 'run', 'scripts/deploy.js', '--network', 'localhost'], {
            cwd: process.cwd(),
            stdio: ['pipe', 'pipe', 'pipe']
        });

        let deployComplete = false;

        deployProcess.stdout.on('data', (data) => {
            const output = data.toString();
            console.log('📝', output.trim());

            // 检测部署完成
            if (output.includes('所有合约部署完成') && !deployComplete) {
                deployComplete = true;
                console.log('✅ 智能合约部署成功!');
                resolve();
            }
        });

        deployProcess.stderr.on('data', (data) => {
            console.error('📝 合约部署错误:', data.toString().trim());
        });

        deployProcess.on('close', (code) => {
            if (code === 0) {
                console.log('✅ 智能合约部署完成!');
                resolve();
            } else {
                console.error(`❌ 合约部署失败 (代码: ${code})`);
                resolve(); // 不阻断启动流程
            }
        });

        deployProcess.on('error', (error) => {
            console.error('❌ 合约部署启动失败:', error.message);
            resolve(); // 不阻断启动流程
        });
    });
}

// 3. 启动前端演示服务
function startWeb3Demo() {
    console.log('🎨 启动Web3演示前端...');

    return new Promise((resolve) => {
        const demoProcess = spawn('node', ['simple-frontend-server.js'], {
            cwd: process.cwd(),
            stdio: ['pipe', 'pipe', 'pipe']
        });

        let demoReady = false;

        demoProcess.stdout.on('data', (data) => {
            const output = data.toString();
            console.log('🎨', output.trim());

            // 检测前端服务器启动成功
            if (output.includes('Web3演示前端服务器启动成功') && !demoReady) {
                demoReady = true;
                console.log('✅ Web3演示前端启动成功!');
                resolve(demoProcess);
            }
        });

        demoProcess.stderr.on('data', (data) => {
            console.error('🎨 前端错误:', data.toString().trim());
        });

        demoProcess.on('error', (error) => {
            console.error('❌ 前端启动失败:', error.message);
            resolve(null); // 不阻断启动流程
        });

        demoProcess.on('exit', (code) => {
            if (!shuttingDown && code !== 0) {
                console.log(`🔴 前端服务退出 (代码: ${code})`);
            }
        });

        processes.push(demoProcess);
    });
}

// 优雅关闭所有进程
function shutdown() {
    if (shuttingDown) return;
    shuttingDown = true;

    console.log('\n🛑 正在关闭Web3演示服务...');

    processes.forEach((process, index) => {
        try {
            process.kill('SIGTERM');
        } catch (error) {
            console.error(`关闭进程 ${index + 1} 失败:`, error.message);
        }
    });

    setTimeout(() => {
        console.log('✅ Web3演示服务已关闭');
        process.exit(0);
    }, 3000);
}

// 监听进程信号
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

// 主启动流程
async function startWeb3DemoPlatform() {
    try {
        console.log('🎯 启动DeSci Web3演示平台...\n');

        // 步骤1: 启动区块链网络
        const blockchainProcess = await startBlockchain();

        // 步骤2: 部署智能合约
        await deployContracts();

        // 步骤3: 启动前端演示服务
        await startWeb3Demo();

        // 显示服务信息
        console.log('\n🎉 Web3演示平台启动完成！');
        console.log('🚀 ============================================');
        console.log('🌐 Web3演示页面: http://localhost:3000');
        console.log('⛓️  区块链网络: http://localhost:8545');
        console.log('🚀 ============================================');

        console.log('\n📋 Web3功能演示:');
        console.log('• 🔗 实时区块链连接 - 查看网络状态和区块信息');
        console.log('• 👥 用户管理系统 - 区块链上注册科研身份');
        console.log('• 📊 数据集管理 - 去中心化数据资产管理');
        console.log('• 🔐 访问控制 - 智能合约自动执行权限');
        console.log('• ⚡ 交易验证 - 所有操作实时记录在区块链');
        console.log('• 🎯 完整演示 - 自动化展示Web3科研流程');

        console.log('\n🌟 Web3优势体现:');
        console.log('• 🔒 数据不可篡改 - 永久记录，任何人无法修改');
        console.log('• 🌐 完全透明 - 所有操作可公开追溯');
        console.log('• ⚡ 自动化执行 - 智能合约处理业务逻辑');
        console.log('• 💰 价值变现 - 自动化的收益分配机制');
        console.log('• 🚫 无需信任 - 代码即法律，去中心化协作');

        console.log('\n🛑 按 Ctrl+C 优雅关闭所有服务');
        console.log('💡 提示: 打开浏览器访问 http://localhost:3000 开始体验真正的Web3科研平台！');

        // 保持进程运行
        process.stdin.resume();

    } catch (error) {
        console.error('❌ Web3演示平台启动失败:', error.message);
        shutdown();
    }
}

// 启动Web3演示平台
startWeb3DemoPlatform();
