#!/usr/bin/env python3
"""learn/outputs.py LESSON_DIR [--fill] — the evidence rule for vikix learn.

A lesson quotes what a command prints by putting, in lesson.md, a line
<!-- output: COMMAND --> right before a fenced block. This runs each
COMMAND in a copy of the lesson (after compiling example.c there, as the
lesson shows, when there is one) and compares what it prints with the
block. --fill writes what it printed into the block instead: how a lesson
is written; tests/learn.sh then checks it never drifts. Standard output
only: a command that wants its errors quoted says 2>&1.
"""
import os, re, shutil, subprocess, sys, tempfile

def main():
    src = sys.argv[1]
    fill = "--fill" in sys.argv[2:]
    with tempfile.TemporaryDirectory() as tmp:
        work = os.path.join(tmp, "lesson")
        shutil.copytree(src, work)
        if os.path.exists(os.path.join(work, "example.c")):
            subprocess.run(["cc", "-std=c17", "-Wall", "-Wextra", "-pedantic", "-g", "-o", "example", "example.c"],
                           cwd=work, check=True)
        path = os.path.join(src, "lesson.md")
        lines = open(path).read().split("\n")
        bad = seen = 0
        out = []
        i = 0
        while i < len(lines):
            line = lines[i]
            out.append(line)
            m = re.fullmatch(r"<!-- output: (.+) -->", line.strip())
            if not m:
                i += 1
                continue
            seen += 1
            if not lines[i + 1].startswith("```"):
                sys.exit(f"{path}:{i + 2}: no block after the marker")
            end = next(j for j in range(i + 2, len(lines)) if lines[j].startswith("```"))
            quoted = "\n".join(lines[i + 2:end])
            got = subprocess.run(["bash", "-c", m.group(1)], cwd=work, capture_output=True, text=True).stdout.rstrip("\n")
            if got != quoted:
                bad += 1
                if not fill:
                    print(f"  {m.group(1)}\n  quoted:\n{quoted}\n  now:\n{got}")
            out.append(lines[i + 1])
            out.extend(got.split("\n") if got else [])
            out.append(lines[end])
            i = end + 1
        if not seen:
            sys.exit(f"{path}: no quoted outputs at all")
        if fill:
            open(path, "w").write("\n".join(out))
            print(f"{os.path.basename(src)}: {seen} outputs, {bad} written")
            return
        sys.exit(1 if bad else 0)

main()
