# deepseek-r1-7b

Everything measured about this model here. **Blank means never measured, not "failed".**

Numbers link back to the document that interprets them; the raw rows are in
[`data/`](../data/).

⚠️ **The published 0.64 is a statement about the harness, not this model.** It was
measured with letter-logprob, which
[cannot measure a model that reasons first](../findings/harness-effect.md) — its 14B
sibling scores 0.2133 there and 0.9133 when allowed to answer. It is also a partial run
at n = 50.

## German comprehension — belebele, answer read from the first token's probability

Source: [`chat_belebele.tsv`](../data/chat_belebele.tsv) · interpreted in [language-understanding](../use-cases/language-understanding.md)

| model | correct | n | accuracy |
|---|---|---|---|
| deepseek-r1-7b | 32 | 50 | 0.6400 |
