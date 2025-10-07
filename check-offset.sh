#!/bin/bash

# Script kiểm tra offset đã được dùng hay chưa
# Sử dụng: ./check-offset.sh <offset>
# Hoặc: ./check-offset.sh random (để test random offset)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

RPC_URL="https://api.devnet.solana.com"

if [ "$1" == "random" ]; then
    OFFSET=$((100000000 + RANDOM))
    echo -e "${BLUE}Offset ngẫu nhiên: $OFFSET${NC}\n"
elif [ -z "$1" ]; then
    echo -e "${RED}Sử dụng: ./check-offset.sh <offset>${NC}"
    echo -e "${YELLOW}Hoặc: ./check-offset.sh random${NC}"
    exit 1
else
    OFFSET=$1
fi

echo -e "${BLUE}Đang kiểm tra offset $OFFSET trên chain...${NC}\n"

# Kiểm tra offset trên chain
if arcium arx-info $OFFSET --rpc-url $RPC_URL 2>&1 | grep -q "Error"; then
    echo -e "${GREEN}✓ Offset $OFFSET CHƯA được sử dụng - CÓ THỂ DÙNG!${NC}"
    exit 0
else
    echo -e "${RED}✗ Offset $OFFSET ĐÃ được sử dụng - KHÔNG THỂ DÙNG!${NC}"
    echo -e "\n${YELLOW}Thông tin node:${NC}"
    arcium arx-info $OFFSET --rpc-url $RPC_URL
    exit 1
fi
