# Qwen Code -- Abkoemmling der Gemini-CLI, spricht OpenAI-kompatible Endpunkte
# ueber Umgebungsvariablen statt ueber eine Konfigurationsdatei.
agent_vorbereiten() { mkdir -p "$ziel/qwenheim"; chown 1000:1000 "$ziel/qwenheim"; }

agent_ausfuehren() {
  # --yolo: keine Rueckfragen. Gefahrlos, weil der Behaelter Wegwerfware ist.
  timeout "$zeitlimit" docker run --rm \
    -v "$ziel/arbeit":/arbeit -v "$ziel/qwenheim":/home/pruef/.qwen \
    -e OPENAI_API_KEY=egal -e OPENAI_BASE_URL="http://$MESS:$PORT/v1" \
    -e OPENAI_MODEL="$model" \
    pruefstand:2 qwen --yolo -m "$model" -p "$(cat "$ziel/aufgabe.txt")" \
    > "$ziel/agent.log" 2>&1
}
