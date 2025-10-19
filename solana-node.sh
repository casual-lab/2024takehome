#!/bin/bash
#
# Solana 本地节点管理脚本
# 支持启动三种类型的节点：Validator、RPC、Indexer
# 以及查看部署状态
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 默认配置
WORK_DIR="test-ledger"
SOLANA_ROOT="/home/yy/2024chain/2024takehome/solana-agave"
USE_TEST_VALIDATOR=true  # 默认使用 agave-validator
ENABLE_GEYSER=false  # 是否启用 Geyser 插件

# 使用说明
usage() {
    cat << EOF
${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Solana 本地节点管理工具
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${YELLOW}用法:${NC}
  $0 <command> [options] [--use-test-validator]

${YELLOW}命令:${NC}
  ${GREEN}init${NC}                初始化环境（生成密钥和创世区块）
  ${GREEN}start${NC} <type>        启动指定类型的节点
  ${GREEN}stop${NC} <type>         停止指定类型的节点
  ${GREEN}status${NC}              查看所有节点的运行状态
  ${GREEN}logs${NC} <type>         查看指定节点的日志
  ${GREEN}clean${NC}               清理所有数据和进程
  ${GREEN}test${NC}                测试网络连接

${YELLOW}节点类型 <type>:${NC}
  ${GREEN}validator${NC}           Validator 节点（参与共识）
  ${GREEN}rpc${NC}                 RPC 节点（提供 API 服务，不参与共识）
  ${GREEN}indexer${NC}             Indexer 节点（数据索引，不参与共识）
  ${GREEN}all${NC}                 所有节点

${YELLOW}选项:${NC}
  ${GREEN}--use-test-validator${NC}  使用 solana-test-validator (WSL 友好)
                          默认使用 agave-validator (需要足够权限)
  ${GREEN}--enable-geyser${NC}       启用 Geyser 插件（仅 Indexer 节点）
                          需要先创建插件配置文件

${YELLOW}示例:${NC}
  # 使用 agave-validator（默认，需要足够权限）
  $0 init
  $0 start validator

  # 使用 solana-test-validator（推荐用于 WSL）
  $0 init --use-test-validator
  $0 start validator --use-test-validator

  # 使用 Geyser 插件的 Indexer
  $0 start indexer --enable-geyser

  # 启动所有节点
  $0 start all

  # 查看状态
  $0 status

  # 停止节点
  $0 stop validator --use-test-validator

  # 查看日志
  $0 logs validator

  # 清理所有数据
  $0 clean

${YELLOW}端口分配:${NC}
  Validator RPC: ${CYAN}8899${NC}
  RPC Node:      ${CYAN}8900${NC}
  Indexer Node:  ${CYAN}8901${NC}

${YELLOW}工作目录:${NC}
  ${WORK_DIR}/

EOF
    exit 1
}

# 检查依赖
check_dependencies() {
    local missing=0
    
    if ! command -v agave-validator &> /dev/null; then
        echo -e "${RED}✗ agave-validator 未找到${NC}"
        echo -e "  请先编译: cd $SOLANA_ROOT && cargo build --release"
        missing=1
    fi
    
    if ! command -v solana-genesis &> /dev/null; then
        echo -e "${RED}✗ solana-genesis 未找到${NC}"
        missing=1
    fi
    
    if ! command -v solana-keygen &> /dev/null; then
        echo -e "${RED}✗ solana-keygen 未找到${NC}"
        missing=1
    fi
    
    if [[ $missing -eq 1 ]]; then
        exit 1
    fi
}

# 初始化环境
init_environment() {
    local mode="agave-validator"
    if [[ "$USE_TEST_VALIDATOR" == "true" ]]; then
        mode="solana-test-validator"
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  初始化 Solana 本地测试环境 (${mode})${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    # 检查是否已存在
    if [[ -d "$WORK_DIR" ]]; then
        echo -e "${YELLOW}⚠ 工作目录 $WORK_DIR 已存在${NC}"
        read -p "是否删除并重新初始化？[y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}[1/4] 清理旧数据...${NC}"
            rm -rf "$WORK_DIR"
        else
            echo -e "${RED}初始化已取消${NC}"
            exit 0
        fi
    else
        echo -e "${YELLOW}[1/4] 创建工作目录...${NC}"
    fi
    
    mkdir -p "$WORK_DIR"/{validator,rpc-node,indexer-node}
    echo -e "${GREEN}✓ 工作目录创建完成${NC}"
    echo
    
    echo -e "${YELLOW}[2/4] 生成密钥对...${NC}"
    
    # Validator 密钥
    echo -e "  生成 Validator 身份密钥..."
    solana-keygen new --outfile "$WORK_DIR/validator/identity.json" --no-bip39-passphrase --silent
    
    echo -e "  生成 Validator 投票账户密钥..."
    solana-keygen new --outfile "$WORK_DIR/validator/vote-account.json" --no-bip39-passphrase --silent
    
    echo -e "  生成 Validator 质押账户密钥..."
    solana-keygen new --outfile "$WORK_DIR/validator/stake-account.json" --no-bip39-passphrase --silent
    
    # RPC 节点密钥
    echo -e "  生成 RPC 节点身份密钥..."
    solana-keygen new --outfile "$WORK_DIR/rpc-node/identity.json" --no-bip39-passphrase --silent
    
    # Indexer 节点密钥
    echo -e "  生成 Indexer 节点身份密钥..."
    solana-keygen new --outfile "$WORK_DIR/indexer-node/identity.json" --no-bip39-passphrase --silent
    
    echo -e "${GREEN}✓ 所有密钥生成完成${NC}"
    echo
    
    echo -e "${YELLOW}[3/4] 创建创世区块...${NC}"
    solana-genesis \
        --bootstrap-validator \
            "$WORK_DIR/validator/identity.json" \
            "$WORK_DIR/validator/vote-account.json" \
            "$WORK_DIR/validator/stake-account.json" \
        --ledger "$WORK_DIR/validator" \
        --faucet-lamports 500000000000000 > /dev/null 2>&1
    
    echo -e "${GREEN}✓ 创世区块创建完成${NC}"
    echo
    
    echo -e "${YELLOW}[4/4] 保存配置...${NC}"
    
    # 保存节点信息
    VALIDATOR_PUBKEY=$(solana-keygen pubkey "$WORK_DIR/validator/identity.json")
    RPC_PUBKEY=$(solana-keygen pubkey "$WORK_DIR/rpc-node/identity.json")
    INDEXER_PUBKEY=$(solana-keygen pubkey "$WORK_DIR/indexer-node/identity.json")
    
    cat > "$WORK_DIR/node-info.txt" << EOF
Validator 公钥: $VALIDATOR_PUBKEY
RPC 节点公钥: $RPC_PUBKEY
Indexer 节点公钥: $INDEXER_PUBKEY
EOF
    
    echo -e "${GREEN}✓ 配置保存完成${NC}"
    echo
    
    # 如果启用 Geyser，创建示例配置
    if [[ "$ENABLE_GEYSER" == "true" ]]; then
        echo -e "${YELLOW}[额外] 创建 Geyser 插件配置...${NC}"
        create_geyser_config
        echo -e "${GREEN}✓ Geyser 配置创建完成${NC}"
        echo
    fi
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✓ 初始化完成！${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    echo -e "${CYAN}节点公钥:${NC}"
    echo -e "  Validator: ${YELLOW}$VALIDATOR_PUBKEY${NC}"
    echo -e "  RPC:       ${YELLOW}$RPC_PUBKEY${NC}"
    echo -e "  Indexer:   ${YELLOW}$INDEXER_PUBKEY${NC}"
    echo
    echo -e "${CYAN}下一步:${NC}"
    echo -e "  启动 Validator: ${GREEN}$0 start validator${NC}"
    echo -e "  启动所有节点:   ${GREEN}$0 start all${NC}"
    echo
}

# 创建 Geyser 插件配置文件
create_geyser_config() {
    cat > "$WORK_DIR/geyser-config.json" << 'EOF'
{
  "libpath": "PLUGIN_PATH_PLACEHOLDER",
  "accounts_selector": {
    "accounts": ["*"]
  },
  "transaction_selector": {
    "mentions": ["*"]
  }
}
EOF
    
    echo -e "  ${CYAN}配置文件: $WORK_DIR/geyser-config.json${NC}"
    echo -e "  ${YELLOW}注意: 这是一个示例配置${NC}"
    echo -e "  ${YELLOW}请根据实际的 Geyser 插件更新 'libpath' 字段${NC}"
}

# 启动 Validator 节点
start_validator() {
    if [[ "$USE_TEST_VALIDATOR" == "true" ]]; then
        start_validator_test_mode
        return
    fi
    
    echo -e "${YELLOW}启动 Validator 节点 (agave-validator)...${NC}"
    
    if [[ ! -d "$WORK_DIR/validator" ]]; then
        echo -e "${RED}✗ Validator 未初始化，请先运行: $0 init${NC}"
        exit 1
    fi
    
    # 检查是否已在运行
    if [[ -f "$WORK_DIR/validator.pid" ]]; then
        local pid=$(cat "$WORK_DIR/validator.pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${YELLOW}⚠ Validator 已在运行 (PID: $pid)${NC}"
            return 0
        fi
    fi
    
    # 启动节点
    agave-validator \
        --identity "$WORK_DIR/validator/identity.json" \
        --vote-account "$WORK_DIR/validator/vote-account.json" \
        --ledger "$WORK_DIR/validator" \
        --rpc-port 8899 \
        --no-os-network-limits-test \
        --no-os-memory-stats-reporting \
        --log "$WORK_DIR/validator.log" \
        > /dev/null 2>&1 &
    
    local pid=$!
    echo "$pid" > "$WORK_DIR/validator.pid"
    
    echo -e "${GREEN}✓ Validator 启动成功 (PID: $pid)${NC}"
    echo -e "  RPC 端口: ${CYAN}8899${NC}"
    echo -e "  日志文件: ${CYAN}$WORK_DIR/validator.log${NC}"
    
    # 等待就绪
    echo -n "  等待节点就绪"
    for i in {1..30}; do
        if curl -s http://127.0.0.1:8899 -X POST -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' > /dev/null 2>&1; then
            echo -e " ${GREEN}✓${NC}"
            return 0
        fi
        echo -n "."
        sleep 1
    done
    echo -e " ${YELLOW}(超时，但进程已启动)${NC}"
}

# 启动 Validator 节点 (test-validator 模式)
start_validator_test_mode() {
    echo -e "${YELLOW}启动 Validator 节点 (solana-test-validator)...${NC}"
    
    # 检查是否已在运行
    if [[ -f "$WORK_DIR/test-validator.pid" ]]; then
        local pid=$(cat "$WORK_DIR/test-validator.pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${YELLOW}⚠ Test Validator 已在运行 (PID: $pid)${NC}"
            return 0
        fi
    fi
    
    # 检查 solana-test-validator 是否存在
    if ! command -v solana-test-validator &> /dev/null; then
        echo -e "${RED}✗ solana-test-validator 未找到${NC}"
        echo -e "  请先编译: cd $SOLANA_ROOT && cargo build --release"
        exit 1
    fi
    
    # 创建工作目录
    mkdir -p "$WORK_DIR/test-validator-ledger"
    
    # 启动 test-validator
    solana-test-validator \
        --ledger "$WORK_DIR/test-validator-ledger" \
        --rpc-port 8899 \
        --log \
        > "$WORK_DIR/test-validator.log" 2>&1 &
    
    local pid=$!
    echo "$pid" > "$WORK_DIR/test-validator.pid"
    
    echo -e "${GREEN}✓ Test Validator 启动成功 (PID: $pid)${NC}"
    echo -e "  模式: ${CYAN}solana-test-validator (单节点，WSL 友好)${NC}"
    echo -e "  RPC 端口: ${CYAN}8899${NC}"
    echo -e "  WebSocket: ${CYAN}8900${NC}"
    echo -e "  Faucet: ${CYAN}9900${NC}"
    echo -e "  日志文件: ${CYAN}$WORK_DIR/test-validator.log${NC}"
    
    # 等待就绪
    echo -n "  等待节点就绪"
    for i in {1..30}; do
        if curl -s http://127.0.0.1:8899 -X POST -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' > /dev/null 2>&1; then
            echo -e " ${GREEN}✓${NC}"
            echo -e "${YELLOW}  注意: test-validator 模式下 RPC 和 Indexer 角色已集成${NC}"
            return 0
        fi
        echo -n "."
        sleep 1
    done
    echo -e " ${YELLOW}(超时，但进程已启动)${NC}"
}

# 启动 RPC 节点
start_rpc() {
    # if [[ "$USE_TEST_VALIDATOR" == "true" ]]; then
    #     echo -e "${YELLOW}⚠ test-validator 模式下无需单独启动 RPC 节点${NC}"
    #     echo -e "  RPC 功能已集成在 test-validator 中（端口 8899）"
    #     return 0
    # fi
    
    echo -e "${YELLOW}启动 RPC 节点...${NC}"
    
    if [[ ! -d "$WORK_DIR/rpc-node" ]]; then
        echo -e "${RED}✗ RPC 节点未初始化，请先运行: $0 init${NC}"
        exit 1
    fi
    
    # 检查 Validator PID 文件是否存在（宽松检查）
    if [[ ! -f "$WORK_DIR/validator.pid" ]]; then
        echo -e "${RED}✗ Validator 未运行，请先启动: $0 start validator${NC}"
        exit 1
    fi
    
    # 检查是否已在运行
    if [[ -f "$WORK_DIR/rpc-node.pid" ]]; then
        local pid=$(cat "$WORK_DIR/rpc-node.pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${YELLOW}⚠ RPC 节点已在运行 (PID: $pid)${NC}"
            return 0
        fi
    fi
    
    # 启动节点
    agave-validator \
        --identity "$WORK_DIR/rpc-node/identity.json" \
        --ledger "$WORK_DIR/rpc-node" \
        --no-voting \
        --entrypoint 127.0.0.1:8001 \
        --rpc-port 8900 \
        --no-os-network-limits-test \
        --no-os-memory-stats-reporting \
        --log "$WORK_DIR/rpc-node.log" \
        > /dev/null 2>&1 &
    
    local pid=$!
    echo "$pid" > "$WORK_DIR/rpc-node.pid"
    
    echo -e "${GREEN}✓ RPC 节点启动成功 (PID: $pid)${NC}"
    echo -e "  RPC 端口: ${CYAN}8900${NC}"
    echo -e "  日志文件: ${CYAN}$WORK_DIR/rpc-node.log${NC}"
}

# 启动 Indexer 节点
start_indexer() {
    # if [[ "$USE_TEST_VALIDATOR" == "true" ]]; then
    #     echo -e "${YELLOW}⚠ test-validator 模式下无需单独启动 Indexer 节点${NC}"
    #     echo -e "  Indexer 功能已集成在 test-validator 中（可通过 RPC 查询）"
    #     return 0
    # fi
    
    echo -e "${YELLOW}启动 Indexer 节点...${NC}"
    
    if [[ ! -d "$WORK_DIR/indexer-node" ]]; then
        echo -e "${RED}✗ Indexer 节点未初始化，请先运行: $0 init${NC}"
        exit 1
    fi
    
    # 检查 Validator PID 文件是否存在（宽松检查）
    if [[ ! -f "$WORK_DIR/validator.pid" ]]; then
        echo -e "${RED}✗ Validator 未运行，请先启动: $0 start validator${NC}"
        exit 1
    fi
    
    # 检查是否已在运行
    if [[ -f "$WORK_DIR/indexer-node.pid" ]]; then
        local pid=$(cat "$WORK_DIR/indexer-node.pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${YELLOW}⚠ Indexer 节点已在运行 (PID: $pid)${NC}"
            return 0
        fi
    fi
    
    # 构建启动命令
    local cmd="agave-validator \
        --identity \"$WORK_DIR/indexer-node/identity.json\" \
        --ledger \"$WORK_DIR/indexer-node\" \
        --no-voting \
        --entrypoint 127.0.0.1:8001 \
        --rpc-port 8901 \
        --no-os-network-limits-test \
        --no-os-memory-stats-reporting \
        --log \"$WORK_DIR/indexer-node.log\""
    
    # 如果启用 Geyser 插件
    if [[ "$ENABLE_GEYSER" == "true" ]]; then
        if [[ -f "$WORK_DIR/geyser-config.json" ]]; then
            cmd="$cmd --geyser-plugin-config \"$WORK_DIR/geyser-config.json\""
            echo -e "  ${GREEN}✓ Geyser 插件已启用${NC}"
        else
            echo -e "  ${YELLOW}⚠ Geyser 配置文件不存在: $WORK_DIR/geyser-config.json${NC}"
            echo -e "  ${YELLOW}  将以不带 Geyser 插件的模式启动${NC}"
            echo -e "  ${YELLOW}  运行 'init --enable-geyser' 创建配置文件${NC}"
        fi
    fi
    
    # 启动节点
    eval "$cmd > /dev/null 2>&1 &"
    
    local pid=$!
    echo "$pid" > "$WORK_DIR/indexer-node.pid"
    
    echo -e "${GREEN}✓ Indexer 节点启动成功 (PID: $pid)${NC}"
    echo -e "  RPC 端口: ${CYAN}8901${NC}"
    echo -e "  日志文件: ${CYAN}$WORK_DIR/indexer-node.log${NC}"
    
    if [[ "$ENABLE_GEYSER" == "true" ]] && [[ -f "$WORK_DIR/geyser-config.json" ]]; then
        echo -e "  Geyser 插件: ${GREEN}已启用${NC}"
    else
        echo -e "  ${YELLOW}注意: 未配置 Geyser 插件，仅同步区块链数据${NC}"
        echo -e "  ${YELLOW}      使用 --enable-geyser 启用插件功能${NC}"
    fi
}

# 启动所有节点
start_all() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  启动所有节点${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    start_validator
    echo
    
    sleep 2
    
    start_rpc
    echo
    
    start_indexer
    echo
    
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  ✓ 所有节点启动完成！${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 启动节点
start_node() {
    local type="$1"
    
    if [[ -z "$type" ]]; then
        echo -e "${RED}✗ 错误: 请指定节点类型${NC}"
        echo -e "用法: $0 start <validator|rpc|indexer|all>"
        exit 1
    fi
    
    case "$type" in
        validator)
            start_validator
            ;;
        rpc)
            start_rpc
            ;;
        indexer)
            start_indexer
            ;;
        all)
            start_all
            ;;
        *)
            echo -e "${RED}✗ 未知节点类型: $type${NC}"
            echo -e "支持的类型: validator, rpc, indexer, all"
            exit 1
            ;;
    esac
}

# 停止节点
stop_node() {
    local type="$1"
    
    if [[ -z "$type" ]]; then
        echo -e "${RED}✗ 错误: 请指定节点类型${NC}"
        echo -e "用法: $0 stop <validator|rpc|indexer|all>"
        exit 1
    fi
    
    case "$type" in
        validator)
            if [[ "$USE_TEST_VALIDATOR" == "true" ]]; then
                stop_single "test-validator" "Test Validator"
            else
                stop_single "validator" "Validator"
            fi
            ;;
        rpc)
            if [[ "$USE_TEST_VALIDATOR" == "true" ]]; then
                echo -e "${YELLOW}⚠ test-validator 模式下 RPC 已集成，无需单独停止${NC}"
            else
                stop_single "rpc-node" "RPC 节点"
            fi
            ;;
        indexer)
            if [[ "$USE_TEST_VALIDATOR" == "true" ]]; then
                echo -e "${YELLOW}⚠ test-validator 模式下 Indexer 已集成，无需单独停止${NC}"
            else
                stop_single "indexer-node" "Indexer 节点"
            fi
            ;;
        all)
            echo -e "${YELLOW}停止所有节点...${NC}"
            if [[ "$USE_TEST_VALIDATOR" == "true" ]]; then
                stop_single "test-validator" "Test Validator"
            else
                stop_single "indexer-node" "Indexer 节点"
                stop_single "rpc-node" "RPC 节点"
                stop_single "validator" "Validator"
            fi
            echo -e "${GREEN}✓ 所有节点已停止${NC}"
            ;;
        *)
            echo -e "${RED}✗ 未知节点类型: $type${NC}"
            exit 1
            ;;
    esac
}

# 停止单个节点
stop_single() {
    local node_dir="$1"
    local node_name="$2"
    local pid_file="$WORK_DIR/$node_dir.pid"
    
    if [[ ! -f "$pid_file" ]]; then
        echo -e "${YELLOW}⚠ $node_name 未运行（PID 文件不存在）${NC}"
        return 0
    fi
    
    local pid=$(cat "$pid_file")
    
    if ! kill -0 "$pid" 2>/dev/null; then
        echo -e "${YELLOW}⚠ $node_name 未运行（进程不存在）${NC}"
        rm -f "$pid_file"
        return 0
    fi
    
    kill "$pid" 2>/dev/null || true
    sleep 1
    
    # 如果进程仍在运行，强制杀死
    if kill -0 "$pid" 2>/dev/null; then
        kill -9 "$pid" 2>/dev/null || true
        sleep 1
    fi
    
    rm -f "$pid_file"
    echo -e "${GREEN}✓ $node_name 已停止 (PID: $pid)${NC}"
}

# 查看节点状态
show_status() {
    # 检测模式
    local mode="未知"
    if [[ -f "$WORK_DIR/test-validator.pid" ]]; then
        mode="solana-test-validator"
    elif [[ -f "$WORK_DIR/validator.pid" ]]; then
        mode="agave-validator"
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  Solana 本地网络状态 (${mode})${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    if [[ ! -d "$WORK_DIR" ]]; then
        echo -e "${RED}✗ 环境未初始化${NC}"
        echo -e "请先运行: ${GREEN}$0 init${NC}"
        echo
        return
    fi
    
    # 根据模式检查节点状态
    if [[ -f "$WORK_DIR/test-validator.pid" ]]; then
        # test-validator 模式
        check_node_status "test-validator" "Test Validator (集成模式)" "8899"
        echo -e "  ${CYAN}包含功能:${NC} Validator + RPC (8899) + WebSocket (8900) + Faucet (9900)"
        echo
    else
        # agave-validator 多节点模式
        check_node_status "validator" "Validator" "8899"
        echo
        check_node_status "rpc-node" "RPC 节点" "8900"
        echo
        check_node_status "indexer-node" "Indexer 节点" "8901"
        echo
    fi
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # 如果 Validator 在运行，获取区块链信息
    if [[ -f "$WORK_DIR/validator.pid" ]] && kill -0 $(cat "$WORK_DIR/validator.pid") 2>/dev/null; then
        echo
        echo -e "${CYAN}区块链信息:${NC}"
        
        # 获取当前 slot
        local slot=$(curl -s http://127.0.0.1:8899 -X POST -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' 2>/dev/null | \
            grep -o '"result":[0-9]*' | cut -d':' -f2)
        
        if [[ -n "$slot" ]]; then
            echo -e "  当前 Slot: ${GREEN}$slot${NC}"
        fi
        
        # 获取健康状态
        local health=$(curl -s http://127.0.0.1:8899 -X POST -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' 2>/dev/null)
        
        if echo "$health" | grep -q '"result":"ok"'; then
            echo -e "  健康状态: ${GREEN}正常${NC}"
        fi
        
        echo
    fi
}

# 检查单个节点状态
check_node_status() {
    local node_dir="$1"
    local node_name="$2"
    local rpc_port="$3"
    local pid_file="$WORK_DIR/$node_dir.pid"
    local log_file="$WORK_DIR/$node_dir.log"
    
    echo -e "${YELLOW}[$node_name]${NC}"
    
    if [[ ! -f "$pid_file" ]]; then
        echo -e "  状态: ${RED}未运行${NC}"
        return
    fi
    
    local pid=$(cat "$pid_file")
    
    if ! kill -0 "$pid" 2>/dev/null; then
        echo -e "  状态: ${RED}未运行${NC} (PID 文件存在但进程不存在)"
        return
    fi
    
    echo -e "  状态: ${GREEN}运行中${NC}"
    echo -e "  PID: ${CYAN}$pid${NC}"
    echo -e "  RPC 端口: ${CYAN}$rpc_port${NC}"
    
    # 检查端口是否在监听
    if netstat -tln 2>/dev/null | grep -q ":$rpc_port "; then
        echo -e "  端口监听: ${GREEN}✓${NC}"
    elif ss -tln 2>/dev/null | grep -q ":$rpc_port "; then
        echo -e "  端口监听: ${GREEN}✓${NC}"
    else
        echo -e "  端口监听: ${YELLOW}⚠ 未检测到${NC}"
    fi
    
    # 显示日志文件大小
    if [[ -f "$log_file" ]]; then
        local log_size=$(du -h "$log_file" | cut -f1)
        echo -e "  日志文件: ${CYAN}$log_file${NC} ($log_size)"
        
        # 显示最后一条错误（如果有）
        local last_error=$(grep -i "error\|fatal" "$log_file" 2>/dev/null | tail -1)
        if [[ -n "$last_error" ]]; then
            echo -e "  ${RED}最近错误:${NC} ${last_error:0:80}..."
        fi
    fi
}

# 查看日志
view_logs() {
    local type="$1"
    
    if [[ -z "$type" ]]; then
        echo -e "${RED}✗ 错误: 请指定节点类型${NC}"
        echo -e "用法: $0 logs <validator|rpc|indexer>"
        exit 1
    fi
    
    local log_file=""
    case "$type" in
        validator)
            log_file="$WORK_DIR/validator.log"
            ;;
        rpc)
            log_file="$WORK_DIR/rpc-node.log"
            ;;
        indexer)
            log_file="$WORK_DIR/indexer-node.log"
            ;;
        *)
            echo -e "${RED}✗ 未知节点类型: $type${NC}"
            exit 1
            ;;
    esac
    
    if [[ ! -f "$log_file" ]]; then
        echo -e "${RED}✗ 日志文件不存在: $log_file${NC}"
        exit 1
    fi
    
    echo -e "${CYAN}查看 $type 节点日志 (Ctrl+C 退出):${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    tail -f "$log_file"
}

# 测试网络
test_network() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  测试 Solana 本地网络${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    # 测试 Validator (8899)
    echo -e "${YELLOW}[1] 测试 Validator (端口 8899)${NC}"
    if curl -s http://127.0.0.1:8899 -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' | grep -q '"result":"ok"'; then
        echo -e "  ${GREEN}✓ Validator 连接正常${NC}"
        
        local slot=$(curl -s http://127.0.0.1:8899 -X POST -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","id":1,"method":"getSlot"}' | \
            grep -o '"result":[0-9]*' | cut -d':' -f2)
        echo -e "  当前 Slot: ${CYAN}$slot${NC}"
    else
        echo -e "  ${RED}✗ Validator 连接失败${NC}"
    fi
    echo
    
    # 测试 RPC 节点 (8900)
    echo -e "${YELLOW}[2] 测试 RPC 节点 (端口 8900)${NC}"
    if curl -s http://127.0.0.1:8900 -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ RPC 节点连接正常${NC}"
    else
        echo -e "  ${YELLOW}⚠ RPC 节点连接失败（可能未启动）${NC}"
    fi
    echo
    
    # 测试 Indexer 节点 (8901)
    echo -e "${YELLOW}[3] 测试 Indexer 节点 (端口 8901)${NC}"
    if curl -s http://127.0.0.1:8901 -X POST -H "Content-Type: application/json" \
        -d '{"jsonrpc":"2.0","id":1,"method":"getHealth"}' > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ Indexer 节点连接正常${NC}"
    else
        echo -e "  ${YELLOW}⚠ Indexer 节点连接失败（可能未启动）${NC}"
    fi
    echo
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# 清理所有数据
clean_all() {
    echo -e "${YELLOW}清理所有数据...${NC}"
    echo
    
    # 停止所有节点
    if [[ -d "$WORK_DIR" ]]; then
        echo -e "${YELLOW}停止所有运行的节点...${NC}"
        stop_node all
        echo
    fi
    
    # 删除工作目录
    if [[ -d "$WORK_DIR" ]]; then
        echo -e "${YELLOW}删除工作目录 $WORK_DIR...${NC}"
        rm -rf "$WORK_DIR"
        echo -e "${GREEN}✓ 工作目录已删除${NC}"
    else
        echo -e "${YELLOW}⚠ 工作目录不存在${NC}"
    fi
    
    echo
    echo -e "${GREEN}✓ 清理完成${NC}"
}

# 主函数
main() {
    # 检查参数
    if [[ $# -eq 0 ]]; then
        usage
    fi
    
    # 解析所有参数，提取标志和命令
    local command=""
    local args=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --use-test-validator)
                USE_TEST_VALIDATOR=true
                shift
                ;;
            --enable-geyser)
                ENABLE_GEYSER=true
                shift
                ;;
            help|--help|-h|init|start|stop|status|logs|test|clean)
                if [[ -z "$command" ]]; then
                    command="$1"
                else
                    args+=("$1")
                fi
                shift
                ;;
            *)
                args+=("$1")
                shift
                ;;
        esac
    done
    
    # 切换到脚本所在目录
    cd "$(dirname "$0")"
    
    # 添加 Solana 二进制文件到 PATH
    if [[ -d "$SOLANA_ROOT/target/release" ]]; then
        export PATH="$SOLANA_ROOT/target/release:$PATH"
    fi
    
    case "$command" in
        init)
            check_dependencies
            init_environment
            ;;
        start)
            check_dependencies
            start_node "${args[@]}"
            ;;
        stop)
            stop_node "${args[@]}"
            ;;
        status)
            show_status
            ;;
        logs)
            view_logs "${args[@]}"
            ;;
        test)
            test_network
            ;;
        clean)
            clean_all
            ;;
        help|--help|-h)
            usage
            ;;
        "")
            echo -e "${RED}✗ 错误: 未指定命令${NC}"
            echo
            usage
            ;;
        *)
            echo -e "${RED}✗ 未知命令: $command${NC}"
            echo
            usage
            ;;
    esac
}

# 执行主函数
main "$@"
