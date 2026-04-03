--- Sets up environment variables for an installed shiv package.
--- Adds the shiv-generated shim to PATH.
--- @param ctx BackendExecEnvCtx
--- @return BackendExecEnvResult
function PLUGIN:BackendExecEnv(ctx)
    local file = require("file")
    local bin_path = file.join_path(ctx.install_path, "bin")

    return {
        env_vars = {
            { key = "PATH", value = bin_path },
        },
    }
end
