-- AI in Neovim: CodeCompanion, on the model Super+i uses (`vikix ai use`:
-- Claude, or a model on this laptop), and your agent (Claude Code, Codex,
-- Gemini CLI, OpenCode) in a chat, over ACP, or in a terminal. Agents start
-- through `vikix agent`, as Super+a's do: the guide, no API keys, and a
-- snapshot first, so `vikix changes` shows what they did.
--
-- Keys, under <Leader>A (AstroCommunity's): c chat, q ask about the
-- selection or the file, p actions, a add the selection to the chat;
-- g a chat with your agent, t your agent in a terminal. Nothing starts or
-- connects until a key is pressed, and each says what's missing.

local home = vim.env.HOME
local config = (vim.env.XDG_CONFIG_HOME or home .. "/.config") .. "/vikix"
local bin = home .. "/.local/bin"
local ollama = "http://127.0.0.1:11434"

-- A setting from one of Vikix's files (ai: use=, model=; agent: agent=).
local function setting(file, key)
  local f = io.open(config .. "/" .. file)
  if not f then return nil end
  local value
  for line in f:lines() do
    local v = line:gsub("#.*", ""):match("^%s*" .. key .. "%s*=%s*(.-)%s*$")
    if v and v ~= "" then value = v end
  end
  f:close()
  return value
end

-- The Anthropic key: from the session, or from `vikix ai key set` since
-- (a key set after login isn't in this Neovim's environment yet).
local function anthropic_key()
  local key = vim.env.ANTHROPIC_API_KEY
  if key and key ~= "" then return key end
  local f = io.open(config .. "/secrets/ANTHROPIC_API_KEY")
  if not f then return nil end
  key = vim.trim(f:read "*a")
  f:close()
  return key ~= "" and key or nil
end

local function use() return (setting("ai", "use") or "local"):lower() end
local function model() return setting("ai", "model") end

-- Your agent (Super+a's), and its CodeCompanion adapter.
local agents = { claude = "claude_code", codex = "codex", gemini = "gemini_cli", opencode = "opencode" }
local function agent() return setting("agent", "agent") or "claude" end

local function say(msg, level) vim.notify(msg, level or vim.log.levels.WARN, { title = "Vikix AI" }) end

-- Is the chat's model there? If not, say what to do, and don't start.
local function model_ready()
  if use() == "claude" then
    if anthropic_key() then return true end
    say "Claude needs your Anthropic key: in a terminal, vikix ai key set anthropic.\nOr a model on this laptop: vikix ai use local"
    return false
  end
  local ok = vim.system({ "curl", "-fsS", "--max-time", "1", ollama .. "/api/version" }):wait().code == 0
  if not ok then say "Local AI isn't running: in a terminal, vikix ai setup.\nOr Claude: vikix ai use claude" end
  return ok
end

local function agent_ready(name)
  if vim.fn.executable "vikix" == 0 then
    say "vikix isn't on PATH: agents start through it"
    return false
  end
  if not agents[name] then
    say(name .. " doesn't speak ACP: <Leader>At runs it in a terminal")
    return false
  end
  local exe = ({ claude = "claude-agent-acp", codex = "codex-acp" })[name] or name
  if vim.fn.executable(bin .. "/" .. exe) == 0 and vim.fn.executable(exe) == 0 then
    say(name .. (exe == name and " isn't installed" or "'s ACP adapter isn't installed") .. ": in a terminal, vikix agent --install " .. name)
    return false
  end
  return true
end

-- An ACP adapter that starts the agent through Vikix. Only that command:
-- the presets' others (--yolo) would skip it.
local function through_vikix(preset, name, changes)
  return function()
    local a = vim.deepcopy(require("codecompanion.adapters.acp." .. preset))
    a.commands = { default = { "vikix", "agent", "--acp", name } }
    return require("codecompanion.adapters").extend(vim.tbl_deep_extend("force", a, changes or {}))
  end
end
-- Each signs in its own way (its login, as in a terminal): no keys given.
local own_login = function() return true end

return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.ai.codecompanion-nvim" },
  {
    "olimorris/codecompanion.nvim",
    opts = function(_, opts)
      -- Super+i's model= when set; else each adapter's own (Claude's is
      -- claude-sonnet-5, as Super+i's; Ollama's the first you have).
      local http = use() == "claude" and "anthropic" or "ollama"
      local chat = model() and { name = http, model = model() } or http
      return vim.tbl_deep_extend("force", opts, {
        adapters = {
          http = {
            anthropic = function()
              return require("codecompanion.adapters").extend("anthropic", { env = { api_key = anthropic_key } })
            end,
            ollama = function()
              return require("codecompanion.adapters").extend("ollama", { env = { url = ollama } })
            end,
          },
          acp = {
            claude_code = through_vikix("claude_code", "claude", { handlers = { auth = own_login } }),
            codex = through_vikix("codex", "codex", { defaults = { auth_method = "chat-gpt" } }),
            gemini_cli = through_vikix("gemini_cli", "gemini"),
            opencode = through_vikix("opencode", "opencode"),
          },
        },
        interactions = {
          chat = { adapter = chat },
          inline = { adapter = chat },
          cmd = { adapter = chat },
          background = { adapter = chat },
          -- In a terminal: `vikix agent` is yours (Super+a's); the others by name.
          cli = {
            agent = "vikix",
            agents = {
              vikix = { cmd = "vikix", args = { "agent" }, description = "Your agent (vikix agent)" },
              claude = { cmd = "vikix", args = { "agent", "--use", "claude" }, description = "Claude Code" },
              codex = { cmd = "vikix", args = { "agent", "--use", "codex" }, description = "Codex" },
              gemini = { cmd = "vikix", args = { "agent", "--use", "gemini" }, description = "Gemini CLI" },
              opencode = { cmd = "vikix", args = { "agent", "--use", "opencode" }, description = "OpenCode" },
              aider = { cmd = "vikix", args = { "agent", "--use", "aider" }, description = "Aider" },
            },
          },
        },
      })
    end,
  },
  {
    "AstroNvim/astrocore",
    opts = function(_, opts)
      local maps = opts.mappings
      local p = "<Leader>A"
      for _, mode in ipairs { "n", "v" } do
        maps[mode][p .. "c"] = {
          function() if model_ready() then vim.cmd "CodeCompanionChat Toggle" end end,
          desc = "Chat (vikix ai use: Claude or local)",
        }
        maps[mode][p .. "q"] = {
          function() if model_ready() then vim.cmd "CodeCompanion" end end,
          desc = "Ask about the code",
        }
      end
      maps.n[p .. "g"] = {
        function()
          local name = agent()
          if agent_ready(name) then vim.cmd("CodeCompanionChat adapter=" .. agents[name]) end
        end,
        desc = "Chat with your agent (vikix agent)",
      }
      maps.n[p .. "t"] = {
        function()
          if vim.fn.executable "vikix" == 0 then return say "vikix isn't on PATH: agents start through it" end
          vim.cmd "CodeCompanionCLI"
        end,
        desc = "Your agent in a terminal",
      }
    end,
  },
}
