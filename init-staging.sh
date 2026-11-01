#!/bin/bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONTAINER_NAME="quickbite-db"
IMAGE_NAME="postgres:15-alpine"
DB_PORT=5432
DB_PASS="12345678"

echo -e "${BLUE}===================================================${NC}"
echo -e "${BLUE}   QUICKBITE STAGING AUTO INITIALIZATION SCRIPT    ${NC}"
echo -e "${BLUE}===================================================${NC}"

# Giai doan 1: Don dep tai nguyen cu (Clean up)
echo -e "\n${YELLOW}[Phase 1/4] Kiem tra va don dep container cu...${NC}"
if [ "$(docker ps -aq -f name=^/${CONTAINER_NAME}$)" ]; then
    echo "Phat hien container $CONTAINER_NAME dang ton tai. Tien hanh go bo..."
    docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
    echo -e "${GREEN}[OK] Da don dep container cu thanh cong.${NC}"
else
    echo "Khong co container cu nao can don dep."
fi

# Giai doan 2: Kiem soat cong mang (Port Check - Fail fast)
echo -e "\n${YELLOW}[Phase 2/4] Kiem tra xung dot cong $DB_PORT (Fail-fast)...${NC}"
PORT_OCCUPIED=false
if command -v ss >/dev/null 2>&1; then
    if ss -tulpn | grep -q ":$DB_PORT"; then
        PORT_OCCUPIED=true
    fi
elif command -v nc >/dev/null 2>&1; then
    if nc -z 127.0.0.1 $DB_PORT; then
        PORT_OCCUPIED=true
    fi
fi

if [ "$PORT_OCCUPIED" = true ]; then
    echo -e "${RED}[ERROR] Cong $DB_PORT dang bi chiem dung boi tien trinh ngoai Docker!${NC}"
    echo -e "${RED}[FAIL-FAST] Dung kich ban ngay lap tuc de tranh xung dot mang.${NC}"
    exit 1
fi
echo -e "${GREEN}[OK] Cong $DB_PORT hoan toan trong.${NC}"

# Giai doan 3: Khoi tao Database Staging
echo -e "\n${YELLOW}[Phase 3/4] Khoi chay container Database Staging...${NC}"
docker run -d \
  --name "$CONTAINER_NAME" \
  -p "$DB_PORT:$DB_PORT" \
  -e POSTGRES_PASSWORD="$DB_PASS" \
  "$IMAGE_NAME" >/dev/null

echo -e "${GREEN}[OK] Container $CONTAINER_NAME da duoc khoi tao thanh cong.${NC}"

# Giai doan 4: Kiem thu do san sang (Smoke Test)
echo -e "\n${YELLOW}[Phase 4/4] Thuc hien Smoke Test kiem tra san sang...${NC}"
echo "Cho 5 giay de PostgreSQL khoi tao he thong..."
sleep 5

if docker exec "$CONTAINER_NAME" pg_isready -U postgres >/dev/null 2>&1; then
    echo -e "${GREEN}===================================================${NC}"
    echo -e "${GREEN}      DATABASE STAGING KHOI TAO THANH CONG!        ${NC}"
    echo -e "${GREEN}===================================================${NC}"
    exit 0
else
    echo -e "${RED}[ERROR] Database Staging chua san sang nhan ket noi!${NC}"
    echo -e "${YELLOW}--- 20 dong log cuoi cung cua container de debug: ---${NC}"
    docker logs --tail 20 "$CONTAINER_NAME"
    echo -e "${YELLOW}-----------------------------------------------------${NC}"
    exit 1
fi
