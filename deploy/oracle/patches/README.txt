ssh-key-support.patch e ilustrativo (pseudo-diff), NAO aplicado. Adiciona config opcional ssh_key_file
em client/ssh.py (linhas 28, 39, 57, 63, 72). Alem disso, ssh.py:21 usa load_system_host_keys e
a politica padrao rejeita hosts desconhecidos: faca `ssh-keyscan HOST >> ~zombizoid/.ssh/known_hosts` (ou /etc/ssh/ssh_known_hosts).
