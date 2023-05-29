local script_dir = require('pandoc.path').directory(PANDOC_SCRIPT_FILE)
package.path = string.format('%s/?.lua;%s/../?.lua;%s/../custom/?.lua;' ..
                                 '%s/../scripts/?.lua;%s', script_dir,
                             script_dir, script_dir, script_dir, package.path)

local base = require 'html-writer'

local logging = require 'logging'
local temp = logging.temp

Writer = base.Writer
Template = base.Template

Writer.BlocksHook = function(blocks, opts)
    -- convert para to plain when:
    -- * it's the only block
    -- * it's the first of two blocks and the other one is a div
    -- XXX might this catch too many cases? should drive this by a div class
    if ((#blocks == 1 and blocks[1].tag == 'Para') or
            (#blocks == 2 and
             blocks[1].tag == 'Para' and blocks[2].tag == 'Div')) then
        blocks = {pandoc.Plain(blocks[1].content), table.unpack(blocks, 2)}
    end
    return Writer.Blocks(blocks, opts)
end

-- convert divs that have attributes to bullet lists with these attributes
-- XXX is this still needed or desirable?
Writer.Block.Div = function(div, opts)
    if (#div.content == 1 and div.attr ~= base.attr_empty and
        div.content[1].tag == 'BulletList') then
        return base.blocks_content('ul', div.content[1], div.attr, 'li')
    else
        return base.block_content('div', div)
    end
end
