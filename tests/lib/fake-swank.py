#!/usr/bin/env python3
"""A stand-in for StumpWM's Swank, for tests/cuis.sh: VikixDesktop in the
Cuis image reads the desktop through it.

  fake-swank.py PORT SECRET DESKTOP.json LOG

Listens on 127.0.0.1:PORT. A client's first packet must be SECRET (as
Swank with ~/.slime-secret asks), or the connection is closed. Then each
(:emacs-rex ...) packet is answered as Swank answers vikix-eval-for-agent:
one that names vikix-desktop-json gets DESKTOP.json's text printed as a
Lisp string after "=> " and the status :OK; the acts VikixDesktop sends
(move-window-to-group, focus-all, switch-to-group, each in the form
VikixSwank writes, with the workspace names and the window number in it)
change DESKTOP.json as StumpWM would change the desktop and answer the
word the form answers (moved, focused, switched, or why not), so the next
poll shows the change; any other form gets an error. A noise message
(:indentation-update) is sent before each answer, as Swank may. Every
request is appended to LOG, a line each, so a test can count the polls.
Packets are six hex digits of length, then UTF-8 text.
"""
import json
import re
import socket
import sys
import threading

port, secret, desktop_file, log_file = int(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]


def lisp_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def send(conn, text):
    data = text.encode("utf-8")
    conn.sendall(("%06x" % len(data)).encode() + data)


def receive(conn):
    def exactly(n):
        data = b""
        while len(data) < n:
            chunk = conn.recv(n - len(data))
            if not chunk:
                raise ConnectionError("closed")
            data += chunk
        return data
    return exactly(int(exactly(6), 16)).decode("utf-8")


def act(request):
    """The desktop changed as StumpWM would change it for an act's form, and
    the word the form answers."""
    # The form is a Lisp string inside a Lisp string by the time it is here,
    # so a quote in it wears several backslashes.
    names = re.findall(r'\(find-group \(current-screen\) \\+"([^"\\]*)\\+"\)', request)
    number = re.search(r"\(find (\d+) \(group-windows", request)
    with open(desktop_file) as f:
        desktop = json.load(f)
    by_name = {w["name"]: w for w in desktop["workspaces"]}
    if "move-window-to-group" in request:
        src, dst = (by_name.get(n) for n in names[:2])
        if dst is None:
            return "no such workspace"
        win = next((w for w in (src or {}).get("windows", []) if w["number"] == int(number.group(1))), None)
        if win is None:
            return "no such window"
        src["windows"].remove(win)
        dst["windows"].append(win)
        word = "moved"
    elif "focus-all" in request:
        ws = by_name.get(names[0]) if names else None
        if ws is None:
            return "no such workspace"
        win = next((w for w in ws["windows"] if w["number"] == int(number.group(1))), None)
        if win is None:
            return "no such window"
        for w in desktop["workspaces"]:
            w["current"] = w is ws
            for x in w["windows"]:
                x["focused"] = x is win
        word = "focused"
    else:
        ws = by_name.get(names[0]) if names else None
        if ws is None:
            return "no such workspace"
        for w in desktop["workspaces"]:
            w["current"] = w is ws
        word = "switched"
    with open(desktop_file, "w") as f:
        json.dump(desktop, f)
    return word


def serve(conn):
    try:
        if receive(conn) != secret:
            return
        while True:
            request = receive(conn)
            with open(log_file, "a") as f:
                f.write(request.replace("\n", " ") + "\n")
            rid = request.rsplit(" ", 1)[-1].rstrip(")")
            send(conn, "(:indentation-update ())")
            if "vikix-desktop-json" in request:
                with open(desktop_file) as f:
                    desktop = json.dumps(json.load(f))
                printed = "=> " + lisp_string(desktop) + "\n"
                send(conn, "(:return (:ok (%s \":OK\")) %s)" % (lisp_string(printed), rid))
            elif any(x in request for x in ("move-window-to-group", "focus-all", "switch-to-group")):
                printed = "=> " + lisp_string(act(request)) + "\n"
                send(conn, "(:return (:ok (%s \":OK\")) %s)" % (lisp_string(printed), rid))
            else:
                send(conn, "(:return (:ok (%s \":ERROR\")) %s)" % (lisp_string("error: not this form\n"), rid))
    except (ConnectionError, OSError):
        pass
    finally:
        conn.close()


server = socket.socket()
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(("127.0.0.1", port))
server.listen(4)
while True:
    conn, _ = server.accept()
    threading.Thread(target=serve, args=(conn,), daemon=True).start()
