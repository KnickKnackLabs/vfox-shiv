--- Error formatting utilities for vfox-shiv hooks.
--- Auto-loaded by vfox from the lib/ directory.

Errors = {}

--- Strip ANSI escape codes and terminal control sequences from text.
function Errors.strip_terminal_noise(text)
    return (text
        :gsub("\27%[[%d;]*[A-Za-z]", "")
        :gsub("\27%[%?%d+[hl]", "")
        :gsub("%[D%[2K", "")
        :gsub("\r", ""))
end

--- Remove known mise and Lua runtime boilerplate lines from error output.
function Errors.strip_boilerplate(text)
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
function Errors.clean_error(raw)
    local clean = Errors.strip_boilerplate(Errors.strip_terminal_noise(raw))
    return (#clean > 0) and clean or raw
end
