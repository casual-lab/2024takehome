# Solana Node 使用指南

## 概述

`solana-node.sh` 是一个统一的 Solana 本地节点管理脚本，支持两种运行模式：

1. **solana-test-validator 模式**（推荐，WSL 友好）
2. **agave-validator 多节点模式**（需要足够系统权限）

## 快速开始

### 方案 A：使用 solana-test-validator（推荐用于 WSL）

```bash
# 1. 初始化环境
./solana-node.sh init --use-test-validator

# 2. 启动节点
./solana-node.sh start validator --use-test-validator

# 3. 查看状态
./solana-node.sh status

# 4. 测试连接
./solana-node.sh test

# 5. 停止节点
./solana-node.sh stop validator --use-test-validator

# 6. 清理所有数据
./solana-node.sh clean
```

### 方案 B：使用 agave-validator 多节点（需要修复内存限制）

```bash
# 1. 初始化环境
./solana-node.sh init

# 2. 启动所有节点
./solana-node.sh start all

# 或分别启动
./solana-node.sh start validator
./solana-node.sh start rpc
./solana-node.sh start indexer

# 3. 查看状态
./solana-node.sh status

# 4. 停止节点
./solana-node.sh stop all
```

## 两种模式对比

| 特性 | solana-test-validator | agave-validator 多节点 |
|------|----------------------|----------------------|
| **适用环境** | WSL、开发环境 | Linux 生产环境 |
| **内存限制要求** | 无特殊要求 | 需要 ulimit -l 2000000000 |
| **节点数量** | 单节点（集成所有功能） | 3 个独立节点 |
| **启动速度** | 快（5-10秒） | 较慢（需要等待同步） |
| **配置复杂度** | 简单 | 复杂（需要密钥、创世区块） |
| **功能完整性** | 完整（包含 Validator + RPC + Faucet） | 完整 + 可扩展 |
| **端口分配** | 8899 (RPC), 8900 (WS), 9900 (Faucet) | 8899 (Validator), 8900 (RPC), 8901 (Indexer) |

## 命令详解

### init - 初始化环境

初始化会创建工作目录、生成密钥对、创建创世区块。

```bash
# test-validator 模式
./solana-node.sh init --use-test-validator

# agave-validator 模式
./solana-node.sh init
```

**工作目录结构**：
```
test-ledger/
├── validator/
│   ├── identity.json
│   ├── vote-account.json
│   └── stake-account.json
├── rpc-node/
│   └── identity.json
├── indexer-node/
│   └── identity.json
├── test-validator-ledger/  (仅 test-validator 模式)
└── node-info.txt
```

### start - 启动节点

```bash
# 启动 Validator
./solana-node.sh start validator [--use-test-validator]

# 启动 RPC 节点（仅 agave-validator 模式）
./solana-node.sh start rpc

# 启动 Indexer 节点（仅 agave-validator 模式）
./solana-node.sh start indexer

# 启动所有节点
./solana-node.sh start all [--use-test-validator]
```

**注意**：
- test-validator 模式下，RPC 和 Indexer 功能已集成，无需单独启动
- agave-validator 模式下，必须先启动 Validator，再启动 RPC/Indexer

### stop - 停止节点

```bash
# 停止 Validator
./solana-node.sh stop validator [--use-test-validator]

# 停止所有节点
./solana-node.sh stop all [--use-test-validator]
```

### status - 查看状态

查看所有节点的运行状态、PID、端口监听情况。

```bash
./solana-node.sh status
```

**输出示例**：
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Solana 本地网络状态 (solana-test-validator)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[Test Validator (集成模式)]
  状态: 运行中
  PID: 382355
  RPC 端口: 8899
  端口监听: ✓
  包含功能: Validator + RPC (8899) + WebSocket (8900) + Faucet (9900)
```

### logs - 查看日志

实时查看节点日志（类似 tail -f）。

```bash
# 查看 Validator 日志
./solana-node.sh logs validator

# 查看 RPC 节点日志
./solana-node.sh logs rpc

# 查看 Indexer 节点日志
./solana-node.sh logs indexer
```

按 `Ctrl+C` 退出日志查看。

### test - 测试网络

测试各节点的 RPC 连接和健康状态。

```bash
./solana-node.sh test
```

**输出示例**：
```
[1] 测试 Validator (端口 8899)
  ✓ Validator 连接正常
  当前 Slot: 106

[2] 测试 RPC 节点 (端口 8900)
  ⚠ RPC 节点连接失败（可能未启动）
```

### clean - 清理数据

停止所有节点并删除所有数据（包括密钥和区块链数据）。

```bash
./solana-node.sh clean
```

**警告**：此操作会永久删除所有本地数据！

## 实际使用场景

### 场景 1：本地开发测试

```bash
# 使用 test-validator，快速启动
./solana-node.sh init --use-test-validator
./solana-node.sh start validator --use-test-validator

# 配置 Solana CLI
solana config set --url http://127.0.0.1:8899

# 请求空投
solana airdrop 10

# 部署程序
solana program deploy my_program.so

# 完成后停止
./solana-node.sh stop validator --use-test-validator
```

### 场景 2：模拟生产多节点环境

```bash
# 使用 agave-validator 多节点模式
./solana-node.sh init
./solana-node.sh start all

# 查看各节点状态
./solana-node.sh status

# 测试 RPC 节点
curl http://127.0.0.1:8900 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'

# 查看 Validator 日志
./solana-node.sh logs validator
```

### 场景 3：持续集成测试

```bash
#!/bin/bash
# CI 测试脚本

# 启动测试节点
./solana-node.sh init --use-test-validator
./solana-node.sh start validator --use-test-validator

# 等待节点就绪
sleep 10

# 运行测试
npm test

# 清理
./solana-node.sh clean
```

## 端口说明

### test-validator 模式
- **8899**: RPC HTTP 端口（主要接口）
- **8900**: WebSocket 端口
- **9900**: Faucet 端口（用于请求测试代币）

### agave-validator 模式
- **8899**: Validator RPC 端口
- **8900**: RPC 节点端口
- **8901**: Indexer 节点端口

## 常见问题

### Q1: 如何选择使用哪种模式？

**A**: 
- **WSL/本地开发**：使用 `--use-test-validator`
- **Linux 生产环境/多节点测试**：使用 agave-validator 模式

### Q2: agave-validator 模式启动失败怎么办？

**A**: 检查内存锁定限制：
```bash
ulimit -l
# 如果小于 2000000000，需要修复

# 临时修复（需要 root）
sudo sh -c 'echo "* soft memlock 2000000000" >> /etc/security/limits.conf'
sudo sh -c 'echo "* hard memlock 2000000000" >> /etc/security/limits.conf'

# 重新登录后生效
```

参考 `WSL_SOLUTIONS.md` 获取详细解决方案。

### Q3: 如何查看当前使用的模式？

**A**: 运行 `./solana-node.sh status`，标题会显示当前模式。

### Q4: 可以同时运行两种模式吗？

**A**: 不建议。两种模式使用相同的端口，会产生冲突。

### Q5: 节点启动后如何验证是否正常工作？

**A**: 
```bash
# 方法1：使用内置测试
./solana-node.sh test

# 方法2：使用 Solana CLI
solana cluster-version
solana slot

# 方法3：直接调用 RPC
curl http://127.0.0.1:8899 -X POST -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}'
```

## 日志位置

- **test-validator 模式**: `test-ledger/test-validator.log`
- **agave-validator 模式**:
  - Validator: `test-ledger/validator.log`
  - RPC: `test-ledger/rpc-node.log`
  - Indexer: `test-ledger/indexer-node.log`

## 高级配置

### 自定义工作目录

编辑脚本开头的配置：
```bash
WORK_DIR="my-custom-ledger"
```

### 自定义 Solana 根目录

```bash
SOLANA_ROOT="/path/to/your/solana-agave"
```

## 相关文档

- [START_HERE.md](START_HERE.md) - WSL 快速开始指南
- [WSL_SOLUTIONS.md](WSL_SOLUTIONS.md) - WSL 问题解决方案
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - 项目完整文档

## 支持

遇到问题？

1. 查看日志：`./solana-node.sh logs validator`
2. 检查状态：`./solana-node.sh status`
3. 测试网络：`./solana-node.sh test`
4. 参考 WSL_SOLUTIONS.md 获取常见问题解决方案
