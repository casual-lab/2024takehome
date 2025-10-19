# Solana 节点配置指南 - 三种角色详解

> **基于源码**: 本文档基于 Solana Agave 源代码分析，所有配置参数均有源码支撑。

## 目录

1. [概述](#1-概述)
2. [Validator 节点配置](#2-validator-节点配置)
3. [RPC 节点配置](#3-rpc-节点配置)
4. [Indexer 节点配置](#4-indexer-节点配置)
5. [配置对比表](#5-配置对比表)
6. [实际部署建议](#6-实际部署建议)

---

## 1. 概述

Solana 节点可以配置为三种不同的角色：

### 1.1 角色定义

| 角色 | 功能 | 是否参与共识 | 主要用途 |
|------|------|------------|---------|
| **Validator** | 验证交易、出块、投票 | ✅ 是 | 维护网络共识 |
| **RPC Node** | 提供 JSON-RPC 和 WebSocket 服务 | ❌ 否 | 为应用提供查询接口 |
| **Indexer Node** | 采集事件和数据推送 | ❌ 否 | 数据分析和索引 |

### 1.2 架构说明

基于源码分析（[`core/src/validator.rs:605-650`](../core/src/validator.rs#L605-L650)），所有节点都运行相同的 `Validator` 进程，区别在于**启动参数配置**：

```rust
pub struct Validator {
    // 核心组件（所有节点都有）
    tpu: Tpu,                    // Transaction Processing Unit
    tvu: Tvu,                    // Transaction Validation Unit
    poh_service: PohService,     // Proof of History
    
    // RPC 服务（可选）
    json_rpc_service: Option<JsonRpcService>,
    pubsub_service: Option<PubSubService>,
    
    // Geyser 插件（可选）
    geyser_plugin_service: Option<GeyserPluginService>,
    
    // ... 其他组件
}
```

关键配置项（[`core/src/validator.rs:304-350`](../core/src/validator.rs#L304-L350)）：

```rust
pub struct ValidatorConfig {
    pub voting_disabled: bool,                              // 是否禁用投票
    pub rpc_addrs: Option<(SocketAddr, SocketAddr)>,      // RPC 地址
    pub rpc_config: JsonRpcConfig,                         // RPC 配置
    pub on_start_geyser_plugin_config_files: Option<Vec<PathBuf>>, // Geyser 插件
    // ... 更多配置
}
```

---

## 2. Validator 节点配置

### 2.1 功能说明

Validator 是**共识节点**，负责：
- 验证其他节点广播的交易和区块
- 作为 Leader 时打包交易并生成区块
- 投票参与 Tower BFT 共识
- 获得质押奖励（如果有质押）

源码参考：[`core/src/tpu.rs`](../core/src/tpu.rs) 和 [`core/src/tvu.rs`](../core/src/tvu.rs)

### 2.2 最小化配置示例

```bash
#!/bin/bash
# validator.sh - Validator 节点启动脚本

exec agave-validator \
    # === 身份和投票账户 ===
    --identity /home/sol/validator-keypair.json \
    --vote-account /home/sol/vote-account-keypair.json \
    --authorized-voter /home/sol/validator-keypair.json \
    \
    # === 网络连接 ===
    --entrypoint entrypoint.mainnet-beta.solana.com:8001 \
    --entrypoint entrypoint2.mainnet-beta.solana.com:8001 \
    --entrypoint entrypoint3.mainnet-beta.solana.com:8001 \
    \
    # === 可信验证者（用于快照下载） ===
    --known-validator 7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2 \
    --known-validator GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ \
    --known-validator DE1bawNcRJB9rVm3buyMVfr8mBEoyyu73NBovf2oXJsJ \
    --only-known-rpc \
    \
    # === 存储路径 ===
    --ledger /mnt/ledger \
    --accounts /mnt/accounts \
    --snapshots /mnt/snapshots \
    \
    # === 日志 ===
    --log /home/sol/validator.log \
    \
    # === 端口配置 ===
    --dynamic-port-range 8000-8020 \
    \
    # === 性能优化 ===
    --limit-ledger-size 50000000 \
    --block-production-method central-scheduler \
    \
    # === 监控（可选）===
    --rpc-port 8899 \
    --private-rpc \
    \
    # === 其他 ===
    --expected-genesis-hash 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d \
    --wal-recovery-mode skip_any_corrupted_record
```

### 2.3 关键参数说明

| 参数 | 必需 | 说明 | 源码参考 |
|------|------|------|----------|
| `--identity` | ✅ | 验证者身份密钥 | [`validator/src/commands/run/execute.rs`](../validator/src/commands/run/execute.rs) |
| `--vote-account` | ✅ | 投票账户公钥 | 同上 |
| `--authorized-voter` | ✅ | 授权投票者密钥 | 同上 |
| `--entrypoint` | ✅ | 集群入口点 | 同上 |
| `--known-validator` | 推荐 | 可信验证者（用于下载快照）| [`validator/src/bootstrap.rs:551-650`](../validator/src/bootstrap.rs#L551) |
| `--ledger` | ✅ | 账本存储路径 | 同上 |
| `--limit-ledger-size` | 推荐 | 限制账本大小（shreds 数量）| [`core/src/validator.rs:319`](../core/src/validator.rs#L319) |

### 2.4 注意事项

1. **硬件要求**（生产环境）：
   - CPU: 12+ 核心（建议 16 核）
   - RAM: 256GB+
   - 存储: 2TB+ NVMe SSD（账本） + 500GB+ SSD（账户）
   - 网络: 1Gbps+ 带宽

2. **不要同时运行 RPC 和共识**：
   - 参考源码注释：[`docs/src/operations/setup-an-rpc-node.md:22`](../docs/src/operations/setup-an-rpc-node.md#L22)
   - 原因：RPC 负载会影响共识性能，可能导致节点落后

3. **投票必须启用**：
   - 默认情况下 `voting_disabled = false`
   - 不要设置 `--no-voting` 标志

---

## 3. RPC 节点配置

### 3.1 功能说明

RPC 节点**不参与共识**，专门提供 JSON-RPC 和 WebSocket 服务，用于：
- 查询账户信息、余额
- 提交交易到网络
- 订阅实时事件
- 获取历史数据

源码参考：
- RPC 服务实现：[`rpc/src/rpc.rs`](../rpc/src/rpc.rs)
- PubSub 服务：[`rpc/src/rpc_pubsub_service.rs:40-65`](../rpc/src/rpc_pubsub_service.rs#L40)

### 3.2 完整配置示例

```bash
#!/bin/bash
# rpc-node.sh - RPC 节点启动脚本

exec agave-validator \
    # === 身份（不需要投票账户）===
    --identity /home/sol/rpc-keypair.json \
    \
    # === 禁用投票（关键！）===
    --no-voting \
    \
    # === 网络连接 ===
    --entrypoint entrypoint.mainnet-beta.solana.com:8001 \
    --entrypoint entrypoint2.mainnet-beta.solana.com:8001 \
    --entrypoint entrypoint3.mainnet-beta.solana.com:8001 \
    \
    # === 可信验证者 ===
    --known-validator 7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2 \
    --known-validator GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ \
    --known-validator DE1bawNcRJB9rVm3buyMVfr8mBEoyyu73NBovf2oXJsJ \
    --only-known-rpc \
    \
    # === 存储路径 ===
    --ledger /mnt/ledger \
    --accounts /mnt/accounts \
    --snapshots /mnt/snapshots \
    \
    # === RPC 配置（关键！）===
    --full-rpc-api \
    --rpc-port 8899 \
    --rpc-bind-address 0.0.0.0 \
    --private-rpc \
    \
    # === WebSocket 配置 ===
    --rpc-pubsub-enable-block-subscription \
    --rpc-pubsub-enable-vote-subscription \
    \
    # === 账户索引（重要！）===
    --account-index program-id \
    --account-index spl-token-owner \
    --account-index spl-token-mint \
    \
    # === 历史数据（可选）===
    --enable-rpc-transaction-history \
    --enable-cpi-and-log-storage \
    \
    # === BigTable（可选，用于历史数据）===
    # --enable-rpc-bigtable-ledger-storage \
    # --rpc-bigtable-instance production \
    \
    # === 性能优化 ===
    --limit-ledger-size 50000000 \
    --rpc-threads 16 \
    --rpc-max-multiple-accounts 100 \
    --rpc-niceness-adjustment -5 \
    \
    # === 日志 ===
    --log /home/sol/rpc.log \
    \
    # === 端口 ===
    --dynamic-port-range 8000-8020 \
    \
    # === 其他 ===
    --expected-genesis-hash 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d \
    --wal-recovery-mode skip_any_corrupted_record
```

### 3.3 关键参数说明

| 参数 | 必需 | 说明 | 源码参考 |
|------|------|------|----------|
| `--no-voting` | ✅ | **禁用投票，不参与共识** | [`core/src/validator.rs:307`](../core/src/validator.rs#L307) |
| `--full-rpc-api` | ✅ | 启用完整 RPC API | [`rpc/src/rpc.rs`](../rpc/src/rpc.rs) |
| `--rpc-port` | ✅ | RPC 监听端口 | [`core/src/validator.rs:309`](../core/src/validator.rs#L309) |
| `--rpc-bind-address` | 推荐 | 绑定地址（`0.0.0.0` 表示所有接口）| 同上 |
| `--private-rpc` | 推荐 | 不在 gossip 中发布 RPC 端口 | 文档：[`docs/src/operations/setup-an-rpc-node.md:24`](../docs/src/operations/setup-an-rpc-node.md#L24) |
| `--account-index` | 重要 | 启用账户索引（加速查询）| 文档：同上，89-100 行 |
| `--enable-rpc-transaction-history` | 可选 | 启用交易历史 | [`rpc/src/rpc.rs`](../rpc/src/rpc.rs) |

### 3.4 账户索引详解

源码：[`docs/src/operations/setup-an-rpc-node.md:89-100`](../docs/src/operations/setup-an-rpc-node.md#L89)

RPC 节点**强烈建议**启用账户索引以提高查询性能：

```bash
--account-index program-id       # 按 program ID 索引（getProgramAccounts）
--account-index spl-token-owner  # 按 token owner 索引（getTokenAccountsByOwner）
--account-index spl-token-mint   # 按 token mint 索引（getTokenAccountsByDelegate）
```

**不启用索引的后果**：
- `getProgramAccounts` 等查询会扫描全部账户，非常慢
- SPL Token 相关查询性能很差
- 可能导致 RPC 请求超时

### 3.5 硬件要求

**生产环境推荐配置**：
- CPU: 16+ 核心
- RAM: 256GB+（RPC 查询缓存需要大量内存）
- 存储: 2TB+ NVMe SSD
- 网络: 1Gbps+ 带宽

---

## 4. Indexer 节点配置

### 4.1 功能说明

Indexer 节点通过 **Geyser 插件**实时采集链上数据，用于：
- 实时事件流式传输
- 数据推送到外部数据库（PostgreSQL、Kafka 等）
- 自定义索引和分析
- 构建 DApp 后端

### 4.2 Geyser 插件架构

源码：[`geyser-plugin-interface/src/geyser_plugin_interface.rs:378-500`](../geyser-plugin-interface/src/geyser_plugin_interface.rs#L378)

```rust
pub trait GeyserPlugin: Any + Send + Sync + Debug {
    // 插件生命周期
    fn on_load(&mut self, config_file: &str, is_reload: bool) -> Result<()>;
    fn on_unload(&mut self);
    
    // 账户更新通知
    fn update_account(&self, account: ReplicaAccountInfoVersions, 
                      slot: Slot, is_startup: bool) -> Result<()>;
    
    // 交易通知
    fn notify_transaction(&self, transaction: ReplicaTransactionInfoVersions, 
                          slot: Slot) -> Result<()>;
    
    // 区块元数据通知
    fn notify_block_metadata(&self, blockinfo: ReplicaBlockInfoVersions) -> Result<()>;
    
    // Entry 通知
    fn notify_entry(&self, entry: ReplicaEntryInfoVersions) -> Result<()>;
    
    // Slot 状态更新
    fn update_slot_status(&self, slot: Slot, parent: Option<u64>, 
                          status: &SlotStatus) -> Result<()>;
    
    // 启用/禁用通知类型
    fn account_data_notifications_enabled(&self) -> bool;
    fn transaction_notifications_enabled(&self) -> bool;
    fn entry_notifications_enabled(&self) -> bool;
}
```

### 4.3 配置步骤

#### 步骤 1: 创建 Geyser 插件配置文件

创建 `/home/sol/geyser-plugin-config.json`:

```json
{
  "libpath": "/usr/local/lib/libmy_geyser_plugin.so",
  "log_level": "info",
  
  "accounts": {
    "enabled": true,
    "filters": [
      {
        "owner": ["TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"]
      }
    ]
  },
  
  "transactions": {
    "enabled": true
  },
  
  "blocks": {
    "enabled": true
  },
  
  "database": {
    "host": "localhost",
    "port": 5432,
    "user": "solana",
    "password": "your_password",
    "dbname": "solana_indexer",
    "connection_pool_size": 10
  }
}
```

源码中配置文件加载：[`geyser-plugin-manager/src/geyser_plugin_manager.rs:1-40`](../geyser-plugin-manager/src/geyser_plugin_manager.rs#L1)

#### 步骤 2: 配置节点启动脚本

```bash
#!/bin/bash
# indexer-node.sh - Indexer 节点启动脚本

exec agave-validator \
    # === 身份 ===
    --identity /home/sol/indexer-keypair.json \
    \
    # === 禁用投票（不参与共识）===
    --no-voting \
    \
    # === 网络连接 ===
    --entrypoint entrypoint.mainnet-beta.solana.com:8001 \
    --entrypoint entrypoint2.mainnet-beta.solana.com:8001 \
    --entrypoint entrypoint3.mainnet-beta.solana.com:8001 \
    \
    # === 可信验证者 ===
    --known-validator 7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2 \
    --known-validator GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ \
    --only-known-rpc \
    \
    # === 存储路径 ===
    --ledger /mnt/ledger \
    --accounts /mnt/accounts \
    --snapshots /mnt/snapshots \
    \
    # === Geyser 插件（关键！）===
    --geyser-plugin-config /home/sol/geyser-plugin-config.json \
    \
    # === RPC（可选，用于监控）===
    --rpc-port 8899 \
    --private-rpc \
    \
    # === 性能优化 ===
    --limit-ledger-size 50000000 \
    \
    # === 日志 ===
    --log /home/sol/indexer.log \
    \
    # === 端口 ===
    --dynamic-port-range 8000-8020 \
    \
    # === 其他 ===
    --expected-genesis-hash 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d \
    --wal-recovery-mode skip_any_corrupted_record
```

### 4.4 关键参数说明

| 参数 | 必需 | 说明 | 源码参考 |
|------|------|------|----------|
| `--geyser-plugin-config` | ✅ | Geyser 插件配置文件路径 | [`validator/src/commands/run/execute.rs:447-458`](../validator/src/commands/run/execute.rs#L447) |
| `--no-voting` | ✅ | 禁用投票（专注数据采集）| [`core/src/validator.rs:307`](../core/src/validator.rs#L307) |

源码中配置加载：
- 命令行参数解析：[`validator/src/commands/run/execute.rs:447`](../validator/src/commands/run/execute.rs#L447)
- 配置结构：[`core/src/validator.rs:313`](../core/src/validator.rs#L313)
- 服务初始化：[`geyser-plugin-manager/src/geyser_plugin_service.rs:45-85`](../geyser-plugin-manager/src/geyser_plugin_service.rs#L45)

### 4.5 实现自定义 Geyser 插件

#### 最小化插件示例

```rust
use {
    agave_geyser_plugin_interface::geyser_plugin_interface::{
        GeyserPlugin, GeyserPluginError, ReplicaAccountInfoVersions, 
        ReplicaTransactionInfoVersions, Result, SlotStatus,
    },
    std::fmt::Debug,
};

#[derive(Debug)]
pub struct MyIndexerPlugin {
    // 你的插件状态
}

impl GeyserPlugin for MyIndexerPlugin {
    fn name(&self) -> &'static str {
        "MyIndexerPlugin"
    }
    
    fn on_load(&mut self, config_file: &str, _is_reload: bool) -> Result<()> {
        // 加载配置，初始化数据库连接等
        println!("Loading plugin with config: {}", config_file);
        Ok(())
    }
    
    fn account_data_notifications_enabled(&self) -> bool {
        true  // 启用账户通知
    }
    
    fn transaction_notifications_enabled(&self) -> bool {
        true  // 启用交易通知
    }
    
    fn update_account(
        &self,
        account: ReplicaAccountInfoVersions,
        slot: u64,
        is_startup: bool,
    ) -> Result<()> {
        // 处理账户更新
        // 异步写入数据库或 Kafka
        Ok(())
    }
    
    fn notify_transaction(
        &self,
        transaction: ReplicaTransactionInfoVersions,
        slot: u64,
    ) -> Result<()> {
        // 处理交易通知
        Ok(())
    }
}

// 导出插件创建函数
#[no_mangle]
#[allow(improper_ctypes_definitions)]
pub unsafe extern "C" fn _create_plugin() -> *mut dyn GeyserPlugin {
    let plugin = MyIndexerPlugin::new();
    let plugin: Box<dyn GeyserPlugin> = Box::new(plugin);
    Box::into_raw(plugin)
}
```

编译为共享库：
```bash
cargo build --release --lib
# 生成 libmy_geyser_plugin.so
```

### 4.6 性能注意事项

源码文档：[`docs/src/validator/geyser.md:109-120`](../docs/src/validator/geyser.md#L109)

> **重要**：插件必须快速处理通知！
> 
> 当在交易处理期间调用 `update_account` 时，插件应尽可能快地处理通知，因为任何延迟都可能导致验证者落后于网络。**持久化到外部存储最好异步完成**。

**推荐做法**：
1. 使用异步队列缓冲数据
2. 批量写入数据库
3. 使用连接池
4. 监控插件延迟

### 4.7 硬件要求

- CPU: 12+ 核心
- RAM: 128GB+
- 存储: 1TB+ NVMe SSD
- 网络: 1Gbps+
- 外部数据库：根据数据量配置

---

## 5. 配置对比表

| 配置项 | Validator | RPC Node | Indexer Node |
|--------|-----------|----------|--------------|
| **身份密钥** | ✅ 需要 | ✅ 需要 | ✅ 需要 |
| **投票账户** | ✅ 需要 | ❌ 不需要 | ❌ 不需要 |
| **`--no-voting`** | ❌ 不设置 | ✅ **必须设置** | ✅ **必须设置** |
| **RPC 服务** | 可选（仅监控）| ✅ 完整 RPC | 可选（仅监控）|
| **`--full-rpc-api`** | ❌ | ✅ | ❌ |
| **`--account-index`** | ❌ | ✅ **强烈推荐** | ❌ |
| **Geyser 插件** | ❌ | ❌ | ✅ **必须配置** |
| **`--geyser-plugin-config`** | ❌ | ❌ | ✅ |
| **参与共识** | ✅ 是 | ❌ 否 | ❌ 否 |
| **获得奖励** | ✅ 是（如有质押）| ❌ 否 | ❌ 否 |
| **主要用途** | 维护网络 | 服务应用 | 数据分析 |

---

## 6. 实际部署建议

### 6.1 部署架构

推荐的生产环境架构：

```
              ┌─────────────────┐
              │   用户 / DApp   │
              └────────┬────────┘
                       │
              ┌────────▼────────┐
              │   负载均衡器     │
              └────────┬────────┘
                       │
         ┌─────────────┼─────────────┐
         │             │             │
    ┌────▼────┐   ┌────▼────┐   ┌────▼────┐
    │ RPC #1  │   │ RPC #2  │   │ RPC #3  │
    └─────────┘   └─────────┘   └─────────┘
         │             │             │
         └─────────────┼─────────────┘
                       │ (连接到网络)
         ┌─────────────▼─────────────┐
         │      Solana 网络           │
         │  (Validator 节点集群)      │
         └────────────────────────────┘
                       │
              ┌────────▼────────┐
              │  Indexer 节点   │
              └────────┬────────┘
                       │
              ┌────────▼────────┐
              │  PostgreSQL /   │
              │  Kafka / ES     │
              └─────────────────┘
```

### 6.2 节点数量建议

| 网络规模 | Validator | RPC Node | Indexer |
|---------|-----------|----------|---------|
| 测试环境 | 1 | 1 | 1 |
| 小规模生产 | 1 | 2-3 | 1 |
| 中规模生产 | 2+ | 5-10 | 2-3 |
| 大规模生产 | 多个 | 10+ | 3-5 |

### 6.3 监控指标

所有节点都应监控：

1. **系统指标**：
   - CPU 使用率
   - 内存使用率
   - 磁盘 I/O
   - 网络带宽

2. **Solana 特定指标**：
   - Slot 高度（是否跟上网络）
   - 交易处理速率（TPS）
   - RPC 请求延迟（RPC 节点）
   - 插件处理延迟（Indexer 节点）

监控命令：
```bash
# 查看节点状态
solana catchup <your-identity-pubkey>

# 查看 gossip 信息
solana gossip

# 查看投票账户（Validator）
solana vote-account <vote-account-pubkey>
```

### 6.4 安全建议

1. **防火墙配置**：
   ```bash
   # Validator: 仅开放必要端口
   # 8000-8020: 动态端口
   # 8001: Gossip
   
   # RPC Node: 开放 RPC 端口
   # 8899: JSON-RPC
   # 8900: WebSocket
   
   # Indexer: 无需开放公网端口
   ```

2. **密钥管理**：
   - 使用硬件钱包存储高价值密钥
   - 定期轮换密钥
   - 限制文件权限：`chmod 400 /path/to/keypair.json`

3. **访问控制**：
   - RPC 节点使用负载均衡器
   - 配置速率限制
   - 使用 `--private-rpc` 避免公开 RPC 端口

### 6.5 运维建议

1. **定期更新**：
   - 关注 Solana 版本更新
   - 测试环境先验证
   - 使用滚动更新避免停机

2. **备份策略**：
   - 定期备份账本和快照
   - 保存密钥的离线副本

3. **日志管理**：
   - 使用日志轮转（logrotate）
   - 集中化日志收集（ELK、Loki 等）

### 6.6 成本优化

1. **Validator**：
   - 使用 `--limit-ledger-size` 限制存储
   - 定期清理旧快照

2. **RPC Node**：
   - 启用 `--account-index` 仅针对需要的索引
   - 使用 BigTable 存储历史数据而非本地

3. **Indexer**：
   - 过滤不需要的账户和交易
   - 优化数据库查询
   - 使用数据压缩

---

## 7. 故障排查

### 7.1 常见问题

#### 问题 1: 节点落后（Slot 延迟）

**症状**：`solana catchup` 显示节点落后很多 slot

**可能原因**：
- 硬件性能不足
- 网络带宽不够
- RPC 负载过高（如果启用了 RPC）

**解决方案**：
```bash
# Validator: 确保没有运行 RPC 服务
# 检查是否设置了 --full-rpc-api（应该移除）

# 所有节点: 检查系统资源
top
iostat -x 1
iftop

# 优化配置
--limit-ledger-size 50000000  # 限制账本大小
--block-production-method central-scheduler  # 使用新调度器
```

#### 问题 2: RPC 请求超时

**症状**：`getProgramAccounts` 等请求超时

**解决方案**：
```bash
# 启用账户索引
--account-index program-id
--account-index spl-token-owner
--account-index spl-token-mint

# 增加 RPC 线程
--rpc-threads 16

# 降低优先级（让其他任务优先）
--rpc-niceness-adjustment -5
```

#### 问题 3: Geyser 插件导致节点变慢

**症状**：Indexer 节点 slot 延迟增加

**解决方案**：
- 检查插件代码：确保异步处理
- 监控插件延迟
- 减少插件处理的数据量（添加过滤器）
- 增加外部数据库性能

### 7.2 调试工具

```bash
# 查看节点日志
tail -f /home/sol/validator.log

# 查看性能统计
solana-validator monitor

# 查看账户信息
solana account <account-pubkey>

# 测试 RPC
curl -X POST -H "Content-Type: application/json" -d '
  {"jsonrpc":"2.0","id":1,"method":"getHealth"}
' http://localhost:8899

# 查看 Geyser 插件状态（Admin RPC）
curl -X POST -H "Content-Type: application/json" -d '
  {"jsonrpc":"2.0","id":1,"method":"geyserPluginList"}
' http://localhost:8899
```

---

## 8. 参考资源

### 8.1 源码参考

- Validator 配置：[`core/src/validator.rs`](../core/src/validator.rs)
- RPC 实现：[`rpc/src/`](../rpc/src/)
- Geyser 插件接口：[`geyser-plugin-interface/src/geyser_plugin_interface.rs`](../geyser-plugin-interface/src/geyser_plugin_interface.rs)
- Geyser 插件管理：[`geyser-plugin-manager/src/`](../geyser-plugin-manager/src/)

### 8.2 官方文档

- RPC 节点设置：[`docs/src/operations/setup-an-rpc-node.md`](../docs/src/operations/setup-an-rpc-node.md)
- Geyser 插件：[`docs/src/validator/geyser.md`](../docs/src/validator/geyser.md)
- Validator 设置：[`docs/src/operations/setup-a-validator.md`](../docs/src/operations/setup-a-validator.md)

### 8.3 社区资源

- Solana Discord: https://discord.gg/solana
- Solana Forums: https://forums.solana.com/
- GitHub Issues: https://github.com/anza-xyz/agave/issues

---

## 附录 A: 完整启动脚本模板

### Validator 节点完整脚本

```bash
#!/bin/bash
# Production Validator Node Startup Script

# Exit on error
set -e

# Environment variables
export SOLANA_METRICS_CONFIG="host=https://metrics.solana.com:8086,db=mainnet-beta,u=mainnet-beta_write,p=password"
export RUST_LOG=info
export RUST_BACKTRACE=1

# Paths
IDENTITY_KEYPAIR="/home/sol/validator-keypair.json"
VOTE_ACCOUNT_KEYPAIR="/home/sol/vote-account-keypair.json"
LEDGER_PATH="/mnt/ledger"
ACCOUNTS_PATH="/mnt/accounts"
SNAPSHOTS_PATH="/mnt/snapshots"
LOG_PATH="/home/sol/validator.log"

# Network
ENTRYPOINT1="entrypoint.mainnet-beta.solana.com:8001"
ENTRYPOINT2="entrypoint2.mainnet-beta.solana.com:8001"
ENTRYPOINT3="entrypoint3.mainnet-beta.solana.com:8001"

# Known validators (for snapshot download)
KNOWN_VALIDATOR1="7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2"
KNOWN_VALIDATOR2="GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ"
KNOWN_VALIDATOR3="DE1bawNcRJB9rVm3buyMVfr8mBEoyyu73NBovf2oXJsJ"

exec agave-validator \
    --identity "$IDENTITY_KEYPAIR" \
    --vote-account "$VOTE_ACCOUNT_KEYPAIR" \
    --authorized-voter "$IDENTITY_KEYPAIR" \
    --entrypoint "$ENTRYPOINT1" \
    --entrypoint "$ENTRYPOINT2" \
    --entrypoint "$ENTRYPOINT3" \
    --known-validator "$KNOWN_VALIDATOR1" \
    --known-validator "$KNOWN_VALIDATOR2" \
    --known-validator "$KNOWN_VALIDATOR3" \
    --only-known-rpc \
    --ledger "$LEDGER_PATH" \
    --accounts "$ACCOUNTS_PATH" \
    --snapshots "$SNAPSHOTS_PATH" \
    --log "$LOG_PATH" \
    --rpc-port 8899 \
    --private-rpc \
    --dynamic-port-range 8000-8020 \
    --limit-ledger-size 50000000 \
    --block-production-method central-scheduler \
    --expected-genesis-hash 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d \
    --wal-recovery-mode skip_any_corrupted_record \
    --snapshot-interval-slots 500 \
    --maximum-snapshots-to-retain 5
```

### RPC 节点完整脚本

```bash
#!/bin/bash
# Production RPC Node Startup Script

set -e

export SOLANA_METRICS_CONFIG="host=https://metrics.solana.com:8086,db=mainnet-beta,u=mainnet-beta_write,p=password"
export RUST_LOG=info

IDENTITY_KEYPAIR="/home/sol/rpc-keypair.json"
LEDGER_PATH="/mnt/ledger"
ACCOUNTS_PATH="/mnt/accounts"
LOG_PATH="/home/sol/rpc.log"

exec agave-validator \
    --identity "$IDENTITY_KEYPAIR" \
    --no-voting \
    --entrypoint entrypoint.mainnet-beta.solana.com:8001 \
    --entrypoint entrypoint2.mainnet-beta.solana.com:8001 \
    --known-validator 7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2 \
    --known-validator GdnSyH3YtwcxFvQrVVJMm1JhTS4QVX7MFsX56uJLUfiZ \
    --only-known-rpc \
    --ledger "$LEDGER_PATH" \
    --accounts "$ACCOUNTS_PATH" \
    --log "$LOG_PATH" \
    --full-rpc-api \
    --rpc-port 8899 \
    --rpc-bind-address 0.0.0.0 \
    --private-rpc \
    --rpc-pubsub-enable-block-subscription \
    --rpc-pubsub-enable-vote-subscription \
    --account-index program-id \
    --account-index spl-token-owner \
    --account-index spl-token-mint \
    --enable-rpc-transaction-history \
    --enable-cpi-and-log-storage \
    --limit-ledger-size 50000000 \
    --rpc-threads 16 \
    --rpc-max-multiple-accounts 100 \
    --rpc-niceness-adjustment -5 \
    --dynamic-port-range 8000-8020 \
    --expected-genesis-hash 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d \
    --wal-recovery-mode skip_any_corrupted_record
```

### Indexer 节点完整脚本

```bash
#!/bin/bash
# Production Indexer Node with Geyser Plugin

set -e

export RUST_LOG=info

IDENTITY_KEYPAIR="/home/sol/indexer-keypair.json"
GEYSER_CONFIG="/home/sol/geyser-plugin-config.json"
LEDGER_PATH="/mnt/ledger"
ACCOUNTS_PATH="/mnt/accounts"
LOG_PATH="/home/sol/indexer.log"

exec agave-validator \
    --identity "$IDENTITY_KEYPAIR" \
    --no-voting \
    --entrypoint entrypoint.mainnet-beta.solana.com:8001 \
    --known-validator 7Np41oeYqPefeNQEHSv1UDhYrehxin3NStELsSKCT4K2 \
    --only-known-rpc \
    --ledger "$LEDGER_PATH" \
    --accounts "$ACCOUNTS_PATH" \
    --log "$LOG_PATH" \
    --geyser-plugin-config "$GEYSER_CONFIG" \
    --rpc-port 8899 \
    --private-rpc \
    --limit-ledger-size 50000000 \
    --dynamic-port-range 8000-8020 \
    --expected-genesis-hash 5eykt4UsFv8P8NJdTREpY1vzqKqZKvdpKuc147dw2N9d \
    --wal-recovery-mode skip_any_corrupted_record
```

---

**文档版本**: v1.0  
**最后更新**: 2025年  
**基于**: Solana Agave 源代码分析  
