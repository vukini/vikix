#!/usr/bin/env python3
"""debug-scrub.py — take secrets and personal details out of a vikix debug
report, read on stdin, written to stdout.

What goes, in this order:
  1. the values of your keys themselves, wherever they appear, whatever
     their shape: each file in ~/.config/vikix/secrets, and each variable
     in the environment named like a key (..._KEY, _TOKEN, _SECRET, ...);
  2. anything shaped like a key (the shapes `vikix ai key check` knows);
  3. NAME=value where NAME looks like a key, token, secret or password,
     "Authorization: Bearer ...", and a password inside a URL;
  4. your home folder (becomes ~), your user name and the machine's name.
Progress bars and colours are tidied first, as a terminal would show them.

The keys are read here and never printed, not even in part.
"""
import os
import re
import socket
import sys

REMOVED = "[removed]"

# The same shapes as KEY_SHAPES in bin/vikix-ai (keep them in step).
KEY_SHAPES = (r"sk-ant-[A-Za-z0-9_-]{16,}|sk-(proj-)?[A-Za-z0-9_-]{20,}|pplx-[A-Za-z0-9]{20,}"
              r"|AIza[A-Za-z0-9_-]{30,}|gsk_[A-Za-z0-9]{20,}|xai-[A-Za-z0-9]{20,}"
              r"|hf_[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}"
              r"|gho_[A-Za-z0-9]{30,}|glpat-[A-Za-z0-9_-]{20,}|AKIA[A-Z0-9]{16}")
SECRET_NAME = r"[A-Za-z0-9_]*(?:API_KEY|_KEY|_TOKEN|_SECRET|PASSWORD|PASSWD|_CREDENTIALS)"
SECRET_ENV = re.compile(r"^[A-Za-z0-9_]*(API_KEY|_KEY|_KEY_ID|_TOKEN|_SECRET|PASSWORD|PASSWD|_CREDENTIALS)$")


def known_values():
    """The actual secrets, longest first, so a longer one isn't cut short."""
    values = set()
    home = os.path.expanduser("~")
    folder = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.join(home, ".config"),
                          "vikix", "secrets")
    try:
        for name in os.listdir(folder):
            path = os.path.join(folder, name)
            if os.path.isfile(path):
                try:
                    with open(path, errors="replace") as f:
                        values.add(f.read().strip())
                except OSError:
                    pass
    except OSError:
        pass
    for name, value in os.environ.items():
        if SECRET_ENV.match(name):
            values.add(value.strip())
    # Also the backup password, if there is one.
    bp = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.join(home, ".config"),
                      "vikix", "backup-password")
    try:
        with open(bp, errors="replace") as f:
            values.add(f.read().strip())
    except OSError:
        pass
    # Short values would remove ordinary words: a real key is longer.
    return sorted((v for v in values if len(v) >= 8), key=len, reverse=True)


def tidy(text):
    """What a terminal would show: a progress bar's many updates on one line
    (joined by carriage returns) become its last, and colours go."""
    text = re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", text)
    text = text.replace("\r\n", "\n")
    return re.sub(r"[^\n]*\r", "", text)


def scrub(text):
    text = tidy(text)
    for v in known_values():
        text = text.replace(v, REMOVED)
    text = re.sub(r"(^|[^A-Za-z0-9_-])(" + KEY_SHAPES + r")", lambda m: m.group(1) + REMOVED, text)
    text = re.sub(r"\b(" + SECRET_NAME + r")(\s*[=:]\s*)([\"']?)[^\s\"']{4,}\3",
                  lambda m: m.group(1) + m.group(2) + REMOVED, text)
    text = re.sub(r"(?i)\b(authorization:\s*(?:bearer|basic|token)\s+)\S+", r"\1" + REMOVED, text)
    text = re.sub(r"([a-z][a-z0-9+.-]*://)[^/\s:@]+:[^/\s@]+@", r"\1" + REMOVED + "@", text)
    home = os.path.expanduser("~")
    if len(home) > 1:
        text = text.replace(home, "~")
    user = os.environ.get("USER") or os.path.basename(home)
    if user and len(user) >= 3 and user != "root":
        text = re.sub(r"\b" + re.escape(user) + r"\b", "[user]", text)
    host = socket.gethostname()
    if host and len(host) >= 3 and host not in ("localhost",):
        text = re.sub(r"\b" + re.escape(host) + r"\b", "[host]", text)
    return text


if __name__ == "__main__":
    sys.stdout.write(scrub(sys.stdin.read()))
