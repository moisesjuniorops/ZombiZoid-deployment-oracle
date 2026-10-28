#!/usr/bin/env bash
# Tenta criar a VM A1.Flex em todos os ADs ate conseguir ("Out of host capacity" e comum).
# Uso: deploy/oracle/retry-a1.sh [intervalo_segundos]   (padrao 300; Ctrl+C para parar)
set -uo pipefail
cd "$(dirname "$0")/infra"
INTERVAL="${1:-300}"
ADS="$(terraform console <<<'length(data.oci_identity_availability_domains.this.availability_domains)' 2>/dev/null || echo 3)"

attempt=0
while true; do
  attempt=$((attempt + 1))
  for ((i = 0; i < ADS; i++)); do
    echo "[$(date '+%F %T')] tentativa $attempt, AD index $i"
    out="$(terraform apply -auto-approve -input=false -no-color -var "availability_domain_index=$i" 2>&1)"
    if terraform state list 2>/dev/null | grep -q '^oci_core_instance.bot$'; then
      echo "VM criada!"
      terraform output
      exit 0
    fi
    if ! grep -q "Out of host capacity" <<<"$out"; then
      echo "Erro diferente de falta de capacidade; abortando:"
      echo "$out" | tail -20
      exit 1
    fi
  done
  echo "Sem capacidade; nova rodada em ${INTERVAL}s"
  sleep "$INTERVAL"
done
