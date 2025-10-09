#!/bin/bash
# Script tự động generate docker-compose.yml cho nhiều nodes với prefix và port range tùy chỉnh
# Sử dụng: ./generate-compose-multi.sh <prefix> <số_node> <port_bắt_đầu>
# Ví dụ: ./generate-compose-multi.sh arx 5 8080
#        ./generate-compose-multi.sh mxc 5 9080

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Lấy parameters
PREFIX=${1:-arx}
NUM_NODES=${2:-5}
START_PORT=${3:-8080}

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}   GENERATE DOCKER-COMPOSE FILE${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Prefix: $PREFIX${NC}"
echo -e "${YELLOW}Số nodes: $NUM_NODES${NC}"
echo -e "${YELLOW}Port bắt đầu: $START_PORT${NC}\n"

# Tạo tên file compose với prefix
COMPOSE_FILE="docker-compose-${PREFIX}.yml"

# Kiểm tra xem có file compose nào đang chạy không
if [ -f "$COMPOSE_FILE" ]; then
    echo -e "${YELLOW}⚠️  File $COMPOSE_FILE đã tồn tại!${NC}"
    read -p "Bạn có muốn ghi đè? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}✗ Đã hủy${NC}"
        exit 1
    fi
fi

# Kiểm tra port conflict
echo -e "${BLUE}Kiểm tra port conflicts...${NC}"
for i in $(seq 1 $NUM_NODES); do
    PORT=$((START_PORT + i - 1))
    if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${RED}✗ Port $PORT đã được sử dụng!${NC}"
        echo -e "${YELLOW}Vui lòng chọn port bắt đầu khác hoặc stop service đang dùng port này${NC}"
        exit 1
    fi
done
echo -e "${GREEN}✓ Tất cả ports đều available${NC}\n"

# Header
cat > $COMPOSE_FILE << 'EOF'
version: '3.8'

services:
EOF

# Generate services
for i in $(seq 1 $NUM_NODES); do
    PORT=$((START_PORT + i - 1))
    
    cat >> $COMPOSE_FILE << EOF
  ${PREFIX}-node-$i:
    image: arcium/arx-node
    container_name: ${PREFIX}-node-$i
    restart: unless-stopped
    environment:
      - NODE_IDENTITY_FILE=/usr/arx-node/node-keys/node_identity.pem
      - NODE_KEYPAIR_FILE=/usr/arx-node/node-keys/node_keypair.json
      - OPERATOR_KEYPAIR_FILE=/usr/arx-node/node-keys/operator_keypair.json
      - CALLBACK_AUTHORITY_KEYPAIR_FILE=/usr/arx-node/node-keys/callback_authority_keypair.json
      - NODE_CONFIG_PATH=/usr/arx-node/arx/node_config.toml
      - RUST_LOG=info
    volumes:
      - ./node-$i/node-config.toml:/usr/arx-node/arx/node_config.toml
      - ./node-$i/node-keypair.json:/usr/arx-node/node-keys/node_keypair.json:ro
      - ./node-$i/node-keypair.json:/usr/arx-node/node-keys/operator_keypair.json:ro
      - ./node-$i/callback-kp.json:/usr/arx-node/node-keys/callback_authority_keypair.json:ro
      - ./node-$i/identity.pem:/usr/arx-node/node-keys/node_identity.pem:ro
      - ./node-$i/logs:/usr/arx-node/logs
    ports:
      - "$PORT:8080"
    networks:
      - ${PREFIX}-network
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

EOF
done

# Footer
cat >> $COMPOSE_FILE << EOF
networks:
  ${PREFIX}-network:
    driver: bridge
EOF

echo -e "${GREEN}✓ Đã tạo file $COMPOSE_FILE cho $NUM_NODES nodes${NC}"
echo -e "${GREEN}✓ Ports: $START_PORT - $((START_PORT + NUM_NODES - 1))${NC}\n"

echo -e "${YELLOW}📋 NỘI DUNG FILE:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
cat $COMPOSE_FILE
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${YELLOW}📊 PORT MAPPING:${NC}"
for i in $(seq 1 $NUM_NODES); do
    PORT=$((START_PORT + i - 1))
    echo -e "  ${GREEN}${PREFIX}-node-$i${NC} → Port ${BLUE}$PORT${NC}"
done

echo ""
echo -e "${YELLOW}📂 CẤU TRÚC THƯ MỤC CẦN TẠO:${NC}"
for i in $(seq 1 $NUM_NODES); do
    echo -e "  ${PREFIX}-node-$i/"
    echo -e "    ├── node-config.toml"
    echo -e "    ├── node-keypair.json"
    echo -e "    ├── callback-kp.json"
    echo -e "    ├── identity.pem"
    echo -e "    └── logs/"
done

echo ""
echo -e "${GREEN}🚀 CÁCH SỬ DỤNG:${NC}"
echo -e "  1. Tạo thư mục và file config cho từng node:"
echo -e "     ${BLUE}mkdir -p ${PREFIX}-node-{1..$NUM_NODES}/logs${NC}"
echo -e ""
echo -e "  2. Copy file cấu hình vào từng thư mục"
echo -e ""
echo -e "  3. Chạy docker compose:"
echo -e "     ${BLUE}docker-compose -f $COMPOSE_FILE up -d${NC}"
echo -e ""
echo -e "  4. Kiểm tra status:"
echo -e "     ${BLUE}docker-compose -f $COMPOSE_FILE ps${NC}"
echo -e ""
echo -e "  5. Xem logs:"
echo -e "     ${BLUE}docker-compose -f $COMPOSE_FILE logs -f ${PREFIX}-node-1${NC}"
echo -e ""
echo -e "  6. Stop services:"
echo -e "     ${BLUE}docker-compose -f $COMPOSE_FILE down${NC}"

echo ""
echo -e "${YELLOW}💡 VÍ DỤ CHẠY NHIỀU BATCH:${NC}"
echo -e "  ${BLUE}./generate-compose-multi.sh arx 5 8080${NC}  # arx-node-1 đến arx-node-5 (ports 8080-8084)"
echo -e "  ${BLUE}./generate-compose-multi.sh mxc 5 9080${NC}  # mxc-node-1 đến mxc-node-5 (ports 9080-9084)"
echo -e "  ${BLUE}./generate-compose-multi.sh sol 3 10080${NC} # sol-node-1 đến sol-node-3 (ports 10080-10082)"

echo ""
