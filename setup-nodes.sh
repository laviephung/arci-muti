#!/bin/bash

# Script tự động setup nhiều node Arcium với random offset
# Sử dụng: ./setup-nodes.sh <số_node>

set -e

# Màu sắc
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Số node muốn tạo (mặc định 5)
NUM_NODES=${1:-5}
RPC_URL="https://api.devnet.solana.com"
OFFSET_FILE="offsets-used.txt"

# Hàm tạo offset ngẫu nhiên và kiểm tra trùng
generate_unique_offset() {
    local offset
    local max_attempts=100
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        # Tạo số ngẫu nhiên từ 100000000 đến 100032767
        offset=$((100000000 + RANDOM))
        
        # Kiểm tra xem offset đã tồn tại trong file chưa
        if [ -f "$OFFSET_FILE" ] && grep -q "^$offset$" "$OFFSET_FILE"; then
            attempt=$((attempt + 1))
            continue
        fi
        
        # Kiểm tra trên chain xem offset đã được dùng chưa
        echo -e "    ${BLUE}→${NC} Đang kiểm tra offset $offset trên chain..." >&2
        
        if arcium arx-info $offset --rpc-url $RPC_URL 2>&1 | grep -q "Error"; then
            # Offset chưa được dùng
            echo "$offset" >> "$OFFSET_FILE"
            echo "$offset"
            return 0
        else
            echo -e "    ${YELLOW}→${NC} Offset $offset đã được dùng, tạo mới..." >&2
            attempt=$((attempt + 1))
        fi
    done
    
    echo -e "${RED}✗ Không thể tạo offset sau $max_attempts lần thử!${NC}" >&2
    exit 1
}

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}   ARCIUM MULTI-NODE SETUP SCRIPT${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Số node sẽ tạo: $NUM_NODES${NC}\n"

# Lấy IP VPS
echo -e "${BLUE}[1/6]${NC} Đang lấy IP VPS..."
IP_ADDRESS=$(curl -s https://ipecho.net/plain)
echo -e "${GREEN}✓ IP VPS: $IP_ADDRESS${NC}\n"

# Tạo file lưu địa chỉ ví
echo -e "${BLUE}[2/6]${NC} Tạo file backup địa chỉ ví..."
WALLET_BACKUP="wallets-backup.txt"
echo "=== ARCIUM NODES WALLET BACKUP ===" > $WALLET_BACKUP
echo "IP VPS: $IP_ADDRESS" >> $WALLET_BACKUP
echo "Date: $(date)" >> $WALLET_BACKUP
echo "" >> $WALLET_BACKUP

# Tạo/đọc file lưu offset đã dùng
touch $OFFSET_FILE

# Đếm số node đã tồn tại
EXISTING_NODES=0
for dir in node-*/; do
    [ -d "$dir" ] && EXISTING_NODES=$((EXISTING_NODES + 1))
done

if [ $EXISTING_NODES -gt 0 ]; then
    echo -e "${YELLOW}Phát hiện $EXISTING_NODES node đã tồn tại${NC}"
    echo -e "${YELLOW}Sẽ tạo thêm $((NUM_NODES - EXISTING_NODES)) node mới${NC}\n"
    START_INDEX=$((EXISTING_NODES + 1))
else
    START_INDEX=1
fi

# Loop qua từng node
for i in $(seq $START_INDEX $NUM_NODES); do
    NODE_DIR="node-$i"
    
    # Bỏ qua nếu thư mục đã tồn tại
    if [ -d "$NODE_DIR" ]; then
        echo -e "${YELLOW}Node $i đã tồn tại, bỏ qua...${NC}\n"
        continue
    fi
    
    echo -e "${BLUE}[3/6]${NC} ${YELLOW}Đang setup NODE $i...${NC}"
    
    # Tạo offset ngẫu nhiên
    NODE_OFFSET=$(generate_unique_offset)
    echo -e "${GREEN}✓ Offset được chọn: $NODE_OFFSET${NC}"
    
    # Tạo thư mục
    mkdir -p $NODE_DIR/logs
    cd $NODE_DIR
    
    # Tạo keypair
    echo -e "  ${GREEN}→${NC} Tạo keypair..."
    solana-keygen new --outfile node-keypair.json --no-bip39-passphrase --silent 2>/dev/null
    solana-keygen new --outfile callback-kp.json --no-bip39-passphrase --silent 2>/dev/null
    openssl genpkey -algorithm Ed25519 -out identity.pem 2>/dev/null
    
    # Lấy địa chỉ ví
    NODE_ADDR=$(solana address --keypair node-keypair.json)
    CALLBACK_ADDR=$(solana address --keypair callback-kp.json)
    
    # Lưu vào file backup
    echo "--- NODE $i ---" >> ../$WALLET_BACKUP
    echo "Offset: $NODE_OFFSET" >> ../$WALLET_BACKUP
    echo "Node Wallet: $NODE_ADDR" >> ../$WALLET_BACKUP
    echo "Callback Wallet: $CALLBACK_ADDR" >> ../$WALLET_BACKUP
    echo "Faucet link: https://faucet.solana.com" >> ../$WALLET_BACKUP
    echo "" >> ../$WALLET_BACKUP
    
    echo -e "  ${GREEN}→${NC} Node wallet: ${GREEN}$NODE_ADDR${NC}"
    echo -e "  ${GREEN}→${NC} Callback wallet: ${GREEN}$CALLBACK_ADDR${NC}"
    
    # Tạo file config
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
    
    echo -e "  ${GREEN}✓${NC} Đã tạo config\n"
    
    cd ..
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Hoàn thành setup $NUM_NODES nodes!${NC}"
echo -e "${GREEN}========================================${NC}\n"

# Tự động generate docker-compose.yml
if [ -f "generate-compose.sh" ]; then
    echo -e "${BLUE}Đang tạo docker-compose.yml cho $NUM_NODES nodes...${NC}"
    ./generate-compose.sh $NUM_NODES 8080 > /dev/null 2>&1
    echo -e "${GREEN}✓ Đã tạo docker-compose.yml${NC}\n"
fi

echo -e "${YELLOW}📋 DANH SÁCH OFFSET ĐÃ TẠO:${NC}"
cat $OFFSET_FILE | nl
echo ""

echo -e "${YELLOW}📋 BƯỚC TIẾP THEO:${NC}"
echo -e "${BLUE}1.${NC} Mở file ${GREEN}$WALLET_BACKUP${NC} để xem danh sách địa chỉ ví"
echo -e "   ${CYAN}cat $WALLET_BACKUP${NC}"
echo -e "${BLUE}2.${NC} Vào ${GREEN}https://faucet.solana.com${NC} để airdrop SOL cho TẤT CẢ các ví"
echo -e "${BLUE}3.${NC} Chạy script init: ${GREEN}./init-nodes.sh $NUM_NODES${NC}"
echo -e "${BLUE}4.${NC} Sau khi init xong, chạy: ${GREEN}docker-compose up -d${NC}\n"

echo -e "${RED}⚠️  LƯU Ý:${NC}"
echo -e "  • File ${GREEN}$WALLET_BACKUP${NC} chứa thông tin quan trọng, hãy backup!"
echo -e "  • File ${GREEN}$OFFSET_FILE${NC} lưu tất cả offset đã dùng"
echo -e "  • Kiểm tra offset: ${CYAN}./list-offsets.sh${NC}\n"
