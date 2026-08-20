# Der Pruefstand, gekapselt: hier drin schreibt und startet ein Modell Code.
#
# ALLE Agenten in einem Abbild. Der Pruefstand ist die groesste ungemessene
# Variable dieses Repos -- bei belebele war er bis zu 70 Punkte wert -- und
# solange nur einer installiert ist, laesst sich die Frage gar nicht stellen.
# Welcher gefahren wird, entscheidet die Konfiguration des Laufs.
#
# Kein GPU-Durchgriff: die Karte steht auf dem Messrechner, dieser Behaelter
# redet nur ueber HTTP. Deshalb laeuft er auch woanders -- waehrend einer
# Messung gehoert keine Fremdlast auf den Messrechner.
FROM debian:13-slim

ARG OPENCODE=1.18.18
ARG CRUSH=0.90.0
ARG GOOSE=1.46.0
ARG QWENCODE=0.21.15

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git jq unzip xz-utils bzip2 python3 python3-venv \
      libxcb1 libdbus-1-3 \
    && rm -rf /var/lib/apt/lists/*

# --- OpenCode ---------------------------------------------------------------
RUN curl -fsSL -o /tmp/oc.tar.gz \
      https://github.com/anomalyco/opencode/releases/download/v${OPENCODE}/opencode-linux-x64.tar.gz \
 && tar xzf /tmp/oc.tar.gz -C /usr/local/bin && rm /tmp/oc.tar.gz \
 && chmod +x /usr/local/bin/opencode

# --- Crush ------------------------------------------------------------------
RUN curl -fsSL -o /tmp/crush.tar.gz \
      https://github.com/charmbracelet/crush/releases/download/v${CRUSH}/crush_${CRUSH}_Linux_x86_64.tar.gz \
 && tar xzf /tmp/crush.tar.gz -C /tmp && rm /tmp/crush.tar.gz \
 && install -m0755 "$(find /tmp -maxdepth 2 -name crush -type f | head -1)" /usr/local/bin/crush \
 && rm -rf /tmp/crush*

# --- Goose ------------------------------------------------------------------
RUN curl -fsSL -o /tmp/goose.tar.bz2 \
      https://github.com/block/goose/releases/download/v${GOOSE}/goose-x86_64-unknown-linux-gnu.tar.bz2 \
 && tar xjf /tmp/goose.tar.bz2 -C /tmp && rm /tmp/goose.tar.bz2 \
 && install -m0755 "$(find /tmp -maxdepth 2 -name goose -type f | head -1)" /usr/local/bin/goose \
 && rm -rf /tmp/goose*

# --- Qwen Code --------------------------------------------------------------
RUN curl -fsSL -o /tmp/qwen.tar.gz \
      https://github.com/QwenLM/qwen-code/releases/download/v${QWENCODE}/qwen-code-linux-x64.tar.gz \
 && mkdir -p /opt/qwen-code && tar xzf /tmp/qwen.tar.gz -C /opt/qwen-code --strip-components=1 \
 && rm /tmp/qwen.tar.gz \
 # Qwen Code bringt sein eigenes Node mit, sucht es aber unter /usr/local/node.
 && ln -sfn /opt/qwen-code/node /usr/local/node \
 # KEIN Symlink nach /usr/local/bin: der Starter loest cli-entry.js relativ zu
 # seinem eigenen Ort auf und sucht sie dann unter /usr/local/lib. Ein Wrapper,
 # der den echten Pfad ausfuehrt, behaelt die Ordnerstruktur bei.
 && printf '#!/bin/sh\nexec /opt/qwen-code/bin/qwen "$@"\n' > /usr/local/bin/qwen \
 && chmod 0755 /usr/local/bin/qwen

# --- Aider ------------------------------------------------------------------
# Eigene Umgebung, damit seine Abhaengigkeiten nichts anderes anfassen.
# Eigene Python-Fassung ueber uv: Debian 13 bringt 3.13, und aider zieht ein
# numpy, fuer das es dafuer kein fertiges Paket gibt -- der Bau aus Quelltext
# scheitert an einer entfernten Schnittstelle in pkgutil. uv holt sich 3.12 und
# umgeht das, ohne am System-Python zu ruehren.
# UV_PYTHON_INSTALL_DIR ist Pflicht: uv legt seine Python-Fassung sonst unter
# /root/.local ab, und root-Heim ist fuer den Pruefnutzer gesperrt -- aider
# scheitert dann mit "Permission denied" an seiner eigenen Interpreterzeile.
ENV UV_PYTHON_INSTALL_DIR=/opt/uv-python
RUN curl -fsSL https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh \
 && uv venv --python 3.12 /opt/aider \
 && VIRTUAL_ENV=/opt/aider uv pip install --no-cache aider-chat \
 && ln -sf /opt/aider/bin/aider /usr/local/bin/aider

# Rechte geradeziehen, bevor der Nutzer wechselt. Der uv-Installer hat /tmp auf
# 755 gesetzt -- damit scheitert jeder Agent, der dort ein Arbeitsverzeichnis
# anlegen will, mit EACCES, und es sieht aus wie ein Fehler des Agenten.
RUN chmod 1777 /tmp && chmod -R a+rX /opt/aider /opt/qwen-code /opt/uv-python

# Nicht als root arbeiten: der Agent fuehrt Code aus, den ein Modell geschrieben hat.
RUN useradd -m -u 1000 pruef
USER pruef
WORKDIR /arbeit
ENV HOME=/home/pruef
