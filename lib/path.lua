--- Path resolution for vfox-shiv hooks.
---
--- Loadable via `require("path")` — mise's vfox implementation sets
--- `package.path` to include the plugin's `lib/?.lua`. See
--- https://github.com/jdx/mise/blob/main/crates/vfox/src/plugin.rs
--- (search for `set_paths` / `lib/?.lua`).

local M = {}

--- Strip leading + trailing whitespace. Returns nil for nil, empty, or
--- whitespace-only inputs — so callers can use a simple truthy check.
---@param s string|nil
---@return string|nil
local function nonblank(s)
    if not s then return nil end
    local trimmed = s:gsub("^%s+", ""):gsub("%s+$", "")
    if trimmed == "" then return nil end
    return trimmed
end

--- Get the path to the plugin's shiv clone.
---
--- Resolution order:
---   1. VFOX_SHIV_PATH — explicit override (used by tests and advanced users).
---   2. MISE_DATA_DIR — when mise runs with a custom data dir (CI isolation,
---      sandboxed test runs, parallel jobs), the shiv clone and its bootstrap
---      lock live under that dir. This keeps the lock scoped to the mise
---      session so a hung session doesn't block unrelated ones on the same
---      machine.
---   3. $HOME/.local/share/mise/shiv-backend/shiv — the default.
---
--- Empty, unset, or whitespace-only values for VFOX_SHIV_PATH and
--- MISE_DATA_DIR are treated as "not set" and fall through to the next
--- tier. This is a small behavior change from the pre-#7 resolver, which
--- relied on Lua's truthy-empty-string semantics and would return `""`
--- for `VFOX_SHIV_PATH=""`.
---
--- See KnickKnackLabs/vfox-shiv#7 for the cross-session hang this prevents.
---
--- @return string
function M.get_shiv_path()
    local override = nonblank(os.getenv("VFOX_SHIV_PATH"))
    if override then
        return override
    end
    local data_dir = nonblank(os.getenv("MISE_DATA_DIR"))
    if data_dir then
        return data_dir .. "/shiv-backend/shiv"
    end
    local home = os.getenv("HOME") or ""
    return home .. "/.local/share/mise/shiv-backend/shiv"
end

return M
