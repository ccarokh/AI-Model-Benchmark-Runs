# Der Pruefstand, gekapselt: hier drin schreibt und startet ein Modell Code.
#
# Kein GPU-Durchgriff -- die Karte steht auf .192, dieser Behaelter redet nur
# ueber HTTP mit dem Modellserver. Deshalb laeuft er auch auf einem anderen
# Rechner: waehrend einer Messung gehoert keine Fremdlast auf den Messrechner.
FROM debian:13-slim

ARG OPENCODE=1.18.18
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git jq unzip python3 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL -o /tmp/oc.tar.gz \
      https://github.com/anomalyco/opencode/releases/download/v${OPENCODE}/opencode-linux-x64.tar.gz \
 && tar xzf /tmp/oc.tar.gz -C /usr/local/bin \
 && rm /tmp/oc.tar.gz \
 && chmod +x /usr/local/bin/opencode

# Nicht als root arbeiten: der Agent fuehrt Code aus, den ein Modell geschrieben hat.
RUN useradd -m -u 1000 pruef
# Die Heimatverzeichnisse im Abbild anlegen, nicht dem Einhaengen ueberlassen.
# Docker legt fehlende Einhaengepunkte als root an -- dann gehoert
# /home/pruef/.local root, und opencode scheitert an mkdir .local/state mit
# EACCES. Das hat drei Laeufe gekostet, die wie Modellversagen aussahen.
RUN mkdir -p /home/pruef/.local/share/opencode /home/pruef/.local/state \
             /home/pruef/.config/opencode /home/pruef/.cache \
 && chown -R pruef:pruef /home/pruef
USER pruef
WORKDIR /arbeit
ENV HOME=/home/pruef
