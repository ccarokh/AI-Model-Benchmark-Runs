# Qwen Code -- a descendant of the Gemini CLI, speaks OpenAI-compatible
# endpoints through environment variables rather than a config file.
agent_vorbereiten() { mkdir -p "$ziel/qwenheim"; chown 1000:1000 "$ziel/qwenheim"; }

agent_ausfuehren() {
  # --yolo: no questions back. Harmless, because the container is disposable.
  timeout "$zeitlimit" docker run --rm \
    -v "$ziel/arbeit":/arbeit -v "$ziel/qwenheim":/home/pruef/.qwen \
    -e OPENAI_API_KEY=egal -e OPENAI_BASE_URL="http://$MESS:$PORT/v1" \
    -e OPENAI_MODEL="$model" \
    pruefstand:2 qwen --yolo -m "$model" -p "$(cat "$ziel/aufgabe.txt")" \
    > "$ziel/agent.log" 2>&1
}
