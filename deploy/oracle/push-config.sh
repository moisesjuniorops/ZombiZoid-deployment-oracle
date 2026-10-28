#!/usr/bin/env bash
# Roda na SUA maquina. Envia o config.yaml real (nunca no git) e reinicia o servico.
#   deploy/oracle/push-config.sh ubuntu@IP [./config.yaml]
set -euo pipefail
TARGET="${1:?uso: $0 usuario@host [config.yaml]}"
CFG="${2:-./config.yaml}"
[ -f "$CFG" ] || { echo "Arquivo nao encontrado: $CFG"; exit 1; }
if grep -qE 'SEU_BOT_TOKEN|SUA_BOT_KEY|SEU_APP_ID' "$CFG"; then
  echo "O arquivo ainda tem placeholders do config.example.yaml."; exit 1
fi
if ! grep -q '^ssh_password:' "$CFG" || grep -q '^ssh_passwod:' "$CFG"; then
  echo "Aviso: use 'ssh_password' (o typo 'ssh_passwod' do base.yaml nao e lido)."
fi
TMP="zz-config.$$.yaml"
# umask 077 no lado remoto: o arquivo temporario nunca fica legivel por outros
ssh "$TARGET" "umask 077; cat > '$TMP'" < "$CFG"
ssh "$TARGET" "sudo install -o zombizoid -g zombizoid -m 600 '$TMP' /opt/zombizoid/config/config.yaml \
  && rm -f '$TMP' \
  && sudo systemctl enable zombizoid && sudo systemctl restart zombizoid \
  && sleep 3 && systemctl is-active zombizoid"
echo "Ok. Logs: ssh $TARGET 'sudo journalctl -u zombizoid -f'"
