#!/usr/bin/env bash
# Smoke test do Chromium+chromedriver exatamente como client/navigator.py os abre. Rodar NA VM:
#   sudo bash deploy/oracle/check-selenium.sh
set -euo pipefail
sudo -u zombizoid -H env HOME=/opt/zombizoid/home /opt/zombizoid/venv/bin/python -I - <<'PY'
from selenium import webdriver
o = webdriver.ChromeOptions()
for a in ("--headless", "--no-sandbox", "--disable-dev-shm-usage"):
    o.add_argument(a)
d = webdriver.Chrome(options=o)
d.get("https://steamcommunity.com/")
print("OK:", d.title, "| chrome", d.capabilities["browserVersion"])
d.quit()
PY
