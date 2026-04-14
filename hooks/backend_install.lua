--- Installs a shiv package by delegating to shiv's install task.
--- Bootstraps shiv if not already present.
--- @param ctx BackendInstallCtx
--- @return BackendInstallResult
function PLUGIN:BackendInstall(ctx)
    local cmd = require("cmd")
    local tool = ctx.tool
    local version = ctx.version
    local install_path = ctx.install_path

    if not tool or tool == "" then
        error("Tool name cannot be empty")
    end
    if not version or version == "" then
        error("Version cannot be empty")
    end
    if not install_path or install_path == "" then
        error("Install path cannot be empty")
    end

    -- Ensure shiv is bootstrapped
    local shiv_path = ensure_shiv()

    -- Build the version/ref specifier for shiv install.
    -- "latest" means no ref (track default branch).
    -- Otherwise, mise strips 'v' prefixes from versions, so we add it back
    -- since shiv tags use the 'v' prefix.
    local tool_spec = tool
    if version ~= "latest" then
        local ref = version
        if not version:match("^v") then
            ref = "v" .. version
        end
        tool_spec = tool .. "@" .. ref
    end

    -- Create isolated shiv environment pointing at mise's install_path
    local shiv_env = {
        SHIV_PACKAGES_DIR = install_path .. "/packages",
        SHIV_BIN_DIR = install_path .. "/bin",
        SHIV_CONFIG_DIR = install_path .. "/config",
        SHIV_CACHE_DIR = install_path .. "/cache",
    }

    -- Build env string for the command
    local env_prefix = ""
    for k, v in pairs(shiv_env) do
        env_prefix = env_prefix .. k .. "='" .. v .. "' "
    end

    -- Sync remote sources.json into bundled shiv so it knows about new packages
    sync_bundled_sources(shiv_path)

    -- Delegate to shiv install via mise run
    local mise_bin = find_mise()
    local install_cmd = env_prefix .. shiv_mise_env() .. mise_bin .. " -C '" .. shiv_path .. "' run -q install " .. tool_spec

    local ok, result = pcall(cmd.exec, install_cmd)
    if not ok then
        error("shiv install failed for " .. tool_spec .. ": " .. Errors.clean_error(tostring(result)))
    end

    return {}
end

--- Sync the bundled shiv's sources.json with the remote version.
--- Uses the same cached remote sources as backend_list_versions.
--- Falls back silently if fetch fails (bundled sources still work).
function sync_bundled_sources(shiv_path)
    local cmd = require("cmd")
    local file = require("file")

    local sources_url = os.getenv("VFOX_SHIV_SOURCES_URL")
        or "https://raw.githubusercontent.com/KnickKnackLabs/shiv/main/sources.json"
    local target = shiv_path .. "/sources.json"

    pcall(cmd.exec, "curl -sf --max-time 3 -o '" .. target .. "' '" .. sources_url .. "'")
end

--- Ensure the plugin's shiv clone exists and is at the pinned ref.
--- Bootstraps via git clone if not present.
--- @return string Path to the shiv clone
function ensure_shiv()
    local cmd = require("cmd")
    local file = require("file")

    local shiv_path = get_shiv_path()

    -- Pin to a specific shiv version for reproducibility
    local shiv_ref = os.getenv("VFOX_SHIV_REF") or "v0.2.3"
    local shiv_repo = os.getenv("VFOX_SHIV_REPO") or "https://github.com/KnickKnackLabs/shiv.git"

    if file.exists(shiv_path .. "/.git/HEAD") then
        -- Already cloned — verify ref if pinned
        -- (For now, trust what's there. Version pinning enforcement can come later.)
        return shiv_path
    end

    -- Bootstrap: clone shiv at the pinned ref.
    -- Multiple shiv:* tools may try to bootstrap simultaneously via
    -- parallel mise install. Use mkdir as an atomic lock.
    local lock_path = shiv_path .. ".lock"
    local parent_dir = shiv_path:match("(.+)/[^/]+$")
    if parent_dir then
        pcall(cmd.exec, "mkdir -p '" .. parent_dir .. "'")
    end

    -- Spin until we acquire the lock or shiv appears
    local got_lock = false
    for attempt = 1, 60 do
        -- Check if another installer already finished
        if file.exists(shiv_path .. "/.git/HEAD") then
            return shiv_path
        end
        -- Try to acquire lock (mkdir is atomic on POSIX)
        local ok = pcall(cmd.exec, "mkdir '" .. lock_path .. "' 2>/dev/null")
        if ok then
            got_lock = true
            break
        end
        -- Lock held by another installer — wait and retry
        pcall(cmd.exec, "sleep 1")
    end

    if not got_lock then
        -- Final check before giving up
        if file.exists(shiv_path .. "/.git/HEAD") then
            return shiv_path
        end
        error("Timed out waiting for shiv bootstrap lock")
    end

    -- We hold the lock. Re-check in case someone finished just before us.
    if file.exists(shiv_path .. "/.git/HEAD") then
        pcall(cmd.exec, "rmdir '" .. lock_path .. "'")
        return shiv_path
    end

    -- Clone shiv
    local clone_cmd = "git clone --quiet --branch " .. shiv_ref .. " --depth 1 --single-branch "
        .. shiv_repo .. " '" .. shiv_path .. "'"

    local ok, result = pcall(cmd.exec, clone_cmd)
    -- Release lock regardless of outcome
    pcall(cmd.exec, "rmdir '" .. lock_path .. "'")
    if not ok then
        -- Clean up partial clone
        pcall(cmd.exec, "rm -rf '" .. shiv_path .. "'")
        error("Failed to bootstrap shiv: " .. tostring(result))
    end

    -- Trust the mise config so shiv's tasks can run
    local mise_bin = find_mise()
    pcall(cmd.exec, shiv_mise_env() .. mise_bin .. " trust -q -C '" .. shiv_path .. "'")

    -- Install shiv's runtime dependencies (gum).
    -- This must succeed — shiv's tasks (install, update, etc.) require gum.
    -- Unset GITHUB_TOKEN to avoid GHE tokens blocking github.com downloads.
    local install_ok, install_err = pcall(cmd.exec,
        "env -u GITHUB_TOKEN " .. shiv_mise_env() .. mise_bin .. " install -q -C '" .. shiv_path .. "'")
    if not install_ok then
        error("Failed to install shiv dependencies (gum): " .. tostring(install_err))
    end

    return shiv_path
end

--- Find the mise binary.
--- @return string
function find_mise()
    local cmd = require("cmd")
    local ok, path = pcall(cmd.exec, "command -v mise")
    if ok and path and path ~= "" then
        return path:gsub("%s+$", "")
    end
    -- Fall back to common locations
    local home = os.getenv("HOME") or ""
    local candidates = {
        home .. "/.local/bin/mise",
        "/usr/local/bin/mise",
        "/usr/bin/mise",
    }
    for _, p in ipairs(candidates) do
        local file = require("file")
        if file.exists(p) then return p end
    end
    error("mise not found on PATH or in common locations")
end

--- Build an env prefix for nested mise calls into the shiv clone.
--- Points mise at mise.prod.toml (runtime-only dependencies) so dev/test
--- tools like bats aren't installed during bootstrap. This also prevents
--- the parent's MISE_OVERRIDE_CONFIG_FILENAMES from leaking in.
--- @return string
function shiv_mise_env()
    return "MISE_OVERRIDE_CONFIG_FILENAMES=mise.prod.toml "
end

--- Get the path to the plugin's shiv clone.
--- @return string
function get_shiv_path()
    local home = os.getenv("HOME") or ""
    return os.getenv("VFOX_SHIV_PATH")
        or (home .. "/.local/share/mise/shiv-backend/shiv")
end
