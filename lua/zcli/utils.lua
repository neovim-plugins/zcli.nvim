local EOL = {
    unix = "\n",
    dos = "\r\n",
    mac = "\r",
}
local error_level_hl = {
    info = "Comment",
    error = "ErrorMsg",
    warning = "WarningMsg",
}

local function has_treesitter ( bufnr )
    local highlighter = require( "vim.treesitter.highlighter" )

    if highlighter.active[ bufnr ] then
        return true
    else
        return false
    end
end

local function parse_treesitter ( bufnr )
    if not vim.api.nvim_buf_is_valid( bufnr ) or not vim.api.nvim_buf_is_loaded( bufnr ) then return end

    if not has_treesitter( bufnr ) then return end

    local parser = vim.treesitter.get_parser( bufnr )

    if not parser then return end

    -- DOCS: https://neovim.io/doc/user/treesitter.html#LanguageTree%3Aparse()
    -- While a buffer is being reloaded, the tree can be stale relative to the text
    -- (injections read text using old ranges -> "Index out of bounds").
    -- In that case we invalidate the tree, and it gets rebuilt on the next redraw.
    local parsed = pcall( parser.parse, parser, true )

    if not parsed then
        pcall( parser.invalidate, parser, true )
    end
end

local M

M = {
    echo = function ( message, level )
        vim.cmd( "redraw" )

        local hl = error_level_hl[ level ]

        if hl then
            vim.cmd.echohl( hl )
        end

        vim.cmd.echo( '"' .. message .. '"' )

        if hl then
            vim.cmd.echohl( "None" )
        end
    end,

    echoc = function ( message )
        M.echo( message, "info" )
    end,

    echoe = function ( message )
        M.echo( message, "error" )
    end,

    echow = function ( message )
        M.echo( message, "warning" )
    end,

    get_buffer = function ( bufnr )
        local eol = EOL[ vim.bo[ bufnr ].fileformat ]
        local buffer = vim.fn.join( vim.fn.getline( 1, "$" ), eol )

        if buffer ~= "" then

            -- add final newline
            if not vim.b[ bufnr ].editorconfig or not vim.b[ bufnr ].editorconfig.insert_final_newline or vim.b[ bufnr ].editorconfig.insert_final_newline == "true" then
                buffer = buffer .. eol
            end
        end

        return buffer
    end,

    set_diagnostic = function ( bufnr, diagnostic )
        local namespace = vim.api.nvim_create_namespace( "zcli" )

        -- vim.diagnostic.config( options, namespace )

        if diagnostic == nil or diagnostic == vim.NIL then
            vim.diagnostic.reset( namespace, bufnr )
        else
            for index, row in ipairs( diagnostic ) do
                for key, value in pairs( row ) do
                    if value == vim.NIL then
                        row[ key ] = nil
                    end
                end

                row.severity = vim.diagnostic.severity[ row.severity ]
            end

            vim.diagnostic.set( namespace, bufnr, diagnostic )
        end
    end,

    open_diagnostics = function ()
        if vim.fn.exists( ":Telescope" ) > 0 then
            local namespace = vim.api.nvim_create_namespace( "zcli" )

            vim.cmd( "Telescope diagnostics bufnr=0 namespace=" .. namespace );
        end
    end,

    update_folds = function ( bufnr )
        if not bufnr then
            bufnr = vim.api.nvim_get_current_buf()
        end

        -- parse only after the buffer has fully reloaded (not inside the FileType autocmd)
        vim.schedule( function ()
            if not vim.api.nvim_buf_is_valid( bufnr ) or not vim.api.nvim_buf_is_loaded( bufnr ) then return end

            parse_treesitter( bufnr )

            vim.api.nvim_buf_call( bufnr, function ()
                vim.cmd.normal( "zx" )
            end )
        end )
    end,
}

return M
