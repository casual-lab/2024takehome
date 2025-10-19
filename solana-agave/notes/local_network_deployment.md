# Solana 本地测试网络部署指南（极简版）

> **适用场景**: 本地开发和测试环境  
> **原则**: 只包含必要参数，删除所有冗余配置

## 目录

1. [快速开始](#1-快速开始)
2. [Validator 节点（本地）](#2-validator-节点本地)
3. [RPC 节点（本地）](#3-rpc-节点本地)
4. [Indexer 节点（本地）](#4-indexer-节点本地)
5. [完整示例：三节点本地网络](#5-完整示例三节点本地网络)

---

## 1. 快速开始

### 1.1 环境准备

```bash
# 1. 编译 Solana（如果尚未编译）
cd /home/yy/2024chain/2024takehome/solana-agave
cargo build --release

# 2. 设置环境变量
export PATH="$PWD/target/release:$PATH"

# 3. 创建配置目录
mkdir -p test-ledger/validator
mkdir -p test-ledger/rpc-node
mkdir -p test-ledger/indexer-node
```

### 1.2 生成密钥对

```bash
# Bootstrap validator 密钥
agave-validator-keygen new --outfile test-ledger/validator/identity.json --no-bip39-passphrase
agave-validator-keygen new --outfile test-ledger/validator/vote-account.json --no-bip39-passphrase

# RPC 节点密钥
agave-validator-keygen new --outfile test-ledger/rpc-node/identity.json --no-bip39-passphrase

# Indexer 节点密钥
agave-validator-keygen new --outfile test-ledger/indexer-node/identity.json --no-bip39-passphrase
```

### 1.3 创建创世区块

```bash
# 创建最小化创世配置
agave-genesis \
  --bootstrap-validator \
    test-ledger/validator/identity.json \
    test-ledger/validator/vote-account.json \
  --ledger test-ledger/validator \
  --faucet-lamports 500000000000000
```

---

## 2. Validator 节点（本地）

### 2.1 最小配置（Bootstrap Validator）

这是网络的**第一个节点**，负责启动区块链：

```bash
#!/bin/bash
# start-validator.sh - 本地 Validator 启动脚本

agave-validator \
  --identity test-ledger/validator/identity.json \
  --vote-account test-ledger/validator/vote-account.json \
  --ledger test-ledger/validator \
  --rpc-port 8899 \
  --log -
```

### 2.2 参数说明

| 参数 | 必需 | 说明 |
|------|------|------|
| `--identity` | ✅ | 验证者身份密钥文件 |
| `--vote-account` | ✅ | 投票账户密钥文件 |
| `--ledger` | ✅ | 账本存储目录 |
| `--rpc-port` | 推荐 | RPC 端口（默认 8899）|
| `--log` | 可选 | 日志输出（`-` 表示标准输出）|

### 2.3 启动命令

```bash
chmod +x start-validator.sh
./start-validator.sh
```

### 2.4 验证节点运行

在另一个终端：

```bash
# 检查集群状态
solana --url http://127.0.0.1:8899 cluster-version

# 查看账本信息
solana --url http://127.0.0.1:8899 slot

# 查看节点身份
solana --url http://127.0.0.1:8899 validators
```

---

## 3. RPC 节点（本地）

### 3.1 最小配置（不参与共识）

```bash
#!/bin/bash
# start-rpc-node.sh - 本地 RPC 节点启动脚本

agave-validator \
  --identity test-ledger/rpc-node/identity.json \
  --ledger test-ledger/rpc-node \
  --no-voting \
  --entrypoint 127.0.0.1:8001 \
  --rpc-port 8900 \
  --log -
```

### 3.2 参数说明

| 参数 | 必需 | 说明 |
|------|------|------|
| `--identity` | ✅ | RPC 节点身份密钥 |
| `--ledger` | ✅ | 账本存储目录（独立于 Validator）|
| `--no-voting` | ✅ | **禁用投票，不参与共识** |
| `--entrypoint` | ✅ | 连接到 Bootstrap Validator 的 gossip 地址 |
| `--rpc-port` | ✅ | RPC 端口（避免与 Validator 冲突，使用 8900）|
| `--log` | 可选 | 日志输出 |

### 3.3 启动命令

**注意**: 必须先启动 Validator 节点！

```bash
chmod +x start-rpc-node.sh
./start-rpc-node.sh
```

### 3.4 测试 RPC 服务

```bash
# 测试 RPC 连接
curl http://127.0.0.1:8900 -X POST -H "Content-Type: application/json" -d '
  {"jsonrpc":"2.0","id":1,"method":"getHealth"}
'

# 查询最新 slot
curl http://127.0.0.1:8900 -X POST -H "Content-Type: application/json" -d '
  {"jsonrpc":"2.0","id":1,"method":"getSlot"}
'
```

---

## 4. Indexer 节点（本地）

### 4.1 创建 Geyser 插件配置

首先创建简化的插件配置文件 `test-ledger/geyser-config.json`:

```json
{
  "libpath": "/path/to/your/geyser/plugin.so",
  "log_level": "info",
  "accounts": {
    "enabled": true
  },
  "transactions": {
    "enabled": true
  },
  "blocks": {
    "enabled": true
  }
}
```

**如果没有自定义插件**，可以跳过 Geyser 配置，仅运行基础节点。

### 4.2 最小配置（带 Geyser 插件）

```bash
#!/bin/bash
# start-indexer-node.sh - 本地 Indexer 节点启动脚本

agave-validator \
  --identity test-ledger/indexer-node/identity.json \
  --ledger test-ledger/indexer-node \
  --no-voting \
  --entrypoint 127.0.0.1:8001 \
  --geyser-plugin-config test-ledger/geyser-config.json \
  --rpc-port 8901 \
  --log -
```

### 4.3 最小配置（不带插件 - 仅同步数据）

如果只是想同步区块链数据而不采集事件：

```bash
#!/bin/bash
# start-indexer-node-basic.sh - 基础 Indexer 节点（无插件）

agave-validator \
  --identity test-ledger/indexer-node/identity.json \
  --ledger test-ledger/indexer-node \
  --no-voting \
  --entrypoint 127.0.0.1:8001 \
  --rpc-port 8901 \
  --log -
```

### 4.4 参数说明

| 参数 | 必需 | 说明 |
|------|------|------|
| `--identity` | ✅ | Indexer 节点身份密钥 |
| `--ledger` | ✅ | 账本存储目录 |
| `--no-voting` | ✅ | **禁用投票** |
| `--entrypoint` | ✅ | 连接到 Bootstrap Validator |
| `--geyser-plugin-config` | 可选 | Geyser 插件配置文件（如需事件采集）|
| `--rpc-port` | ✅ | RPC 端口（避免冲突，使用 8901）|
| `--log` | 可选 | 日志输出 |

---

## 5. 完整示例：三节点本地网络

### 5.1 一键部署脚本

创建 `deploy-local-network.sh`:

```bash
#!/bin/bash
set -e

echo "======================================"
echo "Solana 本地三节点网络部署脚本"
echo "======================================"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 工作目录
WORK_DIR="test-ledger"

echo -e "${YELLOW}[1/6] 清理旧数据...${NC}"
rm -rf $WORK_DIR
mkdir -p $WORK_DIR/{validator,rpc-node,indexer-node}

echo -e "${YELLOW}[2/6] 生成密钥对...${NC}"
# Validator 密钥
agave-validator-keygen new --outfile $WORK_DIR/validator/identity.json --no-bip39-passphrase --silent
agave-validator-keygen new --outfile $WORK_DIR/validator/vote-account.json --no-bip39-passphrase --silent

# RPC 节点密钥
agave-validator-keygen new --outfile $WORK_DIR/rpc-node/identity.json --no-bip39-passphrase --silent

# Indexer 节点密钥
agave-validator-keygen new --outfile $WORK_DIR/indexer-node/identity.json --no-bip39-passphrase --silent

echo -e "${GREEN}✓ 密钥生成完成${NC}"

echo -e "${YELLOW}[3/6] 创建创世区块...${NC}"
agave-genesis \
  --bootstrap-validator \
    $WORK_DIR/validator/identity.json \
    $WORK_DIR/validator/vote-account.json \
  --ledger $WORK_DIR/validator \
  --faucet-lamports 500000000000000 > /dev/null 2>&1

echo -e "${GREEN}✓ 创世区块创建完成${NC}"

echo -e "${YELLOW}[4/6] 启动 Validator 节点（后台）...${NC}"
agave-validator \
  --identity $WORK_DIR/validator/identity.json \
  --vote-account $WORK_DIR/validator/vote-account.json \
  --ledger $WORK_DIR/validator \
  --rpc-port 8899 \
  --log $WORK_DIR/validator.log \
  > /dev/null 2>&1 &

VALIDATOR_PID=$!
echo -e "${GREEN}✓ Validator 启动成功 (PID: $VALIDATOR_PID)${NC}"

# 等待 Validator 初始化
echo -e "${YELLOW}等待 Validator 初始化...${NC}"
for i in {1..30}; do
  if curl -s http://127.0.0.1:8899 -X POST -H "Content-Type: application/json" \
    -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Validator 已就绪${NC}"
    break
  fi
  echo -n "."
  sleep 1
done
echo ""

echo -e "${YELLOW}[5/6] 启动 RPC 节点（后台）...${NC}"
agave-validator \
  --identity $WORK_DIR/rpc-node/identity.json \
  --ledger $WORK_DIR/rpc-node \
  --no-voting \
  --entrypoint 127.0.0.1:8001 \
  --rpc-port 8900 \
  --log $WORK_DIR/rpc-node.log \
  > /dev/null 2>&1 &

RPC_PID=$!
echo -e "${GREEN}✓ RPC 节点启动成功 (PID: $RPC_PID)${NC}"

echo -e "${YELLOW}[6/6] 启动 Indexer 节点（后台）...${NC}"
agave-validator \
  --identity $WORK_DIR/indexer-node/identity.json \
  --ledger $WORK_DIR/indexer-node \
  --no-voting \
  --entrypoint 127.0.0.1:8001 \
  --rpc-port 8901 \
  --log $WORK_DIR/indexer-node.log \
  > /dev/null 2>&1 &

INDEXER_PID=$!
echo -e "${GREEN}✓ Indexer 节点启动成功 (PID: $INDEXER_PID)${NC}"

echo ""
echo -e "${GREEN}======================================"
echo "🎉 本地网络部署完成！"
echo "======================================${NC}"
echo ""
echo "节点信息:"
echo "  Validator (共识): http://127.0.0.1:8899 (PID: $VALIDATOR_PID)"
echo "  RPC 节点:        http://127.0.0.1:8900 (PID: $RPC_PID)"
echo "  Indexer 节点:    http://127.0.0.1:8901 (PID: $INDEXER_PID)"
echo ""
echo "日志文件:"
echo "  Validator: $WORK_DIR/validator.log"
echo "  RPC:       $WORK_DIR/rpc-node.log"
echo "  Indexer:   $WORK_DIR/indexer-node.log"
echo ""
echo "测试命令:"
echo "  solana --url http://127.0.0.1:8899 cluster-version"
echo "  solana --url http://127.0.0.1:8900 slot"
echo ""
echo "停止网络:"
echo "  kill $VALIDATOR_PID $RPC_PID $INDEXER_PID"
echo ""
echo "或者运行:"
echo "  ./stop-local-network.sh"
echo ""

# 保存 PID 以便后续停止
echo "$VALIDATOR_PID" > $WORK_DIR/validator.pid
echo "$RPC_PID" > $WORK_DIR/rpc-node.pid
echo "$INDEXER_PID" > $WORK_DIR/indexer-node.pid
```

### 5.2 停止脚本

创建 `stop-local-network.sh`:

```bash
#!/bin/bash

WORK_DIR="test-ledger"

echo "停止本地 Solana 网络..."

if [[ -f $WORK_DIR/validator.pid ]]; then
  VALIDATOR_PID=$(cat $WORK_DIR/validator.pid)
  if kill -0 $VALIDATOR_PID 2>/dev/null; then
    kill $VALIDATOR_PID
    echo "✓ Validator 已停止 (PID: $VALIDATOR_PID)"
  fi
fi

if [[ -f $WORK_DIR/rpc-node.pid ]]; then
  RPC_PID=$(cat $WORK_DIR/rpc-node.pid)
  if kill -0 $RPC_PID 2>/dev/null; then
    kill $RPC_PID
    echo "✓ RPC 节点已停止 (PID: $RPC_PID)"
  fi
fi

if [[ -f $WORK_DIR/indexer-node.pid ]]; then
  INDEXER_PID=$(cat $WORK_DIR/indexer-node.pid)
  if kill -0 $INDEXER_PID 2>/dev/null; then
    kill $INDEXER_PID
    echo "✓ Indexer 节点已停止 (PID: $INDEXER_PID)"
  fi
fi

echo "所有节点已停止"
```

### 5.3 使用方法

```bash
# 1. 赋予执行权限
chmod +x deploy-local-network.sh stop-local-network.sh

# 2. 部署网络
./deploy-local-network.sh

# 3. 测试网络
solana --url http://127.0.0.1:8899 cluster-version
solana --url http://127.0.0.1:8900 slot

# 4. 查看日志
tail -f test-ledger/validator.log
tail -f test-ledger/rpc-node.log
tail -f test-ledger/indexer-node.log

# 5. 停止网络
./stop-local-network.sh
```

---

## 6. 使用 multinode-demo 脚本（推荐）

Solana 源码自带的 `multinode-demo` 脚本更加稳定可靠：

### 6.1 快速启动

```bash
cd /home/yy/2024chain/2024takehome/solana-agave

# 1. 初始化（生成密钥和创世区块）
./multinode-demo/setup.sh

# 2. 启动 Bootstrap Validator（终端1）
./multinode-demo/bootstrap-validator.sh

# 3. 启动额外的 Validator（终端2，可选）
./multinode-demo/validator.sh

# 4. 启动 RPC 节点（终端3）
./multinode-demo/validator.sh --no-voting --rpc-port 8900

# 5. 启动 Indexer 节点（终端4，如果有 Geyser 插件）
./multinode-demo/validator.sh --no-voting --rpc-port 8901 \
  --geyser-plugin-config /path/to/geyser-config.json
```

### 6.2 参数对比

| 需求 | multinode-demo 参数 |
|------|-------------------|
| **Validator 节点** | `./multinode-demo/bootstrap-validator.sh` |
| **RPC 节点** | `./multinode-demo/validator.sh --no-voting --rpc-port 8900` |
| **Indexer 节点** | `./multinode-demo/validator.sh --no-voting --geyser-plugin-config <path>` |

### 6.3 优势

- ✅ 自动管理密钥和创世区块
- ✅ 支持多节点集群
- ✅ 包含 faucet 服务
- ✅ 经过充分测试

---

## 7. 对比总结

### 7.1 参数对比表（本地部署）

| 参数 | Validator | RPC Node | Indexer |
|------|-----------|----------|---------|
| `--identity` | ✅ | ✅ | ✅ |
| `--vote-account` | ✅ | ❌ | ❌ |
| `--ledger` | ✅ | ✅ | ✅ |
| `--no-voting` | ❌ | ✅ | ✅ |
| `--entrypoint` | ❌ (首节点) | ✅ | ✅ |
| `--rpc-port` | 推荐 | ✅ | ✅ |
| `--geyser-plugin-config` | ❌ | ❌ | 可选 |

### 7.2 最小参数总结

#### Validator（Bootstrap）
```bash
agave-validator \
  --identity <path> \
  --vote-account <path> \
  --ledger <path>
```

#### RPC Node
```bash
agave-validator \
  --identity <path> \
  --ledger <path> \
  --no-voting \
  --entrypoint <validator-address>
```

#### Indexer Node
```bash
agave-validator \
  --identity <path> \
  --ledger <path> \
  --no-voting \
  --entrypoint <validator-address>
  # 可选: --geyser-plugin-config <path>
```

---

## 8. 常见问题

### Q1: 节点启动失败，提示端口已占用？

```bash
# 检查端口占用
lsof -i :8899
lsof -i :8900
lsof -i :8901

# 杀死占用端口的进程
kill -9 <PID>
```

### Q2: RPC 节点无法连接到 Validator？

确保：
1. Validator 已完全启动（等待 10-30 秒）
2. `--entrypoint` 地址正确（默认 `127.0.0.1:8001` 是 Validator 的 gossip 端口）
3. 防火墙允许本地连接

### Q3: 如何查看节点状态？

```bash
# 使用 Solana CLI
solana --url http://127.0.0.1:8899 validators

# 使用 RPC 调用
curl http://127.0.0.1:8899 -X POST -H "Content-Type: application/json" -d '
  {"jsonrpc":"2.0","id":1,"method":"getHealth"}
'
```

### Q4: 如何清理并重新开始？

```bash
# 停止所有节点
./stop-local-network.sh  # 或手动 kill 进程

# 删除所有数据
rm -rf test-ledger/

# 重新部署
./deploy-local-network.sh
```

---

## 9. 下一步

### 开发应用

```bash
# 配置 Solana CLI 使用本地网络
solana config set --url http://127.0.0.1:8899

# 创建钱包
solana-keygen new

# 请求空投（从 Validator 的 faucet）
solana airdrop 10

# 检查余额
solana balance

# 部署程序
solana program deploy <program.so>
```

### 性能测试

```bash
# 使用 bench-tps 进行压力测试
cd /home/yy/2024chain/2024takehome/solana-agave
./multinode-demo/bench-tps.sh
```

---

**文档版本**: v1.0  
**最后更新**: 2025年10月  
**适用环境**: 本地开发和测试
