--- Lists available versions (git tags) for a shiv package.
--- Resolves tool name to a GitHub repo via shiv's source files,
--- then queries the GitHub API for tags.
--- @param ctx BackendListVersionsCtx
--- @return BackendListVersionsResult
function PLUGIN:BackendListVersions(ctx)
    local cmd = require("cmd")
    local json = require("json")
    local tool = ctx.tool

    if not tool or tool == "" then
        error("Tool name cannot be empty")
    end

    -- Resolve tool name to GitHub repo slug
    local repo = resolve_repo(tool)
    if not repo then
        error("Package '" .. tool .. "' not found in any shiv source file")
    end

    -- List tags via gh CLI (handles auth for private repos)
    local versions = {}
    local ok, output = pcall(cmd.exec, "gh api repos/" .. repo .. "/tags --jq '.[].name' 2>/dev/null")
    if ok and output and output ~= "" then
        -- Parse tags into version list
        local tags = {}
        for tag in output:gmatch("[^\n]+") do
            -- Strip leading 'v' prefix for mise's version model
            local version = tag:gsub("^v", "")
            table.insert(tags, version)
        end

        -- Reverse so oldest is first (mise expects ascending order)
        for i = #tags, 1, -1 do
            table.insert(versions, tags[i])
        end
    end

    -- Always include "latest" as a pseudo-version.
    -- When BackendInstall sees this, it installs without a ref
    -- (tracking the default branch, same as bare `shiv install <tool>`).
    table.insert(versions, "latest")

    return { versions = versions }
end

--- Resolve a tool name to a GitHub repo slug by searching shiv source files.
--- Checks user's sources dir (~/.config/shiv/sources/) first,
--- then falls back to the plugin's bundled shiv sources.json.
--- @param tool string
--- @return string|nil
function resolve_repo(tool)
    local json = require("json")
    local cmd = require("cmd")

    -- Check user's shiv sources directory
    local sources_dir = os.getenv("SHIV_SOURCES_DIR")
        or os.getenv("XDG_CONFIG_HOME") and (os.getenv("XDG_CONFIG_HOME") .. "/shiv/sources")
        or (os.getenv("HOME") .. "/.config/shiv/sources")

    local ok, listing = pcall(cmd.exec, "ls " .. sources_dir .. "/*.json 2>/dev/null")
    if ok and listing and listing ~= "" then
        for file_path in listing:gmatch("[^\n]+") do
            local repo = lookup_in_source(file_path, tool)
            if repo then return repo end
        end
    end

    -- Fall back to the plugin's bootstrapped shiv clone
    local shiv_path = get_shiv_path()
    local bundled = shiv_path .. "/sources.json"
    local repo = lookup_in_source(bundled, tool)
    if repo then return repo end

    return nil
end

--- Look up a tool name in a single sources.json file.
--- @param file_path string
--- @param tool string
--- @return string|nil
function lookup_in_source(file_path, tool)
    local cmd = require("cmd")
    local ok, result = pcall(cmd.exec, "jq -r --arg n '" .. tool .. "' '.[$n] // empty' '" .. file_path .. "' 2>/dev/null")
    if ok and result and result ~= "" then
        return result:gsub("%s+$", "")
    end
    return nil
end

--- Get the path to the plugin's shiv clone.
--- @return string
function get_shiv_path()
    local home = os.getenv("HOME") or ""
    return os.getenv("VFOX_SHIV_PATH")
        or (home .. "/.local/share/mise/shiv-backend/shiv")
end
