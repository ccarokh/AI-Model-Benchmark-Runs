# Crush (Charm) -- Terminal-Agent in Go, OpenCode strukturell am naechsten.
# Deshalb der erste Vergleichspunkt: der Unterschied misst dann tatsaechlich
# "anderer Agent" und nicht "anderes Arbeitsprinzip".
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
  # Crush kennt kein -y; die Erlaubnisse stehen bei ihm in der Konfiguration
  # (permissions.allowed_tools), und die ist oben gesetzt.
  timeout "$zeitlimit" docker run --rm \
    -v "$ziel/crushheim":/home/pruef \
    -v "$ziel/arbeit":/arbeit \
    pruefstand:2 crush run -q "$(cat "$ziel/aufgabe.txt")" \
    > "$ziel/agent.log" 2>&1
}
