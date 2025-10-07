#!/bin/bash
# ============================================
# ARCIUM MULTI-NODE SETUP SCRIPT
# Tạo keypair, config cho nhiều nodes
# Sử dụng: ./setup-nodes.sh <số_node>
# ============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

NUM_NODES=${1:-5}
RPC_URL="https://api.devnet.solana.com"
OFFSET_FILE="offsets-used.txt"

# Hàm tạo offset ngẫu nhiên và kiểm tra trùng
generate_unique_offset() {
    local offset
    local max_attempts=100
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        offset=$((100000000 + RANDOM))
        
        if [ -f "$OFFSET_FILE" ] && grep -q "^$offset$" "$OFFSET_FILE"; then
            attempt=$((attempt + 1))
            continue
        fi
        
        echo -e "    ${CYAN}→${NC} Kiểm tra offset $offset trên chain..." >&2
        
        if arcium arx-info $offset --rpc-url $RPC_URL 2>&1 | grep -q "Error"; then
            echo "$offset" >> "$OFFSET_FILE"
            echo "$offset"
            return 0
        else
            echo -e "    ${YELLOW}→${NC} Offset $offset đã dùng, thử lại..." >&2
            attempt=$((attempt + 1))
        fi
    done
    
    echo -e "${RED}✗ Không thể tạo offset sau $max_attempts lần thử!${NC}" >&2
    exit 1
}

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${GREEN}   ARCIUM MULTI-NODE SETUP SCRIPT   ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo -e "${YELLOW}Số node: $NUM_NODES${NC}\n"

# Lấy IP
echo -e "${BLUE}[1/5]${NC} Lấy IP VPS..."
IP_ADDRESS=$(curl -4 -s https://ipecho.net/plain)
if [ -z "$IP_ADDRESS" ]; then
    IP_ADDRESS=$(curl -4 -s ifconfig.me)
fi
if [ -z "$IP_ADDRESS" ]; then
    echo -e "${RED}✗ Không thể lấy IPv4!${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} IP: ${GREEN}$IP_ADDRESS${NC}\n"

# Tạo file backup
echo -e "${BLUE}[2/5]${NC} Tạo file backup..."
WALLET_BACKUP="wallets-backup.txt"
cat > $WALLET_BACKUP << EOF
╔════════════════════════════════════════╗
║     ARCIUM NODES WALLET BACKUP         ║
╚════════════════════════════════════════╝
IP VPS: $IP_ADDRESS
Date: $(date)
Total Nodes: $NUM_NODES

EOF

touch $OFFSET_FILE

EXISTING_NODES=0
for dir in node-*/; do
    [ -d "$dir" ] && EXISTING_NODES=$((EXISTING_NODES + 1))
done

if [ $EXISTING_NODES -gt 0 ]; then
    echo -e "${YELLOW}Phát hiện $EXISTING_NODES node cũ${NC}"
    echo -e "${YELLOW}Sẽ tạo thêm $((NUM_NODES - EXISTING_NODES)) node mới${NC}\n"
    START_INDEX=$((EXISTING_NODES + 1))
else
    START_INDEX=1
fi

# Tạo nodes
echo -e "${BLUE}[3/5]${NC} Tạo nodes...\n"

for i in $(seq $START_INDEX $NUM_NODES); do
    NODE_DIR="node-$i"
    
    if [ -d "$NODE_DIR" ]; then
        echo -e "${YELLOW}Node $i đã tồn tại, bỏ qua...${NC}\n"
        continue
    fi
    
    echo -e "${CYAN}╔══ NODE $i ══╗${NC}"
    
    NODE_OFFSET=$(generate_unique_offset)
    echo -e "${GREEN}✓${NC} Offset: ${GREEN}$NODE_OFFSET${NC}"
    
    mkdir -p $NODE_DIR/logs
    cd $NODE_DIR
    
    echo -e "${CYAN}→${NC} Tạo keypair..."
    
    # Tạo node keypair VÀ lưu mnemonic
    solana-keygen new --outfile node-keypair.json --no-bip39-passphrase 2>&1 | tee node-keypair-seed.txt > /dev/null
    NODE_SEED=$(grep -A 1 "pubkey:" node-keypair-seed.txt | tail -1 | xargs)
    
    # Tạo callback keypair VÀ lưu mnemonic
    solana-keygen new --outfile callback-kp.json --no-bip39-passphrase 2>&1 | tee callback-kp-seed.txt > /dev/null
    CALLBACK_SEED=$(grep -A 1 "pubkey:" callback-kp-seed.txt | tail -1 | xargs)
    
    openssl genpkey -algorithm Ed25519 -out identity.pem 2>/dev/null
    
    NODE_ADDR=$(solana address --keypair node-keypair.json)
    CALLBACK_ADDR=$(solana address --keypair callback-kp.json)
    
    cat >> ../$WALLET_BACKUP << EOF
────────────────────────────────────────
NODE $i (Offset: $NODE_OFFSET)
────────────────────────────────────────
Node Wallet:     $NODE_ADDR
Callback Wallet: $CALLBACK_ADDR
Faucet: https://faucet.solana.com

EOF
    
    echo -e "${GREEN}✓${NC} Node:     ${YELLOW}$NODE_ADDR${NC}"
    echo -e "${GREEN}✓${NC} Callback: ${YELLOW}$CALLBACK_ADDR${NC}"
    
    cat > node-config.toml <<EOF
[node]
offset = $NODE_OFFSET
hardware_claim = 0
starting_epoch = 0
ending_epoch = 9223372036854775807

[network]
address = "0.0.0.0"

[solana]
endpoint_rpc = "$RPC_URL"
endpoint_wss = "wss://api.devnet.solana.com"
cluster = "Devnet"
commitment.commitment = "confirmed"
EOF
    
    echo -e "${GREEN}✓${NC} Config tạo xong\n"
    cd ..
done

# Tạo docker-compose.yml
echo -e "${BLUE}[4/5]${NC} Tạo docker-compose.yml..."
if [ -f "generate-compose.sh" ]; then
    bash generate-compose.sh $NUM_NODES 8080 > /dev/null 2>&1
    echo -e "${GREEN}✓${NC} Docker compose đã tạo\n"
else
    echo -e "${YELLOW}⚠${NC}  Chưa có generate-compose.sh, bỏ qua\n"
fi

# Tạo script check balance
echo -e "${BLUE}[5/5]${NC} Tạo script tiện ích..."
cat > check-balance.sh << 'EOFCHECK'
#!/bin/bash
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}════════ KIỂM TRA BALANCE ════════${NC}\n"

TOTAL_OK=0
TOTAL_LOW=0

for dir in node-*/; do
    [ ! -d "$dir" ] && continue
    i=$(echo $dir | grep -o '[0-9]*')
    
    node_bal=$(solana balance --keypair $dir/node-keypair.json 2>/dev/null | awk '{print $1}')
    callback_bal=$(solana balance --keypair $dir/callback-kp.json 2>/dev/null | awk '{print $1}')
    
    echo -e "${YELLOW}Node $i:${NC}"
    
    if (( $(echo "$node_bal >= 0.5" | bc -l) )); then
        echo -e "  Node:     ${GREEN}$node_bal SOL ✓${NC}"
        TOTAL_OK=$((TOTAL_OK + 1))
    else
        echo -e "  Node:     ${RED}$node_bal SOL ✗ CẦN AIRDROP!${NC}"
        TOTAL_LOW=$((TOTAL_LOW + 1))
    fi
    
    if (( $(echo "$callback_bal >= 0.5" | bc -l) )); then
        echo -e "  Callback: ${GREEN}$callback_bal SOL ✓${NC}"
        TOTAL_OK=$((TOTAL_OK + 1))
    else
        echo -e "  Callback: ${RED}$callback_bal SOL ✗ CẦN AIRDROP!${NC}"
        TOTAL_LOW=$((TOTAL_LOW + 1))
    fi
    echo ""
done

echo -e "${BLUE}════════════════════════════════════${NC}"
echo -e "${GREEN}OK: $TOTAL_OK${NC} | ${RED}Cần airdrop: $TOTAL_LOW${NC}"
EOFCHECK

chmod +x check-balance.sh
echo -e "${GREEN}✓${NC} check-balance.sh đã tạo\n"

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          SETUP HOÀN THÀNH!             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}📋 DANH SÁCH OFFSET:${NC}"
cat $OFFSET_FILE | nl
echo ""

echo -e "${CYAN}═══ BƯỚC TIẾP THEO ═══${NC}"
echo -e "${BLUE}1.${NC} Xem ví cần airdrop:"
echo -e "   ${GREEN}cat wallets-backup.txt${NC}"
echo -e "${BLUE}2.${NC} Airdrop SOL tại:"
echo -e "   ${GREEN}https://faucet.solana.com${NC}"
echo -e "${BLUE}3.${NC} Kiểm tra balance:"
echo -e "   ${GREEN}./check-balance.sh${NC}"
echo -e "${BLUE}4.${NC} Init nodes:"
echo -e "   ${GREEN}./init-nodes.sh $NUM_NODES${NC}"
echo -e "${BLUE}5.${NC} Chạy nodes:"
echo -e "   ${GREEN}docker-compose up -d${NC}\n"

echo -e "${RED}⚠️  QUAN TRỌNG:${NC} Backup file ${GREEN}$WALLET_BACKUP${NC} và ${GREEN}$OFFSET_FILE${NC}!"
