#!/bin/bash
# ============================================
# ARCIUM NODES INITIALIZATION SCRIPT
# Init nodes lên blockchain
# Sử dụng: ./init-nodes.sh <số_node>
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

if [ ! -f "$OFFSET_FILE" ]; then
    echo -e "${RED}✗ File offsets-used.txt không tồn tại!${NC}"
    echo -e "${YELLOW}Chạy ./setup-nodes.sh trước${NC}"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${GREEN}   ARCIUM NODES INITIALIZATION      ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo -e "${YELLOW}Số node: $NUM_NODES${NC}\n"

IP_ADDRESS=$(curl -s https://ipecho.net/plain)
echo -e "${GREEN}IP:${NC} $IP_ADDRESS\n"

# Kiểm tra balance
echo -e "${BLUE}[1/3]${NC} Kiểm tra balance...\n"
MISSING_BALANCE=false

for i in $(seq 1 $NUM_NODES); do
    NODE_DIR="node-$i"
    if [ ! -d "$NODE_DIR" ]; then
        echo -e "${RED}✗ Thư mục $NODE_DIR không tồn tại!${NC}"
        exit 1
    fi
    
    cd $NODE_DIR
    NODE_BALANCE=$(solana balance --keypair node-keypair.json 2>/dev/null | awk '{print $1}')
    CALLBACK_BALANCE=$(solana balance --keypair callback-kp.json 2>/dev/null | awk '{print $1}')
    
    echo -e "${CYAN}Node $i:${NC}"
    
    if (( $(echo "$NODE_BALANCE < 0.5" | bc -l) )); then
        echo -e "  ${RED}✗ Node: $NODE_BALANCE SOL (Cần airdrop!)${NC}"
        MISSING_BALANCE=true
    else
        echo -e "  ${GREEN}✓ Node: $NODE_BALANCE SOL${NC}"
    fi
    
    if (( $(echo "$CALLBACK_BALANCE < 0.5" | bc -l) )); then
        echo -e "  ${RED}✗ Callback: $CALLBACK_BALANCE SOL (Cần airdrop!)${NC}"
        MISSING_BALANCE=true
    else
        echo -e "  ${GREEN}✓ Callback: $CALLBACK_BALANCE SOL${NC}"
    fi
    
    cd ..
done

if [ "$MISSING_BALANCE" = true ]; then
    echo -e "\n${RED}════════════════════════════════════════${NC}"
    echo -e "${RED}⚠️  CÓ VÍ CHƯA ĐỦ SOL!${NC}"
    echo -e "${RED}════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Airdrop tại: https://faucet.solana.com${NC}"
    echo -e "${YELLOW}Xem địa chỉ: cat wallets-backup.txt${NC}\n"
    read -p "Đã airdrop xong? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo ""

# Init nodes
echo -e "${BLUE}[2/3]${NC} Init nodes onchain...\n"
INIT_LOG="init-results.txt"
echo "╔════════════════════════════════════════╗" > $INIT_LOG
echo "║     ARCIUM NODES INIT RESULTS          ║" >> $INIT_LOG
echo "╚════════════════════════════════════════╝" >> $INIT_LOG
echo "Date: $(date)" >> $INIT_LOG
echo "" >> $INIT_LOG

SUCCESS_COUNT=0
FAIL_COUNT=0

for i in $(seq 1 $NUM_NODES); do
    NODE_DIR="node-$i"
    NODE_OFFSET=$(grep "^offset = " $NODE_DIR/node-config.toml | awk '{print $3}')
    
    echo -e "${CYAN}╔══ Đang init Node $i (offset: $NODE_OFFSET) ══╗${NC}"
    cd $NODE_DIR
    
    if arcium init-arx-accs \
        --keypair-path node-keypair.json \
        --callback-keypair-path callback-kp.json \
        --peer-keypair-path identity.pem \
        --node-offset $NODE_OFFSET \
        --ip-address $IP_ADDRESS \
        --rpc-url $RPC_URL 2>&1 | tee ../init-node-$i.log; then
        
        echo -e "${GREEN}✓ Node $i init thành công!${NC}\n"
        echo "Node $i (offset $NODE_OFFSET): ✓ SUCCESS" >> ../$INIT_LOG
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo -e "${RED}✗ Node $i init thất bại!${NC}\n"
        echo "Node $i (offset $NODE_OFFSET): ✗ FAILED" >> ../$INIT_LOG
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    cd ..
    sleep 2
done

echo -e "${BLUE}[3/3]${NC} Hoàn thành!\n"

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        INIT HOÀN THÀNH!                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}📊 KẾT QUẢ:${NC}"
echo -e "${GREEN}✓ Thành công: $SUCCESS_COUNT/$NUM_NODES${NC}"
if [ $FAIL_COUNT -gt 0 ]; then
    echo -e "${RED}✗ Thất bại: $FAIL_COUNT/$NUM_NODES${NC}"
fi
echo ""

if [ $SUCCESS_COUNT -eq $NUM_NODES ]; then
    echo -e "${CYAN}═══ BƯỚC TIẾP THEO ═══${NC}"
    echo -e "${BLUE}1.${NC} Chạy nodes:"
    echo -e "   ${GREEN}docker-compose up -d${NC}"
    echo -e "${BLUE}2.${NC} Xem logs:"
    echo -e "   ${GREEN}docker-compose logs -f${NC}"
    echo -e "${BLUE}3.${NC} Kiểm tra status:"
    echo -e "   ${GREEN}./list-offsets.sh${NC}\n"
else
    echo -e "${RED}Có nodes thất bại!${NC}"
    echo -e "Xem log: ${YELLOW}init-node-*.log${NC}"
    echo -e "Chi tiết: ${YELLOW}$INIT_LOG${NC}\n"
fi
