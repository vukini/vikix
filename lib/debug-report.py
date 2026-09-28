#!/usr/bin/env python3
"""debug-report.py — the text side of `vikix debug`: which log lines go in,
the problems at a glance, taking secrets and personal details out, and the
last check over the finished file.

  debug-report.py                    scrub stdin to stdout
  debug-report.py --session FILE     Vikix's own lines of a session log:
                                     its start and its end
  debug-report.py --vikix-log FILE N the last N of Vikix's own lines of an
                                     install or update log
  debug-report.py --problems FILE... the lines that say something failed
  debug-report.py --check FILE       line numbers of anything secret-looking
                                     left (nothing printed but numbers)

Only Vikix's own lines go in (its start-up trace, its :: and !! messages,
StumpWM's): a browser's or file manager's lines carry the pages you had
open, file names, and text a web page chose, which an agent reading the
report must not take as instructions.

What scrubbing takes out, in this order:
  1. the values of your secrets themselves, whatever their shape: each file
     in ~/.config/vikix/secrets, key-named variables in the environment,
     the backup password, Swank's password, passwords in ~/.git-credentials
     and ~/.netrc;
  2. private key blocks, and anything shaped like a key or token;
  3. a value after a secret-looking name, in any case and form (NAME=v,
     name: v, "name": "v", --password=v), Bearer/Basic credentials, curl -u;
  4. a web address's path and query (its scheme and host stay), and a
     password inside it;
  5. long strings that look random (mixed case and digits);
  6. your home folder (becomes ~), user name, full name and machine name.
Progress bars and terminal control codes are tidied first.

The secrets are read here and never printed, not even in part.
"""
import os
import pwd
import re
import socket
import sys

REMOVED = "[removed]"
HOME = os.path.expanduser("~")
CONFIG = os.environ.get("XDG_CONFIG_HOME") or os.path.join(HOME, ".config")

# Known shapes (bin/vikix-ai's KEY_SHAPES, and more).
KEY_SHAPES = "|".join([
    r"sk-ant-[A-Za-z0-9_-]{16,}", r"sk-(?:proj-|svcacct-|admin-)?[A-Za-z0-9_-]{20,}",
    r"pplx-[A-Za-z0-9]{20,}", r"AIza[A-Za-z0-9_-]{30,}", r"gsk_[A-Za-z0-9]{20,}",
    r"xai-[A-Za-z0-9]{20,}", r"hf_[A-Za-z0-9]{20,}", r"gh[pousr]_[A-Za-z0-9]{30,}",
    r"github_pat_[A-Za-z0-9_]{30,}", r"glpat-[A-Za-z0-9_-]{20,}", r"(?:AKIA|ASIA)[A-Z0-9]{16}",
    r"xox[abprs]-[A-Za-z0-9-]{10,}", r"(?:sk|rk|pk)_(?:live|test)_[A-Za-z0-9]{16,}",
    r"eyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}",
    r"ya29\.[A-Za-z0-9_-]{20,}", r"1//[A-Za-z0-9_-]{20,}", r"npm_[A-Za-z0-9]{30,}",
    r"pypi-[A-Za-z0-9_-]{40,}", r"dop_v1_[a-f0-9]{40,}", r"AGE-SECRET-KEY-1[A-Z0-9]{40,}",
])
SHAPE_RE = re.compile(r"(?<![A-Za-z0-9])(?:" + KEY_SHAPES + ")")
PRIVATE_BLOCK = re.compile(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY( BLOCK)?-----.*?(-----END [A-Z0-9 ]*PRIVATE KEY( BLOCK)?-----|\Z)", re.S)
SECRET_WORDS = (r"(?:api[_-]?key|apikey|secret|token|passwd|password|passphrase|credentials?"
                r"|private[_-]?key|access[_-]?key|session[_-]?key|cookie|authorization)")
VALUE = r"(\"[^\"\n]*\"|'[^'\n]*'|[^\s,;\"'}\]]+)"
# name = value, name: value, "name": "value", --name=value; and --name value
NAMED = re.compile(r"(?i)(\b[\w.-]*" + SECRET_WORDS + r"[\w.-]*[\"']?\s*[=:]\s*)" + VALUE)
FLAG = re.compile(r"(?i)(--[\w-]*" + SECRET_WORDS + r"[\w-]*\s+)" + VALUE)
SECRET_ENV = re.compile(r"^[A-Za-z0-9_]*(API_KEY|_KEY|_KEY_ID|_TOKEN|_SECRET|PASSWORD|PASSWD|_CREDENTIALS)$")
# Words a name can't be taken out as: they're Vikix's own vocabulary.
COMMON = {"void", "vikix", "linux", "stumpwm", "user", "users", "home", "admin", "test", "guest",
          "root", "main", "local", "desktop", "laptop", "localhost"}


def read_text(path):
    try:
        with open(path, "rb") as f:
            return f.read().decode("utf-8", errors="replace")
    except OSError:
        return ""


def known_values():
    """The actual secrets, longest first, so a longer one isn't cut short."""
    values = set()
    folder = os.path.join(CONFIG, "vikix", "secrets")
    try:
        for name in os.listdir(folder):
            values.add(read_text(os.path.join(folder, name)).strip())
    except OSError:
        pass
    for name, value in os.environ.items():
        if SECRET_ENV.match(name):
            values.add(value.strip())
    for path in (os.path.join(CONFIG, "vikix", "backup-password"), os.path.join(HOME, ".slime-secret")):
        values.add(read_text(path).strip())
    for m in re.finditer(r"://[^:/\s]+:([^@\s]+)@", read_text(os.path.join(HOME, ".git-credentials"))):
        values.add(m.group(1))
    for m in re.finditer(r"\bpassword\s+(\S+)", read_text(os.path.join(HOME, ".netrc"))):
        values.add(m.group(1))
    # Short values would remove ordinary words: a real secret is longer.
    return sorted((v for v in values if len(v) >= 8), key=len, reverse=True)


def tidy(text):
    """As a terminal would show it: no control codes, and a progress bar's
    many updates on one line (joined by carriage returns) its last."""
    text = re.sub(r"\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)", "", text)       # OSC
    text = re.sub(r"\x1b\[[0-9;?]*[ -/]*[@-~]", "", text)               # CSI
    text = re.sub(r"\x1b[@-Z\\-_]", "", text)
    text = text.replace("\r\n", "\n")
    text = re.sub(r"[^\n]*\r", "", text)
    return re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]", "", text)


def looks_random(word):
    return (len(word) >= 32 and re.search(r"[a-z]", word) and re.search(r"[A-Z]", word)
            and re.search(r"[0-9]", word))


def scrub(text):
    text = tidy(text)
    for v in known_values():
        text = text.replace(v, REMOVED)
    text = PRIVATE_BLOCK.sub(REMOVED, text)
    text = SHAPE_RE.sub(REMOVED, text)
    text = re.sub(r"(?i)\b((?:bearer|basic|token)\s+)[A-Za-z0-9._~+/=-]{8,}", r"\1" + REMOVED, text)
    text = re.sub(r"(\s-u\s+)\S+:\S+", r"\1" + REMOVED, text)
    text = NAMED.sub(lambda m: m.group(1) + REMOVED, text)
    text = FLAG.sub(lambda m: m.group(1) + REMOVED, text)
    # Web addresses: the scheme and host stay; the rest (paths, queries,
    # tokens in them, what you were reading) goes. user:pass@ goes too.
    text = re.sub(r"(?i)\b([a-z][a-z0-9+.-]*://)(?:[^/\s@]*@)?([^/\s?#:]+(?::\d+)?)[^\s\"'<>)]*",
                  lambda m: m.group(1) + m.group(2) + ("/…" if len(m.group(0)) > len(m.group(1) + m.group(2)) + 1 else ""),
                  text)
    text = re.sub(r"[A-Za-z0-9+/_=-]{32,}", lambda m: REMOVED if looks_random(m.group(0)) else m.group(0), text)
    if len(HOME) > 1:
        text = text.replace(HOME, "~")
    names = set()
    try:
        entry = pwd.getpwuid(os.getuid())
        names.add(entry.pw_name)
        names.update(w for w in re.split(r"[\s,]+", entry.pw_gecos) if w)
    except KeyError:
        pass
    names.add(os.environ.get("USER", ""))
    for n in sorted(names, key=len, reverse=True):
        if len(n) >= 3 and n.lower() not in COMMON:
            text = re.sub(r"(?i)(?<![A-Za-z0-9])" + re.escape(n) + r"(?![A-Za-z0-9])", "[user]", text)
    host = socket.gethostname().split(".")[0]
    if len(host) >= 3 and host.lower() not in COMMON:
        text = re.sub(r"(?i)(?<![A-Za-z0-9])" + re.escape(host) + r"(?![A-Za-z0-9-])", "[host]", text)
    return text


# --- Which lines go in ---------------------------------------------------------

OWN = re.compile(r"^(\+ |:: |!! |xx |vikix|Vikix|;|MESSAGE|stumpwm|StumpWM|swank|Swank|X Error|"
                 r"Unhandled|debugger invoked|Segmentation|Fatal|FATAL|picom|dunst|pipewire|wireplumber)")
PROBLEM = re.compile(r"^(!! |xx )|Vikix: error|error in [\w./-]+\.lisp|stage [\w-]+ failed|"
                     r"these stages failed|debugger invoked|Unhandled|Segmentation fault|X Error")


def own_lines(text):
    lines = tidy(text).split("\n")
    kept = [l for l in lines if OWN.match(l)]
    return kept, len([l for l in lines if l.strip()]) - len(kept)


def collapse(lines):
    """Runs of the same line become one, with a count."""
    out, prev, n = [], None, 0
    for l in lines + [None]:
        if l == prev:
            n += 1
            continue
        if prev is not None:
            out.append(prev if n == 0 else f"{prev}   (and {n} more times)")
        prev, n = l, 0
    return out


def session(path, head=60, tail=200):
    kept, other = own_lines(read_text(path))
    kept = collapse(kept)
    if len(kept) > head + tail:
        kept = kept[:head] + [f"… ({len(kept) - head - tail} lines between) …"] + kept[-tail:]
    print("\n".join(kept) if kept else "(nothing of Vikix's)")
    print(f"({other} lines from other programs left out: browsers, the file manager and the like)")


def vikix_log(path, n):
    kept, other = own_lines(read_text(path))
    kept = collapse(kept)[-n:]
    print("\n".join(kept) if kept else "(nothing of Vikix's)")
    print(f"({other} lines from the programs it ran left out)")


def problems(paths):
    seen, out = set(), []
    for p in paths:
        kept, _ = own_lines(read_text(p))
        for l in kept:
            if PROBLEM.search(l) and l not in seen:
                seen.add(l)
                out.append(f"{os.path.basename(p)}: {l}")
    print("\n".join(out[-40:]) if out else "(nothing failed, as far as the logs say)")


def check(path):
    """Line numbers where something secret-looking is left."""
    values = known_values()
    bad = []
    for i, line in enumerate(read_text(path).split("\n"), 1):
        if SHAPE_RE.search(line) or "PRIVATE KEY" in line or any(v in line for v in values):
            bad.append(str(i))
    print(" ".join(bad))


if __name__ == "__main__":
    a = sys.argv[1:]
    if not a:
        sys.stdout.write(scrub(sys.stdin.buffer.read().decode("utf-8", errors="replace")))
    elif a[0] == "--session":
        session(a[1])
    elif a[0] == "--vikix-log":
        vikix_log(a[1], int(a[2]))
    elif a[0] == "--problems":
        problems(a[1:])
    elif a[0] == "--check":
        check(a[1])
    else:
        sys.exit(__doc__)
