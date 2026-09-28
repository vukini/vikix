# secrets.sh — the API keys `vikix ai key set` keeps, as environment variables.
#
# Sourced (plain sh, so bash and dash alike) by bin/vikix-session, for the
# desktop and everything it starts, and by vikix.bash, for every shell.
# Each file in ~/.config/vikix/secrets/ is one key: its name is the
# variable (ANTHROPIC_API_KEY), its contents the value. Nothing is printed.
#
# That folder is never in a snapshot of your files (bin/vikix excludes it
# explicitly) and is only yours to read (700, its files 600).

vikix_export_secrets() {
  _vikix_dir="${XDG_CONFIG_HOME:-$HOME/.config}/vikix/secrets"
  [ -d "$_vikix_dir" ] || { unset _vikix_dir; return 0; }
  for _vikix_f in "$_vikix_dir"/*; do
    [ -f "$_vikix_f" ] || continue
    _vikix_n=${_vikix_f##*/}
    # Only names a variable can have; anything else in the folder is skipped.
    case $_vikix_n in
      ''|[0-9]*|*[!A-Za-z0-9_]*) continue ;;
    esac
    export "$_vikix_n=$(cat "$_vikix_f")"
  done
  unset _vikix_dir _vikix_f _vikix_n
}
vikix_export_secrets
