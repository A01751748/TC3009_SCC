#!/usr/bin/env bash
#
# Deja tu instancia lista para la parte 2.
#
#   bash setup/bootstrap.sh
#
# Instala lo del backend y, si hace falta, Ollama y el modelo. Se puede correr
# varias veces sin romper nada: comprueba antes de instalar.

set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODELO="${OLLAMA_MODEL:-qwen2.5:1.5b}"

echo "==> Paquetes del sistema"
sudo apt-get update -qq
sudo apt-get install -y -qq git python3 python3-venv python3-pip curl ca-certificates lsof

echo "==> Entorno de Python"
[[ -d "$AQUI/.venv" ]] || python3 -m venv "$AQUI/.venv"
"$AQUI/.venv/bin/pip" install -q --upgrade pip
"$AQUI/.venv/bin/pip" install -q -r "$AQUI/backend/requirements.txt"

echo "==> Ollama"
if command -v ollama >/dev/null 2>&1; then
  echo "    ya estaba instalado ($(ollama --version 2>&1 | head -1))"
else
  curl -fsSL https://ollama.com/install.sh | sh
fi

# El instalador deja un servicio de systemd. Si no arranco solo, lo levantamos.
if ! curl -s --max-time 3 http://localhost:11434/api/tags >/dev/null 2>&1; then
  echo "    arrancando el servidor..."
  sudo systemctl enable --now ollama 2>/dev/null || (nohup ollama serve >/dev/null 2>&1 &)
  sleep 5
fi

if curl -s --max-time 5 http://localhost:11434/api/tags | grep -q "$MODELO"; then
  echo "    $MODELO ya estaba descargado"
else
  echo "==> Descargando $MODELO (~1 GB, tarda)"
  ollama pull "$MODELO"
fi

echo
echo "Listo. Ahora:"
echo "    ./run start"
echo "    ./run salud"
