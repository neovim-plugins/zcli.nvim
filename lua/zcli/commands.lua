local api = require( "zcli/api" )
local utils = require( "zcli/utils" )

local function execute ( input )

    if not input.fargs[ 1 ] then
        utils.echoe( "Command is required" )

    -- lint
    elseif input.fargs[ 1 ] == "lint" then
        api.lint( input.fargs[ 2 ] )

    -- browser
    elseif input.fargs[ 1 ] == "browser" then
        api.browser()

    -- invalid command
    else
        utils.echoe( "Command is not valid: " .. input.fargs[ 1 ] )
    end
end

local subcommands = { "lint", "browser" }

local function complete ( arglead, cmdline, cursorpos )
    local parts = vim.split( cmdline:sub( 1, cursorpos ), "%s+", { trimempty = true } )

    -- number of the argument being completed (1 = subcommand)
    local position = arglead == "" and #parts or #parts - 1

    if position == 1 then
        return vim.tbl_filter( function ( name )
            return vim.startswith( name, arglead )
        end, subcommands )
    end

    return {}
end

local M

M = {
    setup = function ()
        vim.api.nvim_create_user_command( "Zcli", execute, {
            nargs = "*",
            complete = complete,
            desc = "zcli LSP",
        } )
    end,
}

return M
