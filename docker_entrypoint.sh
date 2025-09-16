#!/usr/bin/env bash
set -euo pipefail

# Détecte automatiquement le module Flask
APP_MODULE=""
for CAND in app.py wsgi.py hello.py main.py; do
  if [ -f "/app/${CAND}" ]; then
    APP_MODULE="$CAND"
    break
  fi
done

if [ -z "$APP_MODULE" ]; then
  echo "Aucun fichier Flask trouvé (app.py / wsgi.py / hello.py / main.py)."
  echo "Assure-toi que ton repo contient une appli Flask minimale."
  exit 1
fi

export FLASK_APP="$APP_MODULE"
export FLASK_RUN_HOST=0.0.0.0
export FLASK_RUN_PORT=5000

# Active le token ngrok
if [ -z "${NGROK_AUTHTOKEN:-}" ]; then
  echo "NGROK_AUTHTOKEN non défini. Passe-le via le secret GitHub Actions."
  exit 1
fi
ngrok config add-authtoken "$NGROK_AUTHTOKEN" >/dev/null

# Démarre Flask en arrière-plan
echo "Démarrage du serveur Flask (${APP_MODULE})..."
python -m flask run &

FLASK_PID=$!

# Attends que Flask écoute (port 5000)
echo "Attente du démarrage de Flask..."
for i in {1..30}; do
  if (echo > /dev/tcp/127.0.0.1/5000) >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# Lance ngrok
echo "Ouverture du tunnel ngrok..."
ngrok http http://127.0.0.1:5000 --log=stdout >/tmp/ngrok.log 2>&1 &

NGROK_PID=$!

# Attends l’API ngrok puis récupère l’URL publique
for i in {1..30}; do
  if (echo > /dev/tcp/127.0.0.1/4040) >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# Extraction de l'URL via l'API locale ngrok
PUB_URL="$(curl -s http://127.0.0.1:4040/api/tunnels | jq -r '.tunnels[]?.public_url' | head -n1 || true)"

if [ -z "$PUB_URL" ] || [ "$PUB_URL" = "null" ]; then
  echo "::error::Impossible de récupérer l’URL ngrok (vérifie le token)."
  # Affiche les logs ngrok pour debug
  echo "---- ngrok logs ----"
  tail -n +1 /tmp/ngrok.log || true
  kill $NGROK_PID $FLASK_PID || true
  exit 1
fi

echo ""
echo "=============================================================="
echo "🔗 URL publique (valide ~120 secondes) : $PUB_URL"
echo "=============================================================="
echo ""

# Laisse le preview ouvert 120s puis nettoie
sleep 120

echo "Fermeture du preview..."
kill $NGROK_PID $FLASK_PID || true
wait || true
echo "Preview terminé."
