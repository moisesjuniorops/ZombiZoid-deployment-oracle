#!/usr/bin/env bash
# Idempotente. Executar NA VM Ubuntu 24.04 (root), amd64 ou arm64:
#   sudo bash deploy/oracle/setup-vm.sh [url-git] [branch-ou-tag]
# Chamado automaticamente pelo cloud-init do Terraform (infra/templates/cloud-init.yaml.tftpl).
set -euo pipefail

REPO="${1:-https://github.com/moisesjuniorops/ZombiZoid-deployment-oracle.git}"
REF="${2:-main}"
B=/opt/zombizoid
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get -o DPkg::Lock::Timeout=300 -y)

[ "$(id -u)" -eq 0 ] || { echo "Execute como root (sudo)."; exit 1; }
ARCH="$(dpkg --print-architecture)"   # amd64 | arm64
MEM_MB="$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)"
echo "arch=$ARCH ram=${MEM_MB}MB"
case "$ARCH" in amd64|arm64) ;; *) echo "Arquitetura nao suportada: $ARCH"; exit 1 ;; esac

# swap: 2G no micro (1 GB de RAM), 1G de seguranca nas demais
if ! swapon --show | grep -q .; then
  SIZE=1G; [ "$MEM_MB" -lt 2048 ] && SIZE=2G
  [ -f /swapfile ] || { fallocate -l "$SIZE" /swapfile; chmod 600 /swapfile; mkswap /swapfile; }
  swapon /swapfile
  grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

"${APT[@]}" update
"${APT[@]}" install python3 python3-venv python3-pip git ca-certificates software-properties-common curl netcat-openbsd
python3 -c "import sys; sys.exit(sys.version_info < (3, 12))" || { echo "Python >= 3.12 necessario (use Ubuntu 24.04)"; exit 1; }

id zombizoid &>/dev/null || useradd --system --home-dir $B/home --create-home --shell /usr/sbin/nologin zombizoid
mkdir -p $B/config $B/home

# codigo: clona ou atualiza (ff-only) na ref pedida
if [ -d $B/app/.git ]; then
  git -c safe.directory='*' -C $B/app fetch --tags origin
  git -c safe.directory='*' -C $B/app checkout "$REF"
  git -c safe.directory='*' -C $B/app merge --ff-only "origin/$REF" 2>/dev/null || true
else
  git clone --branch "$REF" "$REPO" $B/app
fi
D=$B/app/deploy/oracle

python3 -m venv $B/venv
$B/venv/bin/pip install --upgrade pip
$B/venv/bin/pip install -r "$D/requirements.txt"

# Chromium + chromedriver NAO-snap, mesma origem e mesma versao em amd64 e arm64
# (PPA xtradeb/apps; Selenium Manager nao baixa chromedriver para linux-arm64).
if ! grep -rqs 'xtradeb' /etc/apt/sources.list.d/; then
  add-apt-repository -y ppa:xtradeb/apps
fi
cat > /etc/apt/preferences.d/xtradeb-chromium <<'PIN'
Package: chromium chromium-driver chromium-common chromium-sandbox
Pin: release o=LP-PPA-xtradeb-apps
Pin-Priority: 900
PIN
"${APT[@]}" update
"${APT[@]}" install chromium chromium-driver
chromium --version
chromedriver --version

[ -f $B/config/config.yaml ] || { cp "$D/config.example.yaml" $B/config/config.yaml; echo "config.yaml de EXEMPLO criado; envie o real com push-config.sh"; }
chown -R zombizoid:zombizoid $B
chmod 700 $B/config; chmod 600 $B/config/config.yaml
cp "$D/zombizoid.service" /etc/systemd/system/zombizoid.service
systemctl daemon-reload
echo "Pronto (arch=$ARCH). Proximos passos: bash $D/check-selenium.sh ; push-config.sh ; systemctl enable --now zombizoid"
