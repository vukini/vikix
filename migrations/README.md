# Migrations

A migration is a one-off change for machines that are **already** running Vikix.

A fresh install gets the change from the install stages themselves. A machine
installed last month doesn't re-run those stages, so it needs a migration
to catch up.

## The rules

- **Name.** Each migration is a file named after the moment it was written, in Unix time:

  ```
  date +%s
  ```

  For example `1790336194.sh`. A plain sort is then time order.
- **When it runs.** `vikix update` runs every migration not yet applied, oldest first.
- **How it's recorded.** A successful migration is recorded as an empty file in
  `~/.local/state/vikix/migrations/`. It never runs again.
- **If one fails.** The update stops there, and nothing after it runs.
- **Fresh installs.** The last install stage marks every existing migration as applied. Re-running the installer on a machine that already has Vikix runs the new ones instead, so none is skipped.
- **Write them to be safe twice.** Check before changing, the same way the install stages do.
- **Explain the why.** Start with a comment saying why the change is needed, not only what it does.
