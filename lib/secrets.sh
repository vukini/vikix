# secrets.sh — the API keys `vikix ai key set` keeps, as environment variables.
#
# Sourced (plain sh, so bash and dash alike) by bin/vikix-session, for the
# desktop and everything it starts, and by vikix.bash, for every shell.
# Each file in ~/.config/vikix/secrets/ is one key: its name is the
# variable (ANTHROPIC_API_KEY), its contents the value. Nothing is printed.
#
# That folder is never in a snapshot of your files (bin/vikix excludes it
# explicitly) and is only yours to read (700, its files 600).
#
# Only names a key has are exported (..._API_KEY, _KEY, _TOKEN, _SECRET),
# from real files of yours: so a file dropped there can't set PATH,
# LD_PRELOAD or ANTHROPIC_BASE_URL (sending your key elsewhere), and a link
# can't make it read a file from somewhere else.

vikix_export_secrets() {
  # Not in an AI agent's shells: vikix agent starts it without the keys,
  # and a bash it opens would read them back here.
  if [ -n "${VIKIX_AGENT:-}" ] && [ "${VIKIX_AGENT_API_KEY:-}" != 1 ]; then return 0; fi
  _vikix_dir="${XDG_CONFIG_HOME:-$HOME/.config}/vikix/secrets"
  if [ ! -d "$_vikix_dir" ] || [ -L "$_vikix_dir" ] || [ ! -O "$_vikix_dir" ]; then
    unset _vikix_dir; return 0
  fi
  for _vikix_f in "$_vikix_dir"/*; do
    [ -f "$_vikix_f" ] && [ ! -L "$_vikix_f" ] && [ -O "$_vikix_f" ] || continue
    _vikix_n=${_vikix_f##*/}
    case $_vikix_n in
      [!A-Z]*|*[!A-Z0-9_]*) continue ;;
      *_API_KEY|*_KEY|*_TOKEN|*_SECRET) ;;
      *) continue ;;
    esac
    export "$_vikix_n=$(cat "$_vikix_f")"
  done
  unset _vikix_dir _vikix_f _vikix_n
}
vikix_export_secrets
