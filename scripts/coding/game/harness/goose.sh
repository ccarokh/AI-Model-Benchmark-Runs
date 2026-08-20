# Goose (Block) -- Rust-Agent, Anbieter ueber Umgebung und eine YAML-Datei.
agent_vorbereiten() {
  mkdir -p "$ziel/gooseheim/.config/goose"
  cat > "$ziel/gooseheim/.config/goose/config.yaml" <<J
GOOSE_PROVIDER: openai
GOOSE_MODEL: $model
GOOSE_MODE: auto
extensions:
  developer:
    enabled: true
    type: builtin
    name: developer
J
  chown -R 1000:1000 "$ziel/gooseheim"
}

agent_ausfuehren() {
  # GOOSE_MODE=auto: keine Rueckfragen.
  timeout "$zeitlimit" docker run --rm \
    -v "$ziel/gooseheim":/home/pruef \
    -v "$ziel/arbeit":/arbeit \
    -e OPENAI_API_KEY=egal -e OPENAI_HOST="http://$MESS:$PORT" \
    -e OPENAI_BASE_PATH=/v1/chat/completions -e GOOSE_MODE=auto \
    pruefstand:2 goose run -t "$(cat "$ziel/aufgabe.txt")" \
    > "$ziel/agent.log" 2>&1
}
