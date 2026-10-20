# cloud-ask.sh — a cloud service that speaks OpenAI's API, for use=cloud.
#
# Sourced (bash) by bin/vikix-ask (Super+i) and bin/vikix-voice (Super+F10)
# for use=cloud in ~/.config/vikix/ai: any OpenAI-compatible address
# (cloud_url=, OpenRouter unless said), a key of yours by its name
# (cloud_key=, openrouter unless said: vikix ai key set openrouter), and
# the service's model (model=, openai/gpt-4o-mini unless said). The text
# goes to that service and whoever hosts the model behind it.
#
# The questions go through llm, as Claude's do, under the model id
# vikix-cloud: an entry Vikix keeps in llm's extra-openai-models.yaml
# (vikix_cloud_llm_entry writes it, the rest of the file untouched). llm
# takes the key for such a model from OPENAI_API_KEY, so each call gets the
# key in its environment and nowhere else: not on a command line, not in
# llm's own key file (vikix ai key set is the one place).

VIKIX_CLOUD_URL_DEFAULT=https://openrouter.ai/api/v1
VIKIX_CLOUD_MODEL_DEFAULT=openai/gpt-4o-mini
VIKIX_CLOUD_KEY_DEFAULT=openrouter
VIKIX_LLM_DIR=${LLM_USER_PATH:-$HOME/.config/io.datasette.llm}

# vikix_cloud_url [URL]: the address, without a trailing slash; "" when it
# isn't one (https, or http on this machine only).
vikix_cloud_url() {
  local url=${1:-}
  url=${url:-$VIKIX_CLOUD_URL_DEFAULT}; url=${url%/}
  case $url in
    https://*) ;;
    http://127.0.0.1*|http://localhost*|http://\[::1\]*) ;;
    *) return 1 ;;
  esac
  case $url in *[[:space:]\"\'\\]*) return 1 ;; esac
  printf '%s' "$url"
}

# vikix_cloud_host URL: what the notification names (openrouter.ai).
vikix_cloud_host() { local h=${1#*://}; h=${h%%/*}; printf '%s' "${h%%:*}"; }

# vikix_cloud_key_var [NAME]: the variable a key's name stands for, as
# vikix ai key set names them: openrouter is OPENROUTER_API_KEY, a name in
# capitals with _ is itself. "" when the name isn't one.
vikix_cloud_key_var() {
  local name=${1:-}
  name=${name:-$VIKIX_CLOUD_KEY_DEFAULT}
  case $name in
    huggingface) echo HF_TOKEN ;;
    github) echo GITHUB_TOKEN ;;
    [A-Z]*[A-Z0-9_]) case $name in *[!A-Z0-9_]*) return 1 ;; *) echo "$name" ;; esac ;;
    [a-z]*) case $name in *[!a-z0-9]*) return 1 ;; *) echo "${name^^}_API_KEY" ;; esac ;;
    *) return 1 ;;
  esac
}

# vikix_cloud_key_value NAME: the key, from the session or the file set
# since login; "" without one.
vikix_cloud_key_value() {
  local var
  var=$(vikix_cloud_key_var "$1") || return 1
  if [ -z "${!var:-}" ] && [ -r "$VIKIX_DIR/lib/secrets.sh" ]; then
    # shellcheck source=../lib/secrets.sh
    . "$VIKIX_DIR/lib/secrets.sh"
  fi
  printf '%s' "${!var:-}"
}

# vikix_cloud_llm_entry URL MODEL: llm's model vikix-cloud, as URL and
# MODEL say, in extra-openai-models.yaml; other entries there stay.
vikix_cloud_llm_entry() {
  mkdir -p "$VIKIX_LLM_DIR" 2>/dev/null || return 0
  python3 - "$VIKIX_LLM_DIR/extra-openai-models.yaml" "$1" "$2" <<'PY'
import os, sys
path, url, model = sys.argv[1:]
ours = ["- model_id: vikix-cloud", "  model_name: " + model, "  api_base: " + url,
        "  api_key_name: vikix-cloud", "  supports_tools: false"]
lines = open(path).read().split("\n") if os.path.exists(path) else []
start = next((i for i, l in enumerate(lines) if l.strip() == "- model_id: vikix-cloud"), None)
if start is not None:
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("- ")), len(lines))
    kept = [l for l in lines[end:] if l.strip()] if end < len(lines) else []
    lines = lines[:start] + ours + kept
else:
    lines = [l for l in lines if l.strip()] + ours
with open(path + ".tmp", "w") as f:
    f.write("\n".join(lines) + "\n")
os.replace(path + ".tmp", path)
PY
}
