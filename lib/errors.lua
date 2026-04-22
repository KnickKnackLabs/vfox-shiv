--- Error formatting utilities for vfox-shiv hooks.
---
--- Loadable via `require("errors")` \u2014 mise's vfox adds the plugin's
--- `lib/?.lua` to `package.path`. The "auto-loaded" comment in prior
--- versions was misleading; nothing auto-loads this module. Each hook
--- that wants to use `Errors.*` must `require("errors")`.
---
--- See KnickKnackLabs/vfox-shiv#10 for the backstory.

local M = {}

--- Strip ANSI escape codes and terminal control sequences from text.
function M.strip_terminal_noise(text)
    return (text
        :gsub("\27%[[%d;]*[A-Za-z]", "")
        :gsub("\27%[%?%d+[hl]", "")
        :gsub("%[D%[2K", "")
        :gsub("\r", ""))
end

--- Remove known mise and Lua runtime boilerplate lines from error output.
function M.strip_boilerplate(text)
    text = text:gsub('[^\n]*Run with %-%-verbose[^\n]*', '')
    text = text:gsub('[^\n]*MISE_VERBOSE[^\n]*', '')
    text = text:gsub('[^\n]*stack traceback[^\n]*', '')
    text = text:gsub('[^\n]*in function[^\n]*', '')
    text = text:gsub('[^\n]*tail calls[^\n]*', '')
    text = text:gsub('[^\n]*%[C%]: in %?[^\n]*', '')
    return (text:gsub('\n+', '\n'):gsub('^%s+', ''):gsub('%s+$', ''))
end

--- Clean command error output for human-readable display.
--- Combines terminal noise stripping and boilerplate removal.
--- Falls back to raw input if cleaning produces empty string.
function M.clean_error(raw)
    local clean = M.strip_boilerplate(M.strip_terminal_noise(raw))
    return (#clean > 0) and clean or raw
end

return M
