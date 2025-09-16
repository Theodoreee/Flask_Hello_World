FROM python:3.12-slim

# Outils utiles
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl jq ca-certificates gnupg && \
    rm -rf /var/lib/apt/lists/*

# Installer ngrok via dépôt officiel
RUN curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && \
    printf "deb https://ngrok-agent.s3.amazonaws.com buster main\n" > /etc/apt/sources.list.d/ngrok.list && \
    apt-get update && apt-get install -y --no-install-recommends ngrok && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Dépendances Python (si requirements.txt existe dans le repo source)
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt || true

# Code de l’appli
COPY . /app

# Script d’entrée
COPY docker_entrypoint.sh /usr/local/bin/docker_entrypoint.sh
RUN chmod +x /usr/local/bin/docker_entrypoint.sh

EXPOSE 5000
ENTRYPOINT ["/usr/local/bin/docker_entrypoint.sh"]
