--- Directory-based advisory lock with PID staleness detection.
---
--- Used by backend_install.lua to serialize the shiv bootstrap clone across
--- concurrent mise sessions. Without staleness handling, a crashed mise
--- session (SIGKILL, terminal close, OOM) leaves the lock directory on disk
--- and every subsequent mise install hangs for the full retry budget.
---
--- Design:
---   - The lock is an mkdir-created directory (atomic on POSIX).
---   - On acquisition, the holder writes $PPID into <lock_dir>/pid.
---     $PPID inside cmd.exec's sh -c is the mise process itself, because
---     mise's vfox spawns sh directly via Rust's std::process::Command
---     (no intermediate shell layer).
---   - When another process finds the lock held, it reads the PID and
---     checks `kill -0 $pid`. If the holder is dead, the lock is stale
---     and can be reclaimed (rm -rf).
---
--- Tradeoffs:
---   - PID reuse: if the holder's PID was recycled by the OS, we may
---     mistake a live unrelated process for the lock holder and wait
---     unnecessarily. This is rare and no worse than today's behavior.
---   - The PID file is written in a second cmd.exec after mkdir, so
---     there is a microscopic window where the lock dir exists but the
---     pid file doesn't. is_stale() treats missing/malformed pid as
---     stale so a crashed process between mkdir and the pid write
---     doesn't wedge forever.
---
--- See KnickKnackLabs/vfox-shiv#8.

local M = {}

--- Read the stored PID from a lock directory. Returns nil if missing or
--- malformed (non-digits). This is the sanitization hook for `kill -0`:
--- we refuse to pass anything that isn't purely digits.
--- @param lock_path string
--- @return string|nil
function M.read_pid(lock_path)
    local cmd = require("cmd")
    local ok, output = pcall(cmd.exec, "cat '" .. lock_path .. "/pid' 2>/dev/null")
    if not ok or not output then
        return nil
    end
    local trimmed = output:gsub("%s+", "")
    if trimmed == "" or trimmed:match("[^%d]") then
        return nil
    end
    return trimmed
end

--- Return true if the lock exists but its holder is no longer running
--- (or the pid file is missing/malformed).
--- @param lock_path string
--- @return boolean
function M.is_stale(lock_path)
    local cmd = require("cmd")
    local file = require("file")
    if not file.exists(lock_path) then
        return false  -- no lock, not "stale" in any meaningful sense
    end
    local pid = M.read_pid(lock_path)
    if not pid then
        return true   -- lock dir without a valid pid file = orphaned
    end
    -- `ps -p` works regardless of process ownership; `kill -0` returns
    -- EPERM for cross-user processes (including PID 1 when the caller is
    -- non-root), which would spuriously mark a live lock as stale.
    local alive = pcall(cmd.exec, "ps -p " .. pid .. " > /dev/null 2>&1")
    return not alive
end

--- Remove a stale lock directory. Safe to call on a non-existent path.
--- @param lock_path string
function M.reclaim(lock_path)
    local cmd = require("cmd")
    pcall(cmd.exec, "rm -rf '" .. lock_path .. "'")
end

--- Attempt to acquire the lock once.
---
--- Returns one of:
---   "acquired"   — lock was taken; caller must eventually call release().
---   "held_alive" — lock is held by a live process.
---   "stale"      — lock exists but holder is dead; caller may reclaim().
---
--- @param lock_path string
--- @return string
function M.try_acquire(lock_path)
    local cmd = require("cmd")
    local ok = pcall(cmd.exec, "mkdir '" .. lock_path .. "' 2>/dev/null")
    if ok then
        -- Write holder PID. $PPID is the mise process (sh -c's parent).
        pcall(cmd.exec, "echo $PPID > '" .. lock_path .. "/pid'")
        return "acquired"
    end
    if M.is_stale(lock_path) then
        return "stale"
    end
    return "held_alive"
end

--- Release a lock we hold. Safe to call even if the lock is missing.
--- @param lock_path string
function M.release(lock_path)
    local cmd = require("cmd")
    pcall(cmd.exec, "rm -rf '" .. lock_path .. "'")
end

return M
