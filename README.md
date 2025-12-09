# ⚙️ Hướng Dẫn Cài Đặt Arcium Node

## 🧩 1. Cập Nhật Hệ Thống

Chạy các lệnh sau để cập nhật và cài đặt các gói cần thiết:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl build-essential pkg-config libssl-dev libudev-dev git docker.io docker-compose openssl
sudo systemctl enable docker
sudo systemctl start docker
sudo apt install docker-compose -y

````
# Cài Rust
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
````

# Cài Solana CLI
```bash
bash -c "$(curl -sSfL https://solana-install.solana.workers.dev)"
source "$HOME/.profile"
````

# Kiểm tra phiên bản Solana
```bash
solana --version
````
# Cài đặt Arcium CLI
```bash
curl --proto '=https' --tlsv1.2 -sSfL https://install.arcium.com/ | bash
source "$HOME/.cargo/env"
````

# Kiểm tra phiên bản Arcium
```bash
arcium --version
arcup --version
````
# Clone the Repository
```bash
git clone https://github.com/laviephung/arci-muti.git
cd arci-muti
````
# cấp quyền
```bash
chmod +x *.sh
````
#setup node
thay số 20 thành số lượng ví muốn tạo
```bash
./setup-nodes-new.sh 20
````
```bash
./generate-compose.sh 20
````
```bash
./init-nodes.sh 20
````
buid compose
```bash
docker-compose up -d
````
# check logs
```bash
./view-logs.sh
````

# Xem logs node 5
```bash
./view-logs.sh 5
````

# Xem logs tất cả (docker)
```bash
./view-logs.sh all
````
# Check nodes đang active
```bash
./view-logs.sh active
````
cecjjj
```bash
docker compose up -d $(seq -f "arx-node-%g" 1 50)
````
chay file docker compose.yml mới
```bash
./generate-compose-v2.sh mxc 100 9080
````
```bash
docker-compose -f docker-compose-mxc.yml up -d
````
docker-compose up -d arx-node-99










