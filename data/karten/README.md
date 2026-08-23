# Bandbreite gegen Erzeugungsrate

`bandbreite_vs_erzeugung.tsv` — dieselbe Datei, derselbe Befehl, derselbe llama.cpp-Bau
und derselbe Treiber auf verschiedenen Karten. Die einzige Variable ist die Karte.

```
llama-bench -m Llama-3.2-3B-Instruct-Q4_K_M.gguf -n 128 -p 512,4096 -pg 4096,128 -ngl 99 -r 20
Bau 70adb1b · Vulkan · Treiber 610.57.04
```

## Zwei Messungen derselben Karte, und warum beide dastehen

Die RTX 3080 sitzt im Arbeitsrechner, und beim ersten Lauf lief der Desktop mit: 2 620 MiB
belegt, 22 % Grundlast. Der zweite Lauf fand nach dem Beenden der meisten Anwendungen
statt, 1 405 MiB.

| | mit Desktop | aufgeräumt |
|---|---|---|
| tg128 | 203,20 ± **15,55** | 218,90 ± **0,77** |
| pp512 | 8 734 ± **1 244** | 8 269 ± **143** |

**Die Streuung fällt um das Zwanzigfache, der Wert steigt um 7,7 %.** Das ist der Preis
einer belegten Karte, beziffert — und der Grund, warum die aufgeräumte Messung die
gültige ist.

Auch sie bleibt eine **Untergrenze**: 1 405 MiB Desktop liegen weiterhin darauf. Für den
Befund macht das nichts, im Gegenteil — die 3080 verliert trotz dieses Vorteils.

⚠️ **Von der ersten Messung existieren keine Rohdaten mehr.** Sie wurden auf ein
„verwerfen" hin gelöscht, bevor entschieden war, dass sie als Vergleichspunkt bleiben
soll. Hier stehen nur die Mittelwerte aus der Ausgabe des Laufs. Verworfene Messungen
gehören markiert, nicht entfernt — sonst fehlt später genau der Beleg, den man doch
braucht.
