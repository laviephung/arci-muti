#!/bin/bash

# Script tự động generate docker-compose.yml cho nhiều nodes
# Sử dụng: ./generate-compose.sh <số_node> <port_bắt_đầu>

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NUM_NODES=${1:-5}
START_PORT=${2:-8080}

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}   GENERATE DOCKER-COMPOSE FILE${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Số nodes: $NUM_NODES${NC}"
echo -e "${YELLOW}Port bắt đầu: $START_PORT${NC}\n"

COMPOSE_FILE="docker-compose.yml"

# Header
cat > $COMPOSE_FILE << 'EOF'
version: '3.8'

services:
EOF

# Generate services
for i in $(seq 1 $NUM_NODES); do
    PORT=$((START_PORT + i - 1))
    
    cat >> $COMPOSE_FILE << EOF
  arx-node-$i:
    image: arcium/arx-node
    container_name: arx-node-$i
    restart: unless-stopped
    environment:
      - NODE_IDENTITY_FILE=/usr/arx-node/node-keys/node_identity.pem
      - NODE_KEYPAIR_FILE=/usr/arx-node/node-keys/node_keypair.json
      - OPERATOR_KEYPAIR_FILE=/usr/arx-node/node-keys/operator_keypair.json
      - CALLBACK_AUTHORITY_KEYPAIR_FILE=/usr/arx-node/node-keys/callback_authority_keypair.json
      - NODE_CONFIG_PATH=/usr/arx-node/arx/node_config.toml
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
      - arcium-network

EOF
done

# Footer
cat >> $COMPOSE_FILE << 'EOF'
networks:
  arcium-network:
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
    echo -e "  ${GREEN}arx-node-$i${NC} → Port ${BLUE}$PORT${NC}"
done
echo ""
