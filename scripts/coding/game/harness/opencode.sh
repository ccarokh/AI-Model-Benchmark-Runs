# OpenCode -- der zuerst gebaute Pruefstand.
agent_vorbereiten() {
  # Das GANZE Heimatverzeichnis einhaengen, nicht einzelne Unterordner. Docker
  # legt fehlende Einhaengepunkte als root an -- dann gehoert /home/pruef/.local
  # root, und opencode scheitert daneben mit EACCES beim Anlegen von .local/state.
  mkdir -p "$ziel/ocheim/.config/opencode" "$ziel/ocheim/.local/share/opencode" \
           "$ziel/ocheim/.local/state"
  cat > "$ziel/ocheim/.config/opencode/opencode.json" <<J
{
  "\$schema": "https://opencode.ai/config.json",
  "provider": {
    "lokal": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "$runtime auf $MESS",
      "options": { "baseURL": "http://$MESS:$PORT/v1", "apiKey": "egal" },
      "models": { "$model": { "name": "$model",
        "limit": { "context": $ctx, "output": $maxtok } } }
    }
  },
  "model": "lokal/$model",
  "small_model": "lokal/$model"
}
J
  chown -R 1000:1000 "$ziel/ocheim"
}

agent_ausfuehren() {
  # --auto: kein Veto des Pruefstands. Ohne den Schalter lehnt OpenCode jeden
  # Schreibzugriff ausserhalb des Arbeitsverzeichnisses ab und meldet dem Modell
  # "The user rejected permission" -- das liest sich wie "ein Mensch hat nein
  # gesagt", nicht wie "nimm einen anderen Pfad". Zwei Modelle haben daraufhin
  # aufgehoert statt es anders zu versuchen.
  timeout "$zeitlimit" docker run --rm \
    -v "$ziel/ocheim":/home/pruef \
    -v "$ziel/arbeit":/arbeit \
    pruefstand:2 opencode run --auto "$(cat "$ziel/aufgabe.txt")" \
    > "$ziel/agent.log" 2>&1
}
