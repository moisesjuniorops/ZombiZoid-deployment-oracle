# Deploy do ZombiZoid na Oracle Cloud (Always Free)

Decisão e diagramas: [ARCHITECTURE.md](ARCHITECTURE.md). Resumo: A1.Flex 1 OCPU/6 GB (aarch64) por padrão, fallback E2.1.Micro, systemd nativo, sem container. O código do bot (`bot.py`, `client/`, `db/`, `utils/`) roda sem alterações.

Pré-requisito: este diretório `deploy/oracle/` precisa estar commitado e com push feito no repositório indicado em `repo_url` (o cloud-init clona de lá). Terraform não é executado por nenhum script; você roda `plan`/`apply`.

## 1. Provisionar (Terraform)
```
cd deploy/oracle/infra
cp terraform.tfvars.example terraform.tfvars   # ignorado pelo git; preencha region, compartment_ocid, ssh_public_key, admin_cidr
terraform init
terraform plan
terraform apply
```
- Credenciais: `~/.oci/config` (perfil em `oci_config_profile`). Nada de segredo no repo ou no `user_data`.
- `admin_cidr` é obrigatório e `0.0.0.0/0` é rejeitado. Único ingress: SSH 22 desse CIDR. Egress livre.
- A1 com "Out of host capacity": tente outro `availability_domain_index`, repita mais tarde, ou use `shape = "VM.Standard.E2.1.Micro"`.
- Commite `infra/.terraform.lock.hcl`; nunca `*.tfstate` nem `terraform.tfvars` (state local contém dados da conta).
- Trocar de shape recria a VM (`terraform apply` destrói a antiga): o `config.yaml` precisa ser reenviado.

Acompanhe o cloud-init (alguns minutos; termina com `== bootstrap OK`):
```
$(terraform output -raw bootstrap_log_command)
```
Ele instala venv + dependências, Chromium/chromedriver não-snap (PPA xtradeb, detecta amd64/arm64), usuário `zombizoid` e a unit. Não habilita o serviço.

## 2. Teste do Chromium (obrigatório: o bot abre o Chrome no import)
```
ssh ubuntu@IP 'sudo bash /opt/zombizoid/app/deploy/oracle/check-selenium.sh'
```
Deve imprimir `OK: ... | chrome <versão>`.

## 3. Config e segredos
Copie `config.example.yaml` para `./config.yaml` (ignorado pelo git) e preencha. Atenção:
- A chave correta é `ssh_password` (`client/ssh.py:28`); o `config/base.yaml` do upstream tem o typo `ssh_passwod`, que faz a senha chegar `None`.
- `rcon_port` inteiro, `guild_id` numérico, `server` = IP/DDNS do servidor Zomboid.
- Discord Developer Portal: habilitar *Message Content Intent* e convidar o bot com escopo `applications.commands`.

Enviar (permissão 600, dono `zombizoid`, habilita e reinicia o serviço):
```
deploy/oracle/push-config.sh ubuntu@IP ./config.yaml     # ou: make push-config
```
Sem scp/sudoedit manual necessário; alternativa manual: `sudoedit /opt/zombizoid/config/config.yaml`.

Host key do servidor Zomboid (`ssh.py:21` rejeita desconhecidos):
```
ssh ubuntu@IP 'ssh-keyscan -p SSH_PORT -H SERVIDOR | sudo tee -a /etc/ssh/ssh_known_hosts >/dev/null'
```
O servidor Zomboid precisa aceitar login SSH por senha (`PasswordAuthentication yes`). Chave SSH exige o patch ilustrativo em `patches/`.

## 4. Teste em modo debug e serviço
```
ssh ubuntu@IP
sudo systemctl stop zombizoid
sudo -u zombizoid -H bash -c 'cd /opt/zombizoid/app && /opt/zombizoid/venv/bin/python bot.py -c /opt/zombizoid/config/config.yaml -D'   # Ctrl+C ao terminar
sudo systemctl start zombizoid
sudo journalctl -u zombizoid -f
```
(`-D` loga os valores da config, incluindo segredos: não cole essa saída em lugar nenhum.) No Discord: `/status`, `/running`, `zz help`.

## 5. Checklist de conectividade
- [ ] VM -> servidor Zomboid TCP SSH (`nc -vz SERVIDOR 22`)
- [ ] VM -> servidor TCP RCON (`nc -vz SERVIDOR RCON_PORT`); firewall/NAT do servidor libera o IP público da VM (`terraform output public_ip`)
- [ ] VM -> discord.com:443 e steamcommunity.com:443 (egress; coberto pela security list)
- [ ] known_hosts do servidor registrado
- [ ] `config.yaml` 600, dono zombizoid, fora do git
- [ ] Nenhuma porta de entrada para o bot; SSH 22 só do `admin_cidr`

## 6. Ociosidade (Always Free)
A Oracle pode reclamar instâncias ociosas (7 dias com CPU p95, rede e, na A1, memória < 20%). Veja mitigações em ARCHITECTURE.md (upgrade PAYG com Budget alerta, sem custo para recursos free).

## 7. Manutenção
- Atualizar código: `ssh ubuntu@IP 'sudo bash /opt/zombizoid/app/deploy/oracle/setup-vm.sh'` e `sudo systemctl restart zombizoid`.
- Backup: `/opt/zombizoid/app/db/mods/mods.json` (cwd-relativo) e o seu `config.yaml` local.
- Layout na VM: `/opt/zombizoid/{app,venv,config,home}`.
- Destruir: `terraform destroy` (confirmação sua).

## 8. Riscos
- Autenticação SSH ao servidor só por senha em texto puro (sem alterar o código).
- Chromium vem de PPA de terceiros; major updates podem quebrar o pareamento driver/browser (ambos vêm do mesmo PPA e atualizam juntos).
- Servidor do Zomboid não roda na VM Oracle (E2: sem RAM; A1: steamcmd x86 exigiria box64/FEX).
- Código upstream sem pinagem de transitivas.
