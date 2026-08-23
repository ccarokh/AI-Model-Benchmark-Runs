# Aider -- works through git diffs rather than free file access. That is a
# different way of working, not just a different name, and interesting for
# exactly that reason: if the harness really counts, it has to show here.
agent_vorbereiten() { mkdir -p "$ziel/arbeit"; }

agent_ausfuehren() {
  # --no-git because the working directory is empty and not a repository.
  # --yes-always because nobody is there to answer questions.
  timeout "$zeitlimit" docker run --rm \
    -v "$ziel/arbeit":/arbeit \
    -e OPENAI_API_BASE="http://$MESS:$PORT/v1" -e OPENAI_API_KEY=egal \
    pruefstand:2 aider \
      --model "openai/$model" \
      --no-git --yes-always --no-analytics --no-check-update \
      --message "$(cat "$ziel/aufgabe.txt")" \
    > "$ziel/agent.log" 2>&1
}
