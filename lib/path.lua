--- Path resolution for vfox-shiv hooks.
---
--- Loadable via `require("path")` — mise's vfox implementation sets
--- `package.path` to include the plugin's `lib/?.lua`. See
--- https://github.com/jdx/mise/blob/main/crates/vfox/src/plugin.rs
--- (search for `set_paths` / `lib/?.lua`).

local M = {}

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
--- See KnickKnackLabs/vfox-shiv#7 for the cross-session hang this prevents.
---
--- @return string
function M.get_shiv_path()
    local override = os.getenv("VFOX_SHIV_PATH")
    if override and override ~= "" then
        return override
    end
    local data_dir = os.getenv("MISE_DATA_DIR")
    if data_dir and data_dir ~= "" then
        return data_dir .. "/shiv-backend/shiv"
    end
    local home = os.getenv("HOME") or ""
    return home .. "/.local/share/mise/shiv-backend/shiv"
end

return M
