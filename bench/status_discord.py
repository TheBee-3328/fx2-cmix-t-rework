#!/usr/bin/env python3
"""Human-readable Discord milestones only.

  status_discord.py started --name "PPMD memory tweak" --why "See if a slightly smaller PPMD helps compression"
  status_discord.py screening-done --name "PPMD memory tweak" --bytes 1627084 --delta 0
  status_discord.py holdout-done --name "PPMD memory tweak" --bytes 524904 --delta 0
  status_discord.py accept --name "..." --slices ... --holdout ... --why "..."
  status_discord.py reject --name "..." --slices ... --holdout ... --why "..."
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.request
from datetime import datetime, timezone


def webhook() -> str:
    if os.environ.get("DISCORD_WEBHOOK"):
        return os.environ["DISCORD_WEBHOOK"]
    path = os.path.join(os.path.dirname(__file__), ".discord_webhook")
    if os.path.isfile(path):
        return open(path, encoding="utf-8").read().strip()
    raise SystemExit("No Discord webhook configured")


COLORS = {"info": 0x5865F2, "ok": 0x57F287, "warn": 0xFEE75C, "fail": 0xED4245, "run": 0x3BA55D}


def send(title: str, description: str = "", status: str = "info") -> int:
    embed = {
        "title": title[:256],
        "description": description[:4096],
        "color": COLORS.get(status, COLORS["info"]),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "footer": {"text": "Hutter campaign"},
    }
    body = json.dumps({"embeds": [embed], "allowed_mentions": {"parse": []}}).encode()
    req = urllib.request.Request(
        webhook(),
        data=body,
        headers={
            "Content-Type": "application/json",
            "User-Agent": "DiscordBot (https://github.com/TheBee-3328/fx2-cmix-t-rework, 1.0)",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return 0 if resp.getcode() in (200, 204) else 1
    except Exception as e:
        print(f"discord error: {e}", file=sys.stderr)
        return 1


def delta_words(delta: int) -> str:
    if delta < 0:
        return f"{abs(delta)} bytes smaller than our best (good)"
    if delta > 0:
        return f"{delta} bytes larger than our best (worse)"
    return "same size as our best (no change)"


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("event", choices=["started", "screening-done", "holdout-done", "accept", "reject", "note"])
    p.add_argument("--name", default="this edit")
    p.add_argument("--why", default="")
    p.add_argument("--bytes", default="")
    p.add_argument("--delta", type=int, default=None)
    p.add_argument("--slices", default="")
    p.add_argument("--holdout", default="")
    p.add_argument("--best-s", type=int, default=1627084)
    p.add_argument("--best-h", type=int, default=524904)
    p.add_argument("--title", default="")
    a = p.parse_args()
    name = a.name

    if a.event == "started":
        body = f"Starting a new test: **{name}**."
        if a.why:
            body += f"\n{a.why}"
        body += "\nI'll report back when screening and holdout finish."
        return send("New edit testing", body, "info")

    if a.event == "screening-done":
        body = f"Finished the 10 screening slices for **{name}**."
        if a.bytes:
            body += f"\nTotal compressed size: **{a.bytes}** bytes."
        if a.delta is not None:
            body += f"\nThat is {delta_words(a.delta)}."
        body += "\nNext: checking the holdout set."
        return send("Screening slices done", body, "run")

    if a.event == "holdout-done":
        body = f"Finished the holdout check for **{name}**."
        if a.bytes:
            body += f"\nHoldout compressed size: **{a.bytes}** bytes."
        if a.delta is not None:
            body += f"\nThat is {delta_words(a.delta)}."
        return send("Holdout done", body, "run")

    if a.event == "accept":
        ds = int(a.slices) - a.best_s if a.slices else 0
        dh = int(a.holdout) - a.best_h if a.holdout else 0
        body = (
            f"**Keeping this edit:** {name}\n"
            f"Screening: {a.slices} bytes ({delta_words(ds)}).\n"
            f"Holdout: {a.holdout} bytes ({delta_words(dh)})."
        )
        if a.why:
            body += f"\n{a.why}"
        return send("Accepted", body, "ok")

    if a.event == "reject":
        ds = int(a.slices) - a.best_s if a.slices else 0
        dh = int(a.holdout) - a.best_h if a.holdout else 0
        body = (
            f"**Dropping this edit:** {name}\n"
            f"Screening: {a.slices} bytes ({delta_words(ds)}).\n"
            f"Holdout: {a.holdout} bytes ({delta_words(dh)})."
        )
        if a.why:
            body += f"\n{a.why}"
        else:
            body += "\nIt did not beat our best on both screening and holdout."
        return send("Rejected", body, "warn")

    if a.event == "note":
        return send(a.title or "Update", a.why or a.name, "info")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
