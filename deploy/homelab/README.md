# ZombiZoid + Project Zomboid B42 no homelab (Proxmox)

Custo zero: tudo roda no Proxmox de casa; jogadores entram via Tailscale (a conexao tem CGNAT, sem IP publico).

```
Amigos (Tailscale) ──UDP 16261-16262──► VM 110 "zomboid" 192.168.3.95 (Ubuntu 24.04, 4 vCPU, 11 GB)
                                          ├─ servidor PZ B42 (usuario pzserver, Xmx 8g)
                                          └─ bot ZombiZoid (systemd) ──SSH/RCON 127.0.0.1──┘
                                                └── WebSocket de saida ──► Discord
```

## 1. VM (Terraform, provider bpg/proxmox)
```
. ./pve.env        # export PROXMOX_VE_USERNAME=... PROXMOX_VE_PASSWORD=...  (ou PROXMOX_VE_API_TOKEN); fora do git
cd infra && terraform init && terraform apply
```
`terraform.tfvars`: `ssh_public_key = "ssh-ed25519 ..."`. IP, recursos e storage em `variables.tf`.

## 2. Software na VM
```
ssh ubuntu@192.168.3.95
curl -fsSL https://raw.githubusercontent.com/<fork>/<branch>/deploy/oracle/setup-vm.sh -o setup-vm.sh
sudo bash setup-vm.sh <url-do-repo> <branch>          # bot: venv, Chromium, unit systemd
sudo PZ_BRANCH=public bash setup-pzserver.sh          # PZ B42 (public), RCON, firewall, Tailscale, config do bot
sudo tailscale up --hostname=zomboid                  # abre URL de login
```
B42 e a branch `public` da Steam (B41 = `legacy41`). Segredos gerados ficam em `/root/pz-secrets.env`
(senha SSH do pzserver, RCON e admin do jogo).

## 3. Discord
Preencha `app_id`, `bot_key`, `bot_token`, `bot_permission`, `guild_id` em `/opt/zombizoid/config/config.yaml`
(o resto ja foi preenchido pelo setup), depois:
```
sudo systemctl enable --now zombizoid && journalctl -u zombizoid -f
```
No Discord: `/restart` sobe o servidor, `/running` confere, `zz <comando RCON>` executa no jogo.

## 4. Jogadores
Painel Tailscale → maquina `zomboid` → Share → convite. O amigo instala o Tailscale, aceita,
e no Zomboid conecta em `<IP 100.x da VM>:16261`.

## Como funciona o controle pelo bot
- O bot inicia `/home/pzserver/ProjectZomboid` por SSH (senha aceita so de 127.0.0.1).
  Esse lancador faz `exec` do binario, entao `pgrep`/`kill -9` do bot atingem o servidor de verdade,
  e ignora SIGHUP (o servidor sobrevive a reinicios do bot).
- `/restart` e `/update` usam `kill -9` (codigo upstream): rode `zz save` antes para nao perder progresso.
- Firewall (ufw): SSH so da LAN; UDP 16261-16262 na LAN e em `tailscale0`; RCON 27015 nunca exposto.

## Recursos do host
O host tem 15,5 GB: com a VM do jogo ligada (11 GB), mantenha o cluster k8s (VMs 101-103) desligado.
