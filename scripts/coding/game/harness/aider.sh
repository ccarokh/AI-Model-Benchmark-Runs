# Aider -- arbeitet ueber Git-Diffs statt ueber freie Dateizugriffe. Das ist ein
# anderes Arbeitsprinzip, nicht nur ein anderer Name, und genau deshalb
# interessant: wenn der Pruefstand wirklich zaehlt, muss man es hier sehen.
agent_vorbereiten() { mkdir -p "$ziel/arbeit"; }

agent_ausfuehren() {
  # --no-git, weil das Arbeitsverzeichnis leer und kein Repository ist.
  # --yes-always, weil niemand da ist, der Rueckfragen beantwortet.
  timeout "$zeitlimit" docker run --rm \
    -v "$ziel/arbeit":/arbeit \
    -e OPENAI_API_BASE="http://$MESS:$PORT/v1" -e OPENAI_API_KEY=egal \
    pruefstand:2 aider \
      --model "openai/$model" \
      --no-git --yes-always --no-analytics --no-check-update \
      --message "$(cat "$ziel/aufgabe.txt")" \
    > "$ziel/agent.log" 2>&1
}
