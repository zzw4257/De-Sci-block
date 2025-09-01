#!/usr/bin/env node

/**
 * 简化的前端服务器
 * 专门用于DeSci Web3演示
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 3000;
const FRONTEND_DIR = path.join(__dirname, 'frontend');

console.log('🎨 启动DeSci Web3演示前端服务器...');
console.log(`📁 前端目录: ${FRONTEND_DIR}`);
console.log(`🌐 服务端口: ${PORT}`);

const server = http.createServer((req, res) => {
    try {
        // 解析请求路径
        let filePath = path.join(FRONTEND_DIR, req.url === '/' ? 'web3-demo.html' : req.url);

        // 如果是目录，尝试添加index.html
        if (fs.existsSync(filePath) && fs.statSync(filePath).isDirectory()) {
            filePath = path.join(filePath, 'index.html');
        }

        // 如果文件不存在，返回web3-demo.html
        if (!fs.existsSync(filePath)) {
            filePath = path.join(FRONTEND_DIR, 'web3-demo.html');
        }

        // 读取文件
        fs.readFile(filePath, (err, data) => {
            if (err) {
                console.error(`❌ 读取文件失败: ${filePath}`, err.message);
                res.writeHead(404);
                res.end('File not found');
                return;
            }

            // 设置正确的Content-Type
            const ext = path.extname(filePath);
            const contentType = {
                '.html': 'text/html',
                '.js': 'text/javascript',
                '.css': 'text/css',
                '.json': 'application/json',
                '.png': 'image/png',
                '.jpg': 'image/jpeg',
                '.jpeg': 'image/jpeg',
                '.gif': 'image/gif',
                '.svg': 'image/svg+xml',
                '.ico': 'image/x-icon'
            }[ext] || 'text/plain';

            res.writeHead(200, {
                'Content-Type': contentType,
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type'
            });
            res.end(data);
        });

    } catch (error) {
        console.error('❌ 服务器错误:', error.message);
        res.writeHead(500);
        res.end('Internal Server Error');
    }
});

// 处理服务器错误
server.on('error', (error) => {
    if (error.code === 'EADDRINUSE') {
        console.error(`❌ 端口 ${PORT} 已被占用`);
        process.exit(1);
    } else {
        console.error('❌ 服务器启动失败:', error.message);
        process.exit(1);
    }
});

// 启动服务器
server.listen(PORT, () => {
    console.log('✅ Web3演示前端服务器启动成功!');
    console.log(`🌐 访问地址: http://localhost:${PORT}`);
    console.log(`🚀 打开浏览器访问 http://localhost:${PORT} 开始体验Web3科研平台!`);
    console.log('');
    console.log('🎯 DeSci Web3演示功能:');
    console.log('• 🔗 实时区块链连接');
    console.log('• 👥 去中心化用户管理');
    console.log('• 📊 科研数据资产管理');
    console.log('• 🔐 智能合约访问控制');
    console.log('• ⚡ 自动化交易验证');
    console.log('• 🎨 现代化Web3界面');
});

// 优雅关闭
process.on('SIGINT', () => {
    console.log('\n🛑 正在关闭前端服务器...');
    server.close(() => {
        console.log('✅ 前端服务器已关闭');
        process.exit(0);
    });
});
