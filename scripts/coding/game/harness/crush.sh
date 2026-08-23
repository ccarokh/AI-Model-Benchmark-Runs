# Crush (Charm) -- a terminal agent in Go, structurally closest to OpenCode.
# Hence the first comparison point: the difference then really measures
# "different agent" and not "different way of working".
agent_vorbereiten() {
  mkdir -p "$ziel/crushheim/.config/crush" "$ziel/crushdaten"
  cat > "$ziel/crushheim/.config/crush/crush.json" <<J
{
  "\$schema": "https://charm.land/crush.json",
  "providers": {
    "lokal": {
      "type": "openai",
      "base_url": "http://$MESS:$PORT/v1",
      "api_key": "egal",
      "models": [
        { "id": "$model", "name": "$model",
          "context_window": $ctx, "default_max_tokens": $maxtok }
      ]
    }
  },
  "models": {
    "large": { "model": "$model", "provider": "lokal" },
    "small": { "model": "$model", "provider": "lokal" }
  },
  "permissions": { "allowed_tools": ["*"] }
}
J
  chown -R 1000:1000 "$ziel/crushheim" "$ziel/crushdaten"
}

agent_ausfuehren() {
  # Crush has no -y; its permissions live in the config
  # (permissions.allowed_tools), set above.
  timeout "$zeitlimit" docker run --rm \
    -v "$ziel/crushheim":/home/pruef \
    -v "$ziel/arbeit":/arbeit \
    pruefstand:2 crush run -q "$(cat "$ziel/aufgabe.txt")" \
    > "$ziel/agent.log" 2>&1
}
