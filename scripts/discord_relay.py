#!/usr/bin/env python3
import json
import os
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

WEBHOOK_URL = os.environ.get("DISCORD_WEBHOOK_URL", "").strip()


def build_content(payload):
    alerts = payload.get("alerts", [])
    if not alerts:
        return "Alertmanager sent an empty alert list."

    lines = []
    for alert in alerts:
        status = alert.get("status", "unknown").upper()
        labels = alert.get("labels", {}) or {}
        annotations = alert.get("annotations", {}) or {}

        name = labels.get("alertname", "Alert")
        severity = labels.get("severity", "info")
        target_name = labels.get("target_name", labels.get("target", "unknown"))
        target = labels.get("target", "unknown")
        summary = annotations.get("summary", "")
        description = annotations.get("description", "")

        lines.append(f"**[{status}] {name}**")
        lines.append(f"Severity: {severity}")
        lines.append(f"Target: {target_name} ({target})")
        if summary:
            lines.append(f"Summary: {summary}")
        if description and description != summary:
            lines.append(f"Description: {description}")
        lines.append("")

    content = "\n".join(lines).strip()
    # Discord message limit is 2000 chars
    if len(content) > 1900:
        content = content[:1900] + "…"
    return content


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != "/alert":
            self.send_response(404)
            self.end_headers()
            return

        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length)

        try:
            payload = json.loads(raw.decode("utf-8"))
        except Exception:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"invalid json")
            return

        if not WEBHOOK_URL:
            self.send_response(500)
            self.end_headers()
            self.wfile.write(b"missing webhook url")
            return

        content = build_content(payload)
        body = json.dumps({"content": content}).encode("utf-8")
        req = urllib.request.Request(
            WEBHOOK_URL,
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )

        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                _ = resp.read()
        except Exception:
            self.send_response(502)
            self.end_headers()
            self.wfile.write(b"discord webhook error")
            return

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"ok")

    def log_message(self, format, *args):
        return


def main():
    server = HTTPServer(("0.0.0.0", 9094), Handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
