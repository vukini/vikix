// vikix-office.js — the Vikix office's house rules for OpenCode: before an
// edit, a write or a shell command, `vikix agents touch --for opencode` is
// asked, with the same JSON Claude Code's hook gets. A refusal (off a desk,
// the project's own folder) throws, which stops the tool with the reason;
// a clash (another agent on the file) is refused once, and the same edit
// tried again within ten minutes goes through, the agent having told the
// user. A crossing is told to the agent in the thrown message's place: it
// is allowed, so nothing is thrown, and the context is written to stderr.
// vikix agents hooks opencode --install links this file into
// ~/.config/opencode/plugins/. Plugin API: tool.execute.before(input {tool,
// sessionID, callID}, output {args}) (@opencode-ai/plugin 1.x).
import { execFile } from "node:child_process";

const WATCHED = { edit: "Edit", write: "Write", bash: "Bash", multiedit: "MultiEdit", patch: "Edit" };

function touch(payload) {
  return new Promise((resolve) => {
    const child = execFile("vikix", ["agents", "touch", "--for", "opencode"], { timeout: 15000 },
      (error, stdout) => resolve({ error, stdout: stdout || "" }));
    child.stdin.on("error", () => {});
    child.stdin.end(JSON.stringify(payload));
  });
}

export const VikixOffice = async ({ directory }) => ({
  "tool.execute.before": async (input, output) => {
    const name = WATCHED[(input.tool || "").toLowerCase()];
    if (!name) return;
    const args = output.args || {};
    const payload = {
      session_id: input.sessionID,
      tool_name: name,
      tool_input: {
        file_path: args.filePath || args.file_path || args.path || undefined,
        command: args.command || undefined,
      },
      cwd: directory || process.cwd(),
    };
    const { error, stdout } = await touch(payload);
    if (error && error.code === "ENOENT") return;   // no vikix on PATH: nothing held, nothing broken
    let answer;
    try { answer = JSON.parse(stdout.trim().split("\n").pop() || "{}"); } catch { return; }
    const out = answer.hookSpecificOutput || {};
    if (out.permissionDecision === "deny" || out.permissionDecision === "ask") {
      throw new Error(out.permissionDecisionReason || "Vikix office: refused");
    }
    if (out.additionalContext) process.stderr.write(out.additionalContext + "\n");
  },
});

export default VikixOffice;
