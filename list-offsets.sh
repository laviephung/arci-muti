#!/bin/bash

# Script liệt kê tất cả offset đang dùng
# Sử dụng: ./list-offsets.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

RPC_URL="https://api.devnet.solana.com"

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}   DANH SÁCH OFFSETS ĐANG SỬ DỤNG${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Kiểm tra file offsets-used.txt
if [ ! -f "offsets-used.txt" ]; then
    echo -e "${RED}✗ File offsets-used.txt không tồn tại!${NC}"
    echo -e "${YELLOW}Chưa có node nào được setup.${NC}"
    exit 1
fi

echo -e "${CYAN}Đọc từ file offsets-used.txt:${NC}\n"

TOTAL=0
ACTIVE=0
INACTIVE=0

while IFS= read -r offset; do
    [ -z "$offset" ] && continue
    
    TOTAL=$((TOTAL + 1))
    printf "%-3d. Offset: ${YELLOW}%-12s${NC} → " "$TOTAL" "$offset"
    
    # Kiểm tra trên chain
    if arcium arx-active $offset --rpc-url $RPC_URL 2>&1 | grep -q "true"; then
        echo -e "${GREEN}ACTIVE ✓${NC}"
        ACTIVE=$((ACTIVE + 1))
    else
        if arcium arx-info $offset --rpc-url $RPC_URL 2>&1 | grep -q "Error"; then
            echo -e "${RED}NOT INIT ✗${NC}"
        else
            echo -e "${YELLOW}INACTIVE ○${NC}"
            INACTIVE=$((INACTIVE + 1))
        fi
    fi
done < offsets-used.txt

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}📊 THỐNG KÊ:${NC}"
echo -e "  ${CYAN}Total offsets:${NC} $TOTAL"
echo -e "  ${GREEN}Active:${NC} $ACTIVE"
echo -e "  ${YELLOW}Inactive:${NC} $INACTIVE"
echo -e "  ${RED}Not init:${NC} $((TOTAL - ACTIVE - INACTIVE))"
echo -e "${BLUE}========================================${NC}\n"
