import sys, time
sys.path.insert(0, "/root/testbench")
import detect
from harness import Build, server_load
from pathlib import Path

build = Build(path=Path("/opt/mess/llama.cpp/build"), backend="vulkan", version="x")
model = Path("/opt/mess/models/gemma-4-12b-qat/gemma-4-12b-it-qat-q4_0.gguf")
prompt = ("Beantworte die Frage ausschliesslich mit dem folgenden Text. Text: Die Wartung "
          "erfolgt jaehrlich im Maerz, zustaendig ist die Betriebstechnik, die Bestellfrist "
          "fuer Ersatzteile betraegt vierzehn Tage. Frage: Wer ist zustaendig und wie lange "
          "dauert eine Bestellung?")
print("Nutzer  Slots  gesamt t/s   je Nutzer   langsamste Antwort   Fehler")
for users, slots in [(4, 4), (8, 4), (16, 4), (32, 4), (16, 2)]:
    r = server_load(build, model, prompt, users, per_user_ctx=8192, n_predict=200, slots=slots)
    if not r["ok"]:
        print("%5d %6d   LAEUFT NICHT: %s" % (users, slots, r["reason"][:70]))
        continue
    print("%5d %6d %10.1f %11.1f %14.1f s %8d" % (
        users, slots, r["aggregate"], r["per_user"], r["slowest"], r["failures"]))
