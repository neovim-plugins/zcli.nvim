local config = require( "zcli/config" )
local utils = require( "zcli/utils" )
local client, server
local M

local START_TIMEOUT = 10000 -- мс
local START_INTERVAL = 100 -- мс

local function test_rpc ()
    local channel

    pcall( function ()
        channel = vim.fn.sockconnect( "tcp", config.hostname .. ":" .. config.port )
    end )

    if not channel or channel == 0 then
        return false
    else
        vim.fn.chanclose( channel )

        return true
    end
end

local function spawn_server ()
    -- не запускаем второй раз, если процесс уже стартовал
    if server and server > 0 then
        return
    end

    local cmd = vim.fn.has( "win32" ) == 1 and "zcli.cmd" or "zcli"

    server = vim.fn.jobstart( cmd .. " rpc start", {
        detach = false,
        on_exit = function ()
            server = nil
        end,
    } )
end

local function start_client ()
    local id = vim.lsp.start( {
        name = "zcli",
        cmd = vim.lsp.rpc.connect( config.hostname, config.port ),
        on_error = function ( code, e )
            if e == "ECONNRESET" and client then
                client:stop( true )

                client = nil
            end
        end,
    } )

    return id and vim.lsp.get_client_by_id( id ) or nil
end

M = {
    setup = function ()
        if config.auto_attach then
            vim.api.nvim_create_autocmd( { "BufFilePost", "BufRead", "BufNewFile", "BufWritePost" }, {
                -- group = "zcli",
                desc = "zcli: attach",
                callback = function ( args )
                    M.attach( args.buf )
                end,
            } )
        end
    end,

    get = function ()
        if client then
            return client
        end

        if not test_rpc() then
            utils.echoc( "Spawn zcli RPC server..." )

            spawn_server()

            local ready = vim.wait( START_TIMEOUT, test_rpc, START_INTERVAL )

            if not ready then
                utils.echoe( "LSP RPC server did not start in time" )

                return nil
            end
        end

        client = start_client()

        return client
    end,

    attach = function ( bufnr )
        local c = M.get()

        if c then
            vim.lsp.buf_attach_client( bufnr, c.id )
        end
    end,
}

return M
