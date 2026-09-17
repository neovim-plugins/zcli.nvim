local client = require( "zcli/client" )
local config = require( "zcli/config" )
local utils = require( "zcli/utils" )
local types = {
    javascript = "text/javascript",
    typescript = "application/x-typescript",
    json = "application/json",
    sh = "application/x-sh",
    ant = "text/xml",
    markdown = "text/markdown",
}
local M

local function do_request ( bufnr, method, params )
    local client = client.get();

    if not client then return end

    local res, e = client:request_sync( method, params, config.timeout )

    if not res then
        return
    else
        return res.result
    end
end

M = {
    lint = function ( action )
        vim.cmd.stopinsert()

        local bufnr = vim.api.nvim_get_current_buf()

        if not action then
            action = "lint"
        end

        local winid = vim.fn.bufwinid( bufnr )
        local buffer = utils.get_buffer( bufnr )

        -- buffer filetype is ignored
        if config.ignored_filetypes[ vim.bo[ bufnr ].filetype ] then
            utils.echo( "Buffer is ignored", "Comment" )

            return
        end

        if vim.bo[ bufnr ].readonly then
            utils.echo( "Buffer is read only", "Comment" )

            return
        end

        -- buffer is empty
        if buffer == "" then
            utils.echo( "Buffer is empty", "Comment" )

            return
        end

        utils.echo( action .. ":  ..." )

        local res = do_request( bufnr, "zcli/lint-file", {
            action = action,
            cwd = vim.fn.getcwd(),
            path = vim.fn.expand( "%:p" ),
            type = types[ vim.bo[ bufnr ].filetype ],
            buffer = buffer,
        } )

        if not res then
            utils.echoe( "Not connected to the LSP server" )

            return
        end

        -- buffer was changed
        if res.meta.isModified then
            local lines = vim.fn.split( res.data, "\r\n\\|\r\\|\n" )
            local cursor_pos = vim.fn.getpos( "." )

            -- update buffer
            vim.api.nvim_buf_set_lines( bufnr, 0, -1, false, {} )
            vim.api.nvim_buf_set_lines( bufnr, 0, #lines, false, lines )

            -- restore cursor position
            vim.fn.setpos( ".", cursor_pos )

            -- center cursor line on the screen
            vim.cmd.normal( "zz" )

            -- update folds
            vim.schedule( function ()
                utils.update_folds( bufnr )
            end )
        end

        -- update diagnostics
        utils.set_diagnostic( 0, res.meta.diagnostic )

        --  fatal error
        if res.meta.isFatalError then
            utils.echoe( action .. ": " .. res.status_text )

            utils.open_diagnostics()

        -- errors
        elseif res.meta.hasErrors then
            utils.echoe( action .. ": " .. res.status_text )

        -- warnings
        elseif res.meta.hasWarnings then
            utils.echow( action .. ": " .. res.status_text )

        -- ok
        else
            utils.echoc( action .. ": " .. res.status_text )
        end
    end,

    browser = function ()
        local bufnr = vim.api.nvim_get_current_buf()

        local buffer = utils.get_buffer( bufnr )

        -- buffer is empty
        if buffer == "" then
            utils.echo( "Buffer is empty", "Comment" )

            return
        end

        do_request( bufnr, "zcli/open-browser", {
            data = buffer,
            encoding = vim.o.encoding,
            font = vim.g.gfn,
        } )
    end
}

return M;
