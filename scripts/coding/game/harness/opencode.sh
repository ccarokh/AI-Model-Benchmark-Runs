# OpenCode -- the harness that was built first.
agent_vorbereiten() {
  # Mount the WHOLE home directory, not individual subdirectories. Docker
  # creates missing mount points as root -- then /home/pruef/.local belongs to
  # root and opencode fails beside it with EACCES creating .local/state.
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
  # --auto: no veto from the harness. Without it OpenCode refuses every write
  # outside the working directory and tells the model "The user rejected
  # permission" -- which reads like "a human said no", not like "use a different
  # path". Two models stopped at that instead of trying differently.
  timeout "$zeitlimit" docker run --rm \
    -v "$ziel/ocheim":/home/pruef \
    -v "$ziel/arbeit":/arbeit \
    pruefstand:2 opencode run --auto "$(cat "$ziel/aufgabe.txt")" \
    > "$ziel/agent.log" 2>&1
}
