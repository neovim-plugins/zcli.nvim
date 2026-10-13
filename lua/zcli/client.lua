local config = require( "zcli/config" )
local utils = require( "zcli/utils" )
local client
local M

local function test_rpc ()
    local channel

    pcall( function ()
        channel = vim.fn.sockconnect( "tcp", config.hostname .. ":" .. config.port )
    end )

    if not channel then
        return false
    else
        vim.fn.chanclose( channel )

        return true
    end
end

local function spawn_Server ()
    local cmd = vim.fn.has( "win32" ) == 1 and "zcli.cmd" or "zcli"

    server = vim.fn.jobstart( cmd .. " rpc start", {
        detach = false,
    } )
end

M = {
    setup = function ()
        if config.auto_attach then
            vim.api.nvim_create_autocmd( { "BufFilePost", "BufRead", "BufNewFile", "BufWritePost" }, {
                -- group = "zcli",
                desc = "zcli: attach",
                callback = function ( args )
                    local bufnr = args.buf

                    M.attach( bufnr )
                end,
            } )

        end
    end,

    get = function ()
        if not client then
            if test_rpc() then
                client = vim.lsp.get_client_by_id( vim.lsp.start( {
                    name = "zcli",
                    cmd = vim.lsp.rpc.connect( config.hostname, config.port ),
                    on_error = function ( code, e )
                        if e == "ECONNRESET" then
                            client:stop( true )

                            client = nil
                        end
                    end
                } ) )
            else
                utils.echoe( "Spawn LSP RPC server" )

                spawn_Server()
            end
        end

        return client
    end,

    attach = function ( bufnr )
        vim.lsp.buf_attach_client( bufnr, M.get().id )
    end,
}

return M
