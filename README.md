# Solana 本地节点管理工具

一个简单易用的 Solana 本地测试网络管理脚本，支持一键部署和管理三种类型的节点。

## 🚀 快速开始

### 1. 初始化环境

```bash
./solana-node.sh init
```

这将：
- 生成所有必要的密钥对
- 创建创世区块
- 设置工作目录结构

### 2. 启动节点

```bash
# 启动 Validator 节点（必须先启动）
./solana-node.sh start validator

# 启动 RPC 节点
./solana-node.sh start rpc

# 启动 Indexer 节点
./solana-node.sh start indexer

# 或者一键启动所有节点
./solana-node.sh start all
```

### 3. 查看状态

```bash
./solana-node.sh status
```

输出示例：
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Solana 本地网络状态
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[Validator]
  状态: 运行中
  PID: 12345
  RPC 端口: 8899
  端口监听: ✓

[RPC 节点]
  状态: 运行中
  PID: 12346
  RPC 端口: 8900
  端口监听: ✓

[Indexer 节点]
  状态: 运行中
  PID: 12347
  RPC 端口: 8901
  端口监听: ✓

区块链信息:
  当前 Slot: 1234
  健康状态: 正常
```

## 📋 所有命令

### 基本命令

| 命令 | 说明 | 示例 |
|------|------|------|
| `init` | 初始化环境 | `./solana-node.sh init` |
| `start <type>` | 启动节点 | `./solana-node.sh start validator` |
| `stop <type>` | 停止节点 | `./solana-node.sh stop rpc` |
| `status` | 查看状态 | `./solana-node.sh status` |
| `logs <type>` | 查看日志 | `./solana-node.sh logs validator` |
| `test` | 测试网络 | `./solana-node.sh test` |
| `clean` | 清理所有数据 | `./solana-node.sh clean` |

### 节点类型

| 类型 | 说明 | 参与共识 | RPC 端口 |
|------|------|---------|---------|
| `validator` | Validator 节点 | ✅ 是 | 8899 |
| `rpc` | RPC 节点 | ❌ 否 | 8900 |
| `indexer` | Indexer 节点 | ❌ 否 | 8901 |
| `all` | 所有节点 | - | - |

## 🎯 使用场景

### 场景 1: 开发测试（仅 Validator）

```bash
# 1. 初始化
./solana-node.sh init

# 2. 启动 Validator
./solana-node.sh start validator

# 3. 配置 Solana CLI
solana config set --url http://127.0.0.1:8899

# 4. 测试
solana cluster-version
```

### 场景 2: 完整开发环境（三个节点）

```bash
# 1. 初始化并启动所有节点
./solana-node.sh init
./solana-node.sh start all

# 2. 查看状态
./solana-node.sh status

# 3. 测试连接
./solana-node.sh test
```

### 场景 3: 调试特定节点

```bash
# 启动 Validator
./solana-node.sh start validator

# 在另一个终端查看实时日志
./solana-node.sh logs validator

# 停止并重启
./solana-node.sh stop validator
./solana-node.sh start validator
```

## 📊 端口映射

| 节点 | RPC 端口 | Gossip 端口 | 用途 |
|------|---------|------------|------|
| Validator | 8899 | 8001 (自动) | 共识 + RPC |
| RPC Node | 8900 | 自动分配 | 仅 RPC 服务 |
| Indexer | 8901 | 自动分配 | 数据索引 |

## 📁 目录结构

```
2024takehome/
├── solana-node.sh          # 主管理脚本
├── README.md               # 本文档
└── test-ledger/            # 工作目录（自动创建）
    ├── validator/
    │   ├── identity.json
    │   ├── vote-account.json
    │   └── ...（账本数据）
    ├── rpc-node/
    │   ├── identity.json
    │   └── ...（账本数据）
    ├── indexer-node/
    │   ├── identity.json
    │   └── ...（账本数据）
    ├── validator.log       # Validator 日志
    ├── rpc-node.log        # RPC 节点日志
    ├── indexer-node.log    # Indexer 节点日志
    ├── validator.pid       # PID 文件
    ├── rpc-node.pid
    ├── indexer-node.pid
    └── node-info.txt       # 节点公钥信息
```

## 🔧 高级用法

### 查看实时日志

```bash
# Validator 日志
./solana-node.sh logs validator

# RPC 节点日志
./solana-node.sh logs rpc

# Indexer 节点日志
./solana-node.sh logs indexer
```

### 测试网络连接

```bash
./solana-node.sh test
```

输出：
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  测试 Solana 本地网络
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1] 测试 Validator (端口 8899)
  ✓ Validator 连接正常
  当前 Slot: 1234

[2] 测试 RPC 节点 (端口 8900)
  ✓ RPC 节点连接正常

[3] 测试 Indexer 节点 (端口 8901)
  ✓ Indexer 节点连接正常
```

### 使用 curl 测试 RPC

```bash
# 测试 Validator (8899)
curl http://127.0.0.1:8899 -X POST -H "Content-Type: application/json" -d '
  {"jsonrpc":"2.0","id":1,"method":"getHealth"}
'

# 测试 RPC 节点 (8900)
curl http://127.0.0.1:8900 -X POST -H "Content-Type: application/json" -d '
  {"jsonrpc":"2.0","id":1,"method":"getSlot"}
'

# 测试 Indexer 节点 (8901)
curl http://127.0.0.1:8901 -X POST -H "Content-Type: application/json" -d '
  {"jsonrpc":"2.0","id":1,"method":"getHealth"}
'
```

## 🛠️ 故障排查

### 问题 1: 端口已被占用

```bash
# 检查端口占用
lsof -i :8899
lsof -i :8900
lsof -i :8901

# 停止所有节点
./solana-node.sh stop all

# 或者手动杀死进程
kill -9 <PID>
```

### 问题 2: 节点启动失败

```bash
# 查看日志
./solana-node.sh logs validator

# 或直接查看日志文件
tail -f test-ledger/validator.log
```

### 问题 3: 清理并重新开始

```bash
# 停止所有节点并清理数据
./solana-node.sh clean

# 重新初始化
./solana-node.sh init

# 启动节点
./solana-node.sh start all
```

## 📝 完整工作流示例

```bash
# 1. 初始化环境
./solana-node.sh init

# 2. 启动所有节点
./solana-node.sh start all

# 3. 查看状态
./solana-node.sh status

# 4. 测试网络
./solana-node.sh test

# 5. 配置 Solana CLI
solana config set --url http://127.0.0.1:8899

# 6. 创建钱包
solana-keygen new

# 7. 请求空投（如果有 faucet）
solana airdrop 10

# 8. 查看余额
solana balance

# --- 开发工作 ---

# 9. 停止节点（完成后）
./solana-node.sh stop all

# 10. 清理数据（如果需要）
./solana-node.sh clean
```

## 🎨 脚本特性

- ✅ **彩色输出**: 清晰的状态指示
- ✅ **错误处理**: 完善的错误检查和提示
- ✅ **PID 管理**: 自动追踪进程状态
- ✅ **依赖检查**: 启动前验证二进制文件
- ✅ **智能等待**: 自动等待节点就绪
- ✅ **日志管理**: 独立的日志文件
- ✅ **状态监控**: 实时显示节点和区块链状态
- ✅ **网络测试**: 内置连接测试功能

## 📖 参考资源

### 相关文档

- [完整配置指南](solana-agave/notes/node_configuration_guide.md) - 生产环境配置
- [本地部署指南](solana-agave/notes/local_network_deployment.md) - 详细部署说明
- [架构分析](solana-agave/notes/solana_architecture_analysis.md) - 代码架构分析

### Solana CLI 常用命令

```bash
# 配置网络
solana config set --url http://127.0.0.1:8899

# 查看配置
solana config get

# 查看集群版本
solana cluster-version

# 查看验证者
solana validators

# 查看当前 slot
solana slot

# 查看账户余额
solana balance <ADDRESS>

# 请求空投
solana airdrop 10

# 转账
solana transfer <TO_ADDRESS> <AMOUNT>
```

## 🚨 注意事项

1. **Validator 必须先启动**: RPC 和 Indexer 节点依赖 Validator 的 gossip 服务
2. **端口冲突**: 确保 8899、8900、8901 端口未被占用
3. **仅用于开发**: 此配置仅适用于本地开发，不适合生产环境
4. **数据持久化**: `test-ledger/` 目录包含所有区块链数据，删除后需重新初始化
5. **Indexer 插件**: 当前版本未配置 Geyser 插件，仅同步区块链数据

## 🤝 贡献

如需添加新功能或报告问题，请查看源码注释或联系开发者。

---

**版本**: 1.0  
**最后更新**: 2025年10月18日  
**维护者**: 2024takehome
