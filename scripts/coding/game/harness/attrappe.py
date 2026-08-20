#!/usr/bin/env python3
"""OpenAI-kompatible Attrappe, um die Verdrahtung der Agenten zu pruefen.

Sie braucht keine Karte und kein Modell. Antwortet auf /v1/models und
/v1/chat/completions mit einer festen Antwort und schreibt jede Anfrage mit.
Damit laesst sich fuer jeden Agenten feststellen, ob er ueberhaupt bei unserem
Endpunkt ankommt -- getrennt von der Frage, ob ein Modell die Aufgabe loest.

    python3 attrappe.py 18299 protokoll.jsonl
"""
import json, sys, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 18299
LOG = sys.argv[2] if len(sys.argv) > 2 else "attrappe.jsonl"

class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def log_message(self, *_): pass

    def _senden(self, obj, code=200):
        leib = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(leib)))
        self.end_headers()
        self.wfile.write(leib)

    def do_GET(self):
        with open(LOG, "a") as f:
            f.write(json.dumps({"pfad": self.path, "methode": "GET"}) + "\n")
        if self.path.rstrip("/").endswith("/models"):
            return self._senden({"object": "list", "data": [
                {"id": "attrappe", "object": "model", "owned_by": "pruefstand"}]})
        self._senden({"status": "ok"})

    def do_POST(self):
        n = int(self.headers.get("Content-Length") or 0)
        roh = self.rfile.read(n)
        try: ein = json.loads(roh or b"{}")
        except ValueError: ein = {"unlesbar": True}
        with open(LOG, "a") as f:
            f.write(json.dumps({"pfad": self.path, "methode": "POST",
                                "modell": ein.get("model"),
                                "max_tokens": ein.get("max_tokens"),
                                "werkzeuge": len(ein.get("tools") or []),
                                "nachrichten": len(ein.get("messages") or [])}) + "\n")
        self._senden({
            "id": "attrappe-1", "object": "chat.completion",
            "created": int(time.time()), "model": ein.get("model", "attrappe"),
            "choices": [{"index": 0, "finish_reason": "stop", "message": {
                "role": "assistant",
                "content": "Attrappe: verstanden. Ich lege nichts an."}}],
            "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2}})

ThreadingHTTPServer(("0.0.0.0", PORT), H).serve_forever()
