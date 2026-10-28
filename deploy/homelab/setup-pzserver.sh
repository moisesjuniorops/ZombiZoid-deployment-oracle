#!/usr/bin/env bash
# Idempotente. Executar NA VM Ubuntu 24.04 (root), DEPOIS de deploy/oracle/setup-vm.sh (bot):
#   sudo PZ_BRANCH=unstable bash setup-pzserver.sh
# Instala steamcmd + Project Zomboid Dedicated Server (app 380870) para o usuario pzserver,
# prepara o lancador que o bot usa (start_path/start_file), RCON so em localhost,
# SSH por senha so de 127.0.0.1 (o bot nao suporta chave) e o config.yaml do bot.
set -euo pipefail

PZ_BRANCH="${PZ_BRANCH:-public}"   # public | unstable (Build 42 enquanto estiver no unstable)
PZ_XMX="${PZ_XMX:-8g}"
SERVER_NAME="${SERVER_NAME:-zomboid}"
PZ_USER=pzserver
PZ_HOME=/home/$PZ_USER
PZ_DIR=$PZ_HOME/pzserver
BOT_CFG=/opt/zombizoid/config/config.yaml
SECRETS=/root/pz-secrets.env
export DEBIAN_FRONTEND=noninteractive
APT=(apt-get -o DPkg::Lock::Timeout=300 -y)

[ "$(id -u)" -eq 0 ] || { echo "Execute como root (sudo)."; exit 1; }
id zombizoid &>/dev/null || { echo "Rode antes deploy/oracle/setup-vm.sh (bot)."; exit 1; }

# --- pacotes: steamcmd (multiverse, i386), guest agent, firewall
dpkg --add-architecture i386
add-apt-repository -y multiverse
echo steam steam/question select "I AGREE" | debconf-set-selections
echo steam steam/license note '' | debconf-set-selections
"${APT[@]}" update
"${APT[@]}" install steamcmd lib32gcc-s1 qemu-guest-agent ufw openssl
systemctl enable --now qemu-guest-agent || true

# --- segredos (gerados uma vez, so root le)
if [ ! -f $SECRETS ]; then
  umask 077
  cat > $SECRETS <<EOF
PZ_SSH_PASSWORD=$(openssl rand -hex 16)
PZ_RCON_PASSWORD=$(openssl rand -hex 16)
PZ_ADMIN_PASSWORD=$(openssl rand -hex 12)
EOF
  umask 022
fi
# shellcheck disable=SC1090
. $SECRETS

# --- usuario do servidor (senha so usada pelo bot via 127.0.0.1)
id $PZ_USER &>/dev/null || useradd --create-home --shell /bin/bash $PZ_USER
echo "$PZ_USER:$PZ_SSH_PASSWORD" | chpasswd
cat > /etc/ssh/sshd_config.d/99-pzserver-local.conf <<'EOF'
# O bot ZombiZoid so autentica por senha: permitido apenas para pzserver vindo de localhost.
Match User pzserver Address 127.0.0.1,::1
    PasswordAuthentication yes
EOF
sshd -t && systemctl reload ssh

# --- steamcmd: script de update usado pelo bot (/update) e instalacao inicial
BETA=""; [ "$PZ_BRANCH" != "public" ] && BETA="-beta $PZ_BRANCH"
cat > $PZ_HOME/update_zomboid.txt <<EOF
@ShutdownOnFailedCommand 1
@NoPromptForPassword 1
force_install_dir $PZ_DIR
login anonymous
app_info_update 1
app_update 380870 $BETA validate
quit
EOF
chown $PZ_USER:$PZ_USER $PZ_HOME/update_zomboid.txt
# steamcmd costuma falhar na 1a execucao ("Missing configuration"): ate 3 tentativas
for try in 1 2 3; do
  sudo -u $PZ_USER -H /usr/games/steamcmd +runscript $PZ_HOME/update_zomboid.txt && [ -x $PZ_DIR/ProjectZomboid64 ] && break
  echo "steamcmd falhou (tentativa $try)"; sleep 10
done
[ -x $PZ_DIR/ProjectZomboid64 ] || { echo "Instalacao do servidor falhou"; exit 1; }

# --- memoria da JVM
JSON=$PZ_DIR/ProjectZomboid64.json
sed -i -E "s/\"-Xmx[0-9]+[mMgG]\"/\"-Xmx$PZ_XMX\"/" "$JSON"
grep -o '"-Xmx[^"]*"' "$JSON"

# --- lancador usado pelo bot.
# O bot inicia "start_path/start_file" por SSH e procura/mata com "pgrep -u pzserver start_file" + kill -9.
# Por isso o lancador se chama ProjectZomboid e faz exec do binario: o processo do servidor fica com
# nome "ProjectZomboid6", o pgrep o encontra e o kill atinge o servidor (e nao so um shell pai).
# trap '' HUP: o servidor sobrevive se a sessao SSH do bot cair (reinicio do bot).
LAUNCHER=$PZ_HOME/ProjectZomboid
grep -q 'ProjectZomboid64' $PZ_DIR/start-server.sh || { echo "start-server.sh inesperado"; exit 1; }
{
  echo '#!/usr/bin/env bash'
  echo '# Gerado por setup-pzserver.sh a partir de start-server.sh (ambiente identico, com exec).'
  echo "cd $PZ_DIR"
  grep -E '^\s*(export|INSTDIR|JSIG)' $PZ_DIR/start-server.sh | sed "s|\`dirname \$0\`|$PZ_DIR|"
  echo "trap '' HUP"
  echo "LD_PRELOAD=\"\${LD_PRELOAD}:\${JSIG:-libjsig.so}\" exec ./ProjectZomboid64 -servername $SERVER_NAME \"\$@\""
} > $LAUNCHER
chmod 755 $LAUNCHER; chown $PZ_USER:$PZ_USER $LAUNCHER

# --- primeira execucao: gera o .ini e o admin
INI=$PZ_HOME/Zomboid/Server/$SERVER_NAME.ini
if [ ! -f "$INI" ]; then
  echo "Primeira execucao do servidor (gera mundo e $INI; pode levar minutos)..."
  sudo -u $PZ_USER -H bash -c "timeout 600 $LAUNCHER -adminpassword '$PZ_ADMIN_PASSWORD' > $PZ_HOME/first-run.log 2>&1 &"
  for _ in $(seq 1 120); do
    grep -qE 'SERVER STARTED|Server Steam ID' $PZ_HOME/first-run.log 2>/dev/null && [ -f "$INI" ] && break
    sleep 5
  done
  pkill -u $PZ_USER -f ProjectZomboid64 || true
  sleep 5
  [ -f "$INI" ] || { echo "Servidor nao gerou $INI; veja $PZ_HOME/first-run.log"; exit 1; }
fi
set_ini() { if grep -q "^$1=" "$INI"; then sed -i "s|^$1=.*|$1=$2|" "$INI"; else echo "$1=$2" >> "$INI"; fi; }
set_ini RCONPort 27015
set_ini RCONPassword "$PZ_RCON_PASSWORD"
set_ini Public false
set_ini UPnP false
chown -R $PZ_USER:$PZ_USER $PZ_HOME/Zomboid

# --- known_hosts para o paramiko do bot (load_system_host_keys le ~/.ssh/known_hosts do usuario do bot)
ZH=/opt/zombizoid/home/.ssh
mkdir -p $ZH
ssh-keyscan -t ed25519 127.0.0.1 2>/dev/null > $ZH/known_hosts
chown -R zombizoid:zombizoid $ZH; chmod 700 $ZH; chmod 600 $ZH/known_hosts

# --- config do bot: campos do servidor preenchidos; Discord fica para o dono preencher
if grep -q 'SEU_BOT_TOKEN' $BOT_CFG; then
  sed -i \
    -e "s|^ssh_user:.*|ssh_user: \"$PZ_USER\"|" \
    -e "s|^ssh_password:.*|ssh_password: \"$PZ_SSH_PASSWORD\"|" \
    -e "s|^rcon_port:.*|rcon_port: 27015|" \
    -e "s|^rcon_pwd:.*|rcon_pwd: \"$PZ_RCON_PASSWORD\"|" \
    -e "s|^server:.*|server: \"127.0.0.1\"|" \
    -e "s|^start_file:.*|start_file: \"ProjectZomboid\"|" \
    -e "s|^start_path:.*|start_path: \"$PZ_HOME\"|" \
    -e "s|^update_script:.*|update_script: \"$PZ_HOME/update_zomboid.txt\"|" \
    -e "s|^server_file:.*|server_file: \"$INI\"|" \
    $BOT_CFG
fi

# --- Tailscale (repo apt oficial assinado); login manual: sudo tailscale up --hostname=zomboid
if ! command -v tailscale >/dev/null; then
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg -o /usr/share/keyrings/tailscale-archive-keyring.gpg
  curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list -o /etc/apt/sources.list.d/tailscale.list
  "${APT[@]}" update
  "${APT[@]}" install tailscale
fi

# --- firewall: SSH so da LAN; jogo (UDP 16261-16262) na LAN e no Tailscale; RCON (27015) nunca exposto
ufw default deny incoming
ufw default allow outgoing
ufw allow from 192.168.3.0/24 to any port 22 proto tcp
ufw allow from 192.168.3.0/24 to any port 16261:16262 proto udp
ufw allow in on tailscale0 to any port 16261:16262 proto udp
ufw --force enable

echo "== PZ pronto: branch=$PZ_BRANCH, ini=$INI. Segredos em $SECRETS (root)."
echo "Falta: preencher app_id/bot_key/bot_token/bot_permission/guild_id em $BOT_CFG e 'systemctl enable --now zombizoid'."
