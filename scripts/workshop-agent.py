#!/usr/bin/env python3
"""Workshop Mac agent. Polls the contest dashboard and runs Reset Workshop --yes."""

from __future__ import annotations

import json
import os
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

CONFIG_DIR = Path.home() / "Library/Application Support/Ambassadors26"
CONFIG_PATH = CONFIG_DIR / "agent.json"
LOG_PATH = Path.home() / "Library/Logs/ambassadors26-agent.log"
POLL_SECONDS = 3


def log(message: str) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    line = time.strftime("%Y-%m-%d %H:%M:%S ") + message + "\n"
    with LOG_PATH.open("a", encoding="utf-8") as fh:
        fh.write(line)


def load_config() -> dict:
    if not CONFIG_PATH.exists():
        raise SystemExit(f"No agent config at {CONFIG_PATH}. Run Install Workshop Agent.command first.")
    return json.loads(CONFIG_PATH.read_text())


def save_config(cfg: dict) -> None:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    CONFIG_PATH.write_text(json.dumps(cfg, indent=2) + "\n")


def computer_name() -> str:
    try:
        out = subprocess.check_output(["scutil", "--get", "ComputerName"], text=True).strip()
        if out:
            return out
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    return socket.gethostname().split(".")[0]


def request(cfg: dict, method: str, path: str, payload: dict | None = None) -> dict:
    url = cfg["server"].rstrip("/") + path
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("content-type", "application/json")
    req.add_header("x-agent-secret", cfg["secret"])
    if cfg.get("token"):
        req.add_header("authorization", "Bearer " + cfg["token"])
    try:
        with urllib.request.urlopen(req, timeout=20) as res:
            body = res.read().decode()
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")
        raise RuntimeError(f"{method} {path} -> {exc.code} {detail}") from exc


def hello(cfg: dict) -> dict:
    label = computer_name()
    reply = request(
        cfg,
        "POST",
        "/api/agent/hello",
        {
            "hostname": socket.gethostname(),
            "label": label,
            "token": cfg.get("token") or "",
        },
    )
    if reply.get("token") and reply["token"] != cfg.get("token"):
        cfg["token"] = reply["token"]
        save_config(cfg)
    return reply


def run_reset(cfg: dict) -> None:
    pack = Path(cfg["pack"]).expanduser().resolve()
    script = pack / "scripts" / "Reset Workshop.command"
    if not script.is_file():
        raise RuntimeError(f"Reset script missing: {script}")
    env = os.environ.copy()
    env["MIB_RESET_YES"] = "1"
    result = subprocess.run(
        ["/bin/bash", str(script), "--yes"],
        cwd=str(pack),
        env=env,
        capture_output=True,
        text=True,
        timeout=180,
    )
    if result.returncode != 0:
        err = (result.stderr or result.stdout or "reset failed").strip()
        raise RuntimeError(err[-800:])
    server = cfg["server"].rstrip("/")
    subprocess.run(["open", f"{server}/leave"], check=False)


def loop() -> None:
    cfg = load_config()
    log(f"agent starting pack={cfg.get('pack')} server={cfg.get('server')}")
    while True:
        try:
            hello(cfg)
            poll = request(cfg, "GET", "/api/agent/poll")
            if poll.get("reset"):
                log("reset requested")
                try:
                    run_reset(cfg)
                    request(cfg, "POST", "/api/agent/ack", {"ok": True, "theme": ""})
                    log("reset done")
                except Exception as exc:
                    log(f"reset failed: {exc}")
                    try:
                        request(cfg, "POST", "/api/agent/ack", {"ok": False, "error": str(exc)[:500]})
                    except Exception as ack_exc:
                        log(f"ack failed: {ack_exc}")
        except Exception as exc:
            log(f"poll error: {exc}")
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    try:
        loop()
    except KeyboardInterrupt:
        sys.exit(0)
