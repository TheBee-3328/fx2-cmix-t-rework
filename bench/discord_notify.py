#!/usr/bin/env python3
"""Send a Discord webhook embed. Usage:
  discord_notify.py TITLE DESC [field=value ...] [--color COLOR] [--status ok|warn|fail|info]
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.request
from datetime import datetime, timezone

def _default_webhook() -> str:
    if os.environ.get("DISCORD_WEBHOOK"):
        return os.environ["DISCORD_WEBHOOK"]
    path = os.path.join(os.path.dirname(__file__), ".discord_webhook")
    if os.path.isfile(path):
        return open(path, encoding="utf-8").read().strip()
    raise SystemExit("No DISCORD_WEBHOOK env or bench/.discord_webhook file")


DEFAULT_WEBHOOK = _default_webhook()

COLORS = {
    "info": 0x5865F2,   # blurple
    "ok": 0x57F287,     # green
    "warn": 0xFEE75C,   # yellow
    "fail": 0xED4245,   # red
    "run": 0xEB459E,    # fuchsia / in-progress
}


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("title")
    p.add_argument("description", nargs="?", default="")
    p.add_argument("fields", nargs="*", help="name=value (value may contain =)")
    p.add_argument("--status", choices=COLORS.keys(), default="info")
    p.add_argument("--color", type=lambda s: int(s, 0), default=None)
    p.add_argument("--footer", default="fx2-cmix-t-rework monitor")
    p.add_argument("--webhook", default=DEFAULT_WEBHOOK)
    args = p.parse_args()

    fields = []
    for raw in args.fields:
        if "=" not in raw:
            continue
        name, value = raw.split("=", 1)
        fields.append({
            "name": name[:256],
            "value": (value or "—")[:1024],
            "inline": True,
        })

    embed = {
        "title": args.title[:256],
        "description": args.description[:4096],
        "color": args.color if args.color is not None else COLORS[args.status],
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "footer": {"text": args.footer[:2048]},
    }
    if fields:
        embed["fields"] = fields[:25]

    body = json.dumps({"embeds": [embed], "allowed_mentions": {"parse": []}}).encode()
    req = urllib.request.Request(
        args.webhook,
        data=body,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "DiscordBot (https://github.com/TheBee-3328/fx2-cmix-t-rework, 1.0)",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            code = resp.getcode()
    except Exception as e:
        print(f"discord error: {e}", file=sys.stderr)
        return 1
    print(code)
    return 0 if code in (200, 204) else 1


if __name__ == "__main__":
    raise SystemExit(main())
