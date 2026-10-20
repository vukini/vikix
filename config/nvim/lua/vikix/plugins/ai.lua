-- AI in Neovim: CodeCompanion, on the model Super+i uses (`vikix ai use`:
-- Claude, a model on this laptop, or a cloud service that speaks OpenAI's
-- API, OpenRouter unless ~/.config/vikix/ai says another), and your agent (Claude Code, Codex,
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

-- The cloud service (use=cloud): its address, its key by the name `vikix ai
-- key set` gave it (lib/cloud-ask.sh's rules), and the model.
local cloud_url_default, cloud_model_default = "https://openrouter.ai/api/v1", "openai/gpt-4o-mini"
local function cloud_url() return (setting("ai", "cloud_url") or cloud_url_default):gsub("/$", "") end
local function cloud_host() return cloud_url():gsub("^%w+://", ""):gsub("[/:].*$", "") end
local function cloud_key_name() return setting("ai", "cloud_key") or "openrouter" end
local function cloud_key_var()
  local name = cloud_key_name()
  if name == "huggingface" then return "HF_TOKEN" elseif name == "github" then return "GITHUB_TOKEN" end
  if name:match "^[A-Z][A-Z0-9_]*$" then return name end
  return name:upper() .. "_API_KEY"
end
local function cloud_key()
  local var = cloud_key_var()
  local key = vim.env[var]
  if key and key ~= "" then return key end
  local f = io.open(config .. "/secrets/" .. var)
  if not f then return nil end
  key = vim.trim(f:read "*a")
  f:close()
  return key ~= "" and key or nil
end

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
  if use() == "cloud" then
    if cloud_key() then return true end
    say("The cloud service needs its key: in a terminal, vikix ai key set " .. cloud_key_name() .. ".\nOr a model on this laptop: vikix ai use local")
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

-- Who answers a chat, in its window's bar before you type: the two chats
-- look alike, and one may be paid (Claude), the other free (local).
local function where(adapter)
  if adapter.type == "acp" then return "your agent, started by vikix agent" end
  if adapter.name == "cloud" then return "sent to " .. cloud_host() end
  return adapter.name == "ollama" and "on this laptop" or "sent to " .. (adapter.formatted_name or adapter.name)
end
local function chat_bar(bufnr, model)
  local ok, chat = pcall(function() return require("codecompanion").buf_get_chat(bufnr) end)
  if not ok or not chat or not chat.adapter then return end
  local a = chat.adapter
  model = model or (chat.settings and chat.settings.model)
  local text = (a.formatted_name or a.name) .. (model and model ~= "default" and ("  " .. model) or "") .. "  (" .. where(a) .. ")"
  vim.b[bufnr].vikix_chat_bar = text:gsub("%%", "%%%%")
  for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do vim.wo[win].winbar = vim.b[bufnr].vikix_chat_bar end
end
local group = vim.api.nvim_create_augroup("vikix_chat_bar", { clear = true })
vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = { "CodeCompanionChatCreated", "CodeCompanionChatOpened", "CodeCompanionChatAdapter", "CodeCompanionChatModel" },
  callback = function(ev)
    local d = ev.data or {}
    if d.bufnr then vim.schedule(function() chat_bar(d.bufnr, type(d.model) == "string" and d.model or nil) end) end
  end,
})
-- auto_insert (below) acts when you come back to the agent's terminal;
-- this, when it first opens.
vim.api.nvim_create_autocmd("User", {
  group = group,
  pattern = "CodeCompanionCLIOpened",
  callback = function(ev)
    local bufnr = (ev.data or {}).bufnr
    vim.schedule(function()
      if bufnr and vim.api.nvim_get_current_buf() == bufnr then vim.cmd.startinsert() end
    end)
  end,
})
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = group,
  callback = function(ev)
    if vim.b[ev.buf].vikix_chat_bar then vim.wo.winbar = vim.b[ev.buf].vikix_chat_bar end
  end,
})

return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.ai.codecompanion-nvim" },
  {
    "olimorris/codecompanion.nvim",
    opts = function(_, opts)
      -- Super+i's model= when set; else each adapter's own (Claude's is
      -- claude-sonnet-5, as Super+i's; Ollama's the first you have; the
      -- cloud's openai/gpt-4o-mini).
      local http = ({ claude = "anthropic", cloud = "cloud" })[use()] or "ollama"
      local chat = model() and { name = http, model = model() } or http
      if http == "cloud" and not model() then chat = { name = "cloud", model = cloud_model_default } end
      return vim.tbl_deep_extend("force", opts, {
        adapters = {
          http = {
            anthropic = function()
              return require("codecompanion.adapters").extend("anthropic", { env = { api_key = anthropic_key } })
            end,
            ollama = function()
              return require("codecompanion.adapters").extend("ollama", { env = { url = ollama } })
            end,
            -- The cloud service: OpenAI's API at its address, your key by name.
            cloud = function()
              return require("codecompanion.adapters").extend("openai_compatible", {
                name = "cloud",
                formatted_name = "Cloud",
                env = { url = cloud_url(), api_key = cloud_key, chat_url = "/chat/completions" },
                schema = { model = { default = model() or cloud_model_default } },
              })
            end,
          },
          acp = {
            claude_code = through_vikix("claude_code", "claude", { handlers = { auth = own_login } }),
            codex = through_vikix("codex", "codex", { defaults = { auth_method = "chat-gpt" } }),
            gemini_cli = through_vikix("gemini_cli", "gemini"),
            opencode = through_vikix("opencode", "opencode"),
          },
        },
        -- Your agent's terminal (Space A t) is ready to type, without
        -- line numbers down its side.
        display = { cli = { window = { opts = { number = false, relativenumber = false, signcolumn = "no" } } } },
        interactions = {
          chat = { adapter = chat },
          inline = { adapter = chat },
          cmd = { adapter = chat },
          background = { adapter = chat },
          -- In a terminal: `vikix agent` is yours (Super+a's); the others by name.
          cli = {
            opts = { auto_insert = true },
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
          desc = "Chat (vikix ai use: Claude, local or the cloud)",
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
