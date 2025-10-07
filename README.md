CHAY UPDATE HỆ THỐNG
apt update && apt upgrade -y
apt install -y curl build-essential pkg-config libssl-dev libudev-dev git docker.io docker-compose openssl
systemctl enable docker
systemctl start docker

2. Cài Rust và Solana CLI
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
. "$HOME/.cargo/env"
-SOLANA CLI cài 
 bash -c "$(curl -sSfL https://solana-install.solana.workers.dev)"
. "$HOME/.profile"
solana --version
 3. Cài Arcium Tooling
curl --proto '=https' --tlsv1.2 -sSfL https://arcium-install.arcium.workers.dev/ | bash
. "$HOME/.cargo/env"
arcium --version
arcup --version


cấp quyền cho sh
chmod +x *.sh
khởi tạo docker compose
./generate-compose.sh thay số ví muốn tạo 8080


