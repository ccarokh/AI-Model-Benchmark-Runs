# The harness, encapsulated: inside here a model writes and runs code.
#
# ALL agents in one image. The harness is the biggest unmeasured variable in
# this repo -- on belebele it was worth up to 70 points -- and as long as only
# one is installed, the question cannot even be asked. Which one runs is
# decided by the run's configuration.
#
# No GPU passthrough: the card sits in the measuring machine, this container
# only talks HTTP. That is also why it runs elsewhere -- no foreign load
# belongs on the measuring machine during a run.
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
 # Qwen Code ships its own Node but looks for it under /usr/local/node.
 && ln -sfn /opt/qwen-code/node /usr/local/node \
 # NO symlink into /usr/local/bin: the launcher resolves cli-entry.js relative
 # to its own location and would then look under /usr/local/lib. A wrapper that
 # executes the real path keeps the directory layout intact.
 && printf '#!/bin/sh\nexec /opt/qwen-code/bin/qwen "$@"\n' > /usr/local/bin/qwen \
 && chmod 0755 /usr/local/bin/qwen

# --- Aider ------------------------------------------------------------------
# Its own environment, so its dependencies touch nothing else.
# Its own Python via uv: Debian 13 ships 3.13, and aider pulls a numpy that has
# no prebuilt wheel for it -- building from source fails on an interface
# removed from pkgutil. uv fetches 3.12 and sidesteps that without touching the
# system Python.
# UV_PYTHON_INSTALL_DIR is mandatory: otherwise uv puts its Python under
# /root/.local, and root's home is closed to the test user -- aider then fails
# with "Permission denied" on its own interpreter line.
ENV UV_PYTHON_INSTALL_DIR=/opt/uv-python
RUN curl -fsSL https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/usr/local/bin sh \
 && uv venv --python 3.12 /opt/aider \
 && VIRTUAL_ENV=/opt/aider uv pip install --no-cache aider-chat \
 && ln -sf /opt/aider/bin/aider /usr/local/bin/aider

# Straighten out permissions before switching users. The uv installer set /tmp
# to 755 -- every agent that wants a working directory there then fails with
# EACCES, and it looks like a fault of the agent.
RUN chmod 1777 /tmp && chmod -R a+rX /opt/aider /opt/qwen-code /opt/uv-python

# Do not work as root: the agent runs code a model wrote.
RUN useradd -m -u 1000 pruef
USER pruef
WORKDIR /arbeit
ENV HOME=/home/pruef
