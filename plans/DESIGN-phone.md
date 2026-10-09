# The Office on Telegram

Reach the Office from a phone: give an agent a task, answer whatever is holding it up, pause it, let it continue, or close it while keeping its work.

Drafted 2026-10-08 from Vid's discussion of [OpenClaw](DESIGN-openclaw.md). This replaces that proposal's phone gateway direction for TODO 13. Telegram is the chosen first channel. OpenClaw and Hermes are not dependencies: the existing agents do the thinking, and a small Vikix bridge carries questions, answers and controls. This is a design, not an installed feature.

## What Vid has decided

- Phone access is the reason for the work. Adding another terminal agent is outside this design.
- Agents must push a question to the phone when waiting for its answer prevents progress. If useful independent work remains, they should continue it.
- Vid can answer questions and permission requests, assign work, pause, resume and close agents from the phone.
- Closing an agent preserves its desk, branch, files and available conversation history.
- Telegram is acceptable as the first interface. The question and control mechanisms belong to Vikix so another interface can use them later.

The detailed defaults below are proposed implementation choices. In particular, the first fully supported provider is selected by the capability experiment, not assumed from a provider's name.

## Using it

One private conversation with the bot shows the Office. Each card names the machine, project, desk and task; similar topic names on different projects never identify a target by themselves.

| Action | Result |
|---|---|
| Open Office | Working, waiting and paused desks, with their latest handoffs |
| Open Needs you | Unanswered questions and approvals, each with its own reply target |
| Reply to a question | The answer reaches the originating request; progress resumes unless explicitly paused |
| Approve or deny | Decide the particular pending action shown on the card |
| Pause | Request a hold and show whether it has actually taken effect |
| Continue | Release a pause, or resume the saved session when the old process ended |
| Close agent | End that agent, retaining the desk and work |
| Give a task | Choose an existing desk, or a project and topic for a new desk, then type the task |
| Show result | Read the handoff and check results, including failures and checks not run |

Example:

> **laptop / vikix / office-ui**
> Task: finish the new Office layout
> **Waiting for your answer:** should archived desks appear on this screen?
> [Show context] [Pause] [Close agent]
> Reply to this message to answer.

Vid replies, “Keep them on a separate screen.” The card first says that the answer was received, then that the agent accepted it. It says resumed only when the provider confirms progress. An answer received while explicitly paused is retained and shown as “answered; still paused.”

Task text goes to the chosen agent unchanged. Buttons and simple commands identify the destination and operation; the bridge does not need a model to interpret them. An unaddressed message opens a desk choice instead of guessing. A task for a desk already working is an instruction to that worker, with delivery status; it never silently replaces the recorded task or starts a second worker.

Closing uses the Office's existing confirmation and process identity checks. It never calls the similarly named command that removes a desk's worktree. A new task uses an explicit provider and all required launcher choices, so it cannot leave an unseen desktop picker waiting for input.

## When the phone makes a noise

A new blocking question or permission request is pushed immediately. The card contains the question, enough context to decide, and the affected task. A status of “waiting” without a captured question still produces an honest “needs attention; question unavailable” alert.

Nonblocking questions remain available in the Office while the agent continues useful work. If such a question later becomes blocking, that transition triggers the push. A test queue, release queue or known automatic retry is waiting for the machine, not for Vid; it does not become a question notification.

Proposed defaults: send one completion or failure report per task, keep ordinary progress quiet, and do not repeat an unanswered question periodically. Needs you always retains unresolved questions. Network retries and repeated provider events must not create a stream of identical alerts.

No bridge can promise that the phone sounds: Telegram delivery, the phone's network and notification settings are outside Vikix. Track “sent to Telegram” separately from “answered”; do not claim the person saw a notification.

## What exists and what is missing

The [Workers design](DESIGN-workers.md) records the pieces already built. The current command headers and Office backend are the implementation references.

| Existing piece | How this design uses it |
|---|---|
| `vikix agents office --json` | Desk inventory, activity and handoffs |
| `desk --task` | Start a worker with the task as its first prompt, subject to provider support |
| `tell` and the inbox | Instructions delivered at a subsequent tool call for supported hooks |
| `pause` and `go` | Cooperative hold and release; explicit hard pause also exists |
| `dismiss` and Office Close agent | End an agent while preserving its desk |
| Handoff, tester and status notifications | Task result and check evidence |

The inbox alone is insufficient. An agent sitting at a question or permission prompt may make no next tool call. Some providers only read inbox notes through handoff or resume. Likewise, the existing cooperative pause has a ten-minute hook wait limit; releasing its flag after the turn ended may not restart work.

The new work is a durable question queue, a provider interface that can deliver an answer while the agent is waiting, truthful action acknowledgements, and the Telegram bridge. Native approvals are distinct from conversational questions. Text saying “yes” in an inbox is not proof that a provider's permission request was approved.

## Architecture

```text
phone / Telegram
       |
       | messages, replies, buttons
       v
Vikix Telegram bridge
       |
       | authenticated, named operations
       v
Office questions and controls
       |                         |
       | provider adapters       | existing desk and worker commands
       v                         v
waiting agent <------------> task, handoff, checks and lifecycle
```

The bridge is a transport adapter. The Office owns identities, pending questions, control state and results. It exposes a narrow local interface for list, ask, answer, assign, pause, continue and close. The desktop UI and a later MCP interface can use the same operations.

The bridge invokes fixed operations with structured arguments. It offers no arbitrary shell, Lisp evaluation, generic desktop command execution or model-based command routing. A task still grants the selected worker the normal scope of that task, under its usual house rules and provider permissions.

## Reaching an agent that is waiting

Each provider adapter declares its actual capabilities: capture a question, answer it, capture and decide a permission request, deliver an instruction at an idle prompt, interrupt a turn, and resume a conversation. The UI shows unavailable operations rather than pretending all agents behave alike.

The first experiment must prove an entire round trip with one real provider. Inspect its supported hooks, SDK or session protocol. Prefer an existing structured interface; if supporting one requires a supervised launcher, keep the session visible in the Office and explain that requirement. Do not type into an arbitrary desktop window, scrape a terminal to infer permission, or replay keystrokes after reconnecting.

A Vikix question tool can cover ordinary questions for agents that can call it. Its wait must fit the provider's tool timeout; otherwise it needs a durable suspend and resume mechanism. It does not automatically intercept native questions or approval dialogs. Both paths need explicit testing.

The goal is every blocking question from the agents Vid uses. A first provider is a milestone, not completion of that goal. Until an adapter supports a prompt type, the notification must say that it needs local attention. Do not silently approve, discard the question, or claim the agent resumed.

## Questions and answers as records

Proposed storage is an Office SQLite database under `$XDG_STATE_HOME/vikix/office/`, with private directory and file permissions. Question state is independent of Telegram message state.

A question records its ID, machine and desk IDs, provider session and request IDs, kind (question or permission), text and choices, blocking flag, creation time, optional expiry, and state. A permission also records the exact operation, arguments and scope being requested. Large details can be shown separately, but approval must not hide part of the action.

An answer records the authenticated sender, originating Telegram update or local action, selected choice or text, time and delivery acknowledgement. The lifecycle distinguishes pending, answer recorded, delivered, resolved, cancelled and expired. A delivery failure remains visible and retryable. The adapter may report that no active request remains; that is not success.

Replying to a Telegram card uses a persisted mapping to that question. Callback buttons carry an opaque action identifier, resolved locally. Every write rechecks sender, question state and session identity. Resolving locally retires the phone card; closing or replacing the session cancels obsolete prompts. A late reply explains why it no longer applies. The first valid answer wins under a transaction; conflicting later answers are never silently substituted.

## Pause and close semantics

Pause means “stop at the next supported safe point.” Show pause requested until the adapter acknowledges the hold. Commands already running, tests and child processes may continue; show that limitation when relevant. An explicit hard stop is a separate advanced control using the existing process identity safeguards, never the automatic fallback.

The paused intent survives bridge restarts and tool wait timeouts. If the provider ends its turn while held, Continue may need to restart the saved conversation. Show the distinction and never create a second live session for the same worker.

Closing first attempts the existing dismissal path and reports the outcome. A process that has not exited is “close requested,” not closed. Confirm the process start identity again before acting. Once closed, invalidate its pending controls and questions; preserve the handoff, worktree and files.

## Telegram and setup

Use the [Telegram Bot API](https://core.telegram.org/bots/api) directly. Long polling receives updates over outbound HTTPS, so the initial design needs no public listener or Tailscale connection. Replies and callback buttons support the question cards. Telegram keeps undelivered updates for at most 24 hours; it cannot serve as the durable Office queue. Respect API rate limits and retry delays.

The user creates a bot through [BotFather](https://core.telegram.org/bots/features#botfather) and stores its token through a local secret-entry flow. The token must stay outside snapshot history, command arguments and logs; HTTP diagnostics must redact token-bearing URLs.

Pair locally with a short-lived challenge: send it from the intended private chat, then approve the displayed account on the desktop. Bind both the numeric user ID and private chat ID. Merely messaging the bot never authorizes someone, and account names are not identity checks. Every reply and button press checks the binding. Revocation is available locally even when Telegram is unavailable.

Setup explains that task and question text goes through Telegram. Send the relevant context, not whole transcripts or automatic file attachments. Private document restrictions still apply. A permission that requires secret entry remains local; the bot never asks for passwords or API keys in chat.

Proposed command surface: `vikix phone setup|on|off|status|unpair`. These commands do not exist yet. Status shows pairing, polling health, last successful contact, queued notifications and delivery failures without secrets.

## Restart and offline behavior

Start with one machine and one bridge process, supervised in the user session using Vikix's Void-compatible lifecycle. No systemd dependency. A lock prevents two pollers from consuming updates for one bot. Off stops the owned bridge cleanly and leaves its queue intact.

Persist incoming updates before advancing the polling offset. Use a durable outbox for notifications and an action journal for controls. Deduplicate Telegram update IDs and action IDs. A crash after an action but before acknowledgement requires reconciliation against the actual desk or session, not blind repetition. In particular, repeating Start must not create a second desk. If delivery to a provider has an uncertain outcome, show uncertainty until its request state can be checked.

Telegram sends can have an ambiguous outcome after a network failure. Duplicate cards may occasionally be unavoidable; they still map to one question and cannot apply an action twice.

While the host is suspended or offline, it cannot act on messages or deliver new questions. On reconnection, reconcile sessions first, retire obsolete prompts, and resend only still-relevant notifications. An old queued close or approval must not execute against a changed session; stale controls require a fresh action. Messages outside Telegram's retention window may be lost, so the Office remains authoritative.

The later always-on machine can host its own workers and bridge. Remote laptop control and multiple machines belong with [the machines design](DESIGN-machines.md); they are not prerequisites for this first version.

## Build order and acceptance

1. **Prove question delivery and answering.** With one provider in an isolated environment, trigger an ordinary blocking question and a native permission request. Capture their identities, answer through a local test interface while the agent waits, and observe continuation. Also prove idle task delivery. Record unsupported prompt types before choosing the first provider.
2. **Build Office records and controls.** Add the durable question lifecycle, acknowledgement state, capability reporting and reconciliation. Exercise pause timeout, resume and close with stand-in providers before attaching Telegram.
3. **Connect Telegram.** Pair one user, show Office and Needs you, push a blocking question, accept its reply or approval, and update the card. Add task assignment, pause, continue and close using the same local operations.
4. **Complete the worker loop.** Start a task from the phone, receive and answer a question, pause and continue it, then receive its handoff and check results. Close a separate live worker and verify its files and desk remain.
5. **Extend provider coverage and document setup.** Publish the tested capability table. Add further adapters without changing the Telegram protocol.

Tests run through `tests/run.sh` in isolated homes with a fake Telegram service and stand-in provider sessions. Cover an unauthorized sender; two simultaneous desks; duplicate replies; local and phone answers racing; stale approvals; session replacement and reused PIDs; restart between action and acknowledgement; an offline host; rate limiting; a pause that outlives the hook wait; and closing with uncommitted work preserved.

A real phone check then proves notification, text reply, approval and denial, task delivery, pause, continue, close and completion for each advertised provider. No live messages or credentials are needed for the automated suite. Passing the suite alone does not establish phone notification delivery or provider compatibility.

## Decisions left for implementation

- Which structured interface supports each installed provider, including its native permission prompts and idle sessions?
- How does each provider acknowledge a safe pause, and which child operations continue?
- Can existing desk launch and resume paths be invoked with every choice explicit and no hidden interactive picker?
- What retention period should the local question and action history use?

These are capability and implementation decisions. The product direction is settled: Telegram reaches the existing Office, blocking questions reach Vid promptly, and his answers go back to the exact waiting agent.
