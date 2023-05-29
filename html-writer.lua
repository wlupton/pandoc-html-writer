local script_dir = require('pandoc.path').directory(PANDOC_SCRIPT_FILE)
package.path = string.format('%s/?.lua;%s/../?.lua;%s/../scripts/?.lua;%s',
                             script_dir, script_dir, script_dir, package.path)

local logging = require 'logging'
local temp = logging.temp

-- XXX should use the add() pattern, like in html-single-writer.lua

-- base writer
-- XXX should check the pandoc version; it needs to be at least 3.0
Writer = pandoc.scaffolding.Writer

-- default template
-- XXX the documentation says this should return a Template object,
--     but it seems that it should return a string?
function Template()
    return pandoc.template.default('html')
end

local function escape(text, in_attribute)
    return text:gsub('[<>&"\']',
                     function(char)
                         if char == '<' then
                             return '&lt;'
                         elseif char == '>' then
                             return '&gt;'
                         elseif char == '&' then
                             return '&amp;'
                         elseif in_attribute and char == '"' then
                             return '&quot;'
                         elseif in_attribute and char == "'" then
                             -- XXX this was '&#39;'; is that better?
                             return '&apos;'
                         else
                             return char
                         end
                     end)
end

-- note that the returned string is either empty or starts with a space
-- XXX need to insert 'data-' prefixes for non-standard attributes
local function attributes(attr)
    local comps = pandoc.List()
    -- XXX this was utils.spairs()
    for name, value in pairs(attr) do
        if value and #value > 0 then
            comps:insert(string.format(' %s="%s"', name, escape(value, true)))
        end
    end
    return table.concat(comps)
end

-- XXX I think that can just use {} to indicate empty attributes
local attr_empty = pandoc.Attr()

-- XXX need to pass down opts so they're always available

local function open(name, attr, extra, close)
    attr = attr or attr_empty

    -- XXX hack to allow extra to be an Attr instance and to replace attr
    --     if it's empty (this is a workaround poor interface choices)
    -- XXX a better fix would merge attr and extra
    if attr == attr_empty and extra and extra.tag == 'Attr' then
        attr, extra = extra, nil
    end

    local comps = pandoc.List()
    if name and #name > 0 then
        comps:insert('<')
        comps:insert(name)
        if #attr.identifier > 0 then
            comps:insert(' id="')
            comps:insert(attr.identifier)
            comps:insert('"')
        end
        if #attr.classes > 0 then
            comps:insert(' class="')
            comps:insert(table.concat(attr.classes, ' '))
            comps:insert('"')
        end
        -- attributes() takes care of the leading space
        comps:insert(attributes(attr.attributes))
        if extra then
            -- XXX allow extra to be an Attr instance
            comps:insert(attributes(extra.tag == 'Attr' and
                                        extra.attributes or extra))
        end
        comps:insert('>')
        if close then
            comps:insert('</')
            comps:insert(name)
            comps:insert('>')
        end
    end
    return table.concat(comps)
end

local function close(name)
    local comps = pandoc.List()
    if name and #name > 0 then
        comps:insert('</')
        comps:insert(name)
        comps:insert('>')
    end
    return table.concat(comps)
end

local function element(name, attr, extra)
    return open(name, attr, extra, true)
end

local function blocks_content(name, elem, extra, child_name)
    if not child_name then child_name = '' end
    local items = pandoc.List()
    items:insert(open(name, elem.attr or attr_empty, extra))
    for _, blocks in ipairs(elem.content) do
        items:insert(pandoc.layout.cr)
        items:insert(open(child_name))
        items:insert(Writer.BlocksHook(blocks))
        items:insert(close(child_name))
    end
    items:insert(close(name))
    return items
end

local function block_content(name, elem, extra)
    local items = pandoc.List()
    items:insert(open(name, elem.attr or attr_empty, extra))
    items:insert(Writer.BlocksHook(elem.content))
    items:insert(close(name))
    return items
end

local function inline_content(name, elem, extra)
    local items = pandoc.List()
    items:insert(open(name, elem.attr or attr_empty, extra))
    items:insert(Writer.InlinesHook(elem.content))
    items:insert(close(name))
    return items
end

-- table of contents is created by Writer.Block.Header

local table_of_contents = pandoc.List()

-- XXX need to check that all element types are covered and that the correct
--     text is being generated

-- Block elements

-- XXX it doesn't seem to work to define Writer.Blocks and then invoke
--     pandoc.scaffolding.Writer.Blocks() (similar for Inlines)
-- XXX maybe I've misunderstood Writer.Blocks and Writer.Block.Blocks? no,
--     they're the same; having both is a bit confusing? (similar for Inlines)
Writer.BlocksHook = function(blocks, opts)
    return Writer.Blocks(blocks, opts)
end

Writer.Block.BlockQuote = function(quote)
    return block_content('blockquote', quote)
end

Writer.Block.BulletList = function(list, opts, attr)
    return blocks_content('ul', list, attr, 'li')
end

Writer.Block.CodeBlock = function(code)
    return open('pre') .. open('code', code.attr) .. escape(code.text) ..
        close('code') .. close('pre')
end

Writer.Block.DefinitionList = function(list, opts, attr)
    local items = pandoc.List()
    items:insert(pandoc.layout.cr)
    items:insert(open('dl'))
    for _, dt_and_dd in ipairs(list.content) do
        items:insert(open('dt'))
        items:insert(Writer.InlinesHook(dt_and_dd[1]))
        items:insert(close('dt'))
        for _, blocks in ipairs(dt_and_dd[2]) do
            items:insert(open('dd'))
            items:insert(Writer.BlocksHook(blocks))
            items:insert(close('dd'))
        end
    end
    return items
end

Writer.Block.Div = function(div, opts)
    return block_content('div', div)
end

-- XXX what determines which functions are called? they aren't necessarily the
--     same as those in classic writers, e.g., the classic writer has
--     CaptionedImage, and they aren't necessarily the same as the pandoc
--     lua classes... oh hang on, I think they are the same; perhaps these two
--     are the only ones with different names
Writer.Block.Figure = function(figure, opts)
    local items = pandoc.List()
    items:insert(open('figure', figure.attr or attr_empty))
    items:insert(Writer.BlocksHook(figure.content))
    items:insert(open('figcaption', attr_empty, {['aria-hidden']='true'}))
    items:insert(Writer.BlocksHook(figure.caption.long))
    items:insert(close('figcaption'))
    items:insert(close('figure'))
    return items
end

Writer.Block.Header = function(header, opts)
    local name = string.format('h%d', header.level)
    -- XXX careful re extend versus insert; I think scaffolding is forgiving...
    table_of_contents:extend{
        {level=header.level, content=pandoc.utils.stringify(header.content)}
    }
    return inline_content(name, header)
end

Writer.Block.HorizontalRule = function(rule)
    return '<hr/>'
end

Writer.Block.LineBlock = function(line_block)
    local items = pandoc.List()
    -- XXX documentation for pandoc.Attr() is wrong (id, class)
    items:insert(open('div', {identifier='', classes={'line-block'},
                              attributes={}}))
    for i, inlines in ipairs(line_block.content) do
        items:insert(Writer.InlinesHook(inlines))
        if i < #line_block.content then
            items:insert(Writer.Inline.LineBreak())
        end
    end
    items:insert(close('div'))
    return items
end

-- XXX need to support numbering styles etc.
Writer.Block.OrderedList = function(list)
    return blocks_content('ol', list, attr_empty, 'li')
end

Writer.Block.Para = function(para)
    return inline_content('p', para)
end

Writer.Block.Plain = function(plain)
    return inline_content('', plain)
end

Writer.Block.RawBlock = function(raw)
    return raw.format == 'html' and raw.text or ''
end

-- XXX need to handle caption
Writer.Block.Table = function(table)
    local items = pandoc.List()
    items:insert(pandoc.layout.cr)
    items:insert(open('table', table.attr))

    -- column specs (done lazily because they're only needed for widths)
    local aligns = pandoc.List()
    local opened = false
    for i, colspec in ipairs(table.colspecs) do
        aligns:insert(colspec[1])
        local width = colspec[2]
        local style = nil
        if width then
            width = 100 * width
            style = string.format('width: %.1f%%;', width)
        end
        if style then
            if not opened then
                items:insert(pandoc.layout.cr)
                items:insert(open('colgroup'))
                opened = true
            end
            items:insert(pandoc.layout.cr)
            items:insert(element('col', attr_empty, {style=style}))
        end
    end
    if opened then
        items:insert(close('colgroup'))
    end

    -- helpers
    local function align_string(align)
        local text = ({AlignLeft='left',
                       AlignRight='right', AlignCenter='center'})[align]
        if text then
            text = string.format('text-align: %s;', text)
        end
        return text
    end

    local function output(name, elem, opts)
        opts = opts or {}
        local head_rows = opts.head_rows or 0 -- "#elem.head"
        local head_cols = opts.head_cols or 0 -- "body.row_head_columns"
        items:insert(pandoc.layout.cr)
        items:insert(open(name, elem.attr))
        for y, row in ipairs(elem.rows or (elem.head .. elem.body)) do
            items:insert(pandoc.layout.cr)
            -- XXX this was row but should surely be row.attr?
            items:insert(open('tr', row.attr))
            for x, cell in ipairs(row.cells) do
                local cname = (name == 'thead' or y <= head_rows or
                                   x <= head_cols) and 'th' or 'td'
                local align = align_string(cell.alignment or aligns[x])
                local col_span = cell.col_span > 1 and tostring(cell.col_span)
                    or nil
                local row_span = cell.row_span > 1 and tostring(cell.col_span)
                    or nil
                items:insert(pandoc.layout.cr)
                -- XXX this can now be blocks_content()
                items:insert(open(cname, cell.attr, {align=align,
                                                     colspan=col_span,
                                                     rowspan=row_span}))
                items:insert(Writer.BlocksHook(cell.contents))
                items:insert(close(cname))
            end
            items:insert(close('tr'))
        end
        items:insert(close(name))
    end

    -- header
    if #table.head.rows > 0 then
        output('thead', table.head)
    end

    -- bodies
    for _, body in ipairs(table.bodies) do
        items:insert(pandoc.layout.cr)
        local opts = {head_rows=#body.head, head_cols=body.row_head_columns}
        output('tbody', body, opts)
    end

    -- foot
    if #table.foot.rows > 0 then
        items:insert(pandoc.layout.cr)
        output('tfoot', table.foot)
    end

    items:insert(close('table'))
    return items
end

-- Inline elements

Writer.InlinesHook = function(inlines, opts)
    return Writer.Inlines(inlines, opts)
end

-- XXX need to implement this
Writer.Inline.Cite = function(cite)
    temp('cite', cite.citations[1].id, '...')
    return '{{Cite}}'
end

Writer.Inline.Code = function(code)
    return open('code', code.attr) .. escape(code.text) .. close('code')
end

Writer.Inline.Emph = function(emph)
    return inline_content('em', emph)
end

Writer.Inline.Image = function(image)
    return element('img', image.attr,
                   {src=image.src, title=image.title,
                    alt=pandoc.utils.stringify(image.caption)})
end

-- XXX this could be a constant
Writer.Inline.LineBreak = function(line_break)
    return '<br/>'
end

Writer.Inline.Link = function(link)
    return inline_content('a', link, {href=link.target, title=link.title})
end

Writer.Inline.Math = function(math)
    -- XXX should pass some (but not all) writer options
    -- XXX we may be able to use this trick (leveraging pandoc) elsewhere?
    return pandoc.write(pandoc.Pandoc(math), 'html')
end

-- XXX need to implement this
Writer.Inline.Note = function(note)
    temp('note', note.content[1].content[1], '...')
    return '{{Note}}'
end

-- XXX does this need to account for the 'smart' extension?
Writer.Inline.Quoted = function(quoted)
    local quotes = quoted.quotetype == 'SingleQuote' and
        {left='&lsquo;', right='&rsquo;'} or {left='&ldquo;', right='&rdquo;'}
    return quotes.left .. Writer.Inlines(quoted.content) .. quotes.right
end

Writer.Inline.RawInline = function(raw)
    return raw.format == 'html' and raw.text or ''
end

-- XXX this pattern occurs a few times
Writer.Inline.SmallCaps = function(small_caps)
    local items = pandoc.List()
    items:insert(open('span', {identifier='', classes={'smallcaps'},
                               attributes={}}))
    items:insert(Writer.InlinesHook(small_caps.content))
    items:insert(close('span'))
    return items
end

Writer.Inline.SoftBreak = function(soft_break)
    return '\n'
end

Writer.Inline.Space = function(space)
    return ' '
end

Writer.Inline.Span = function(span)
    return inline_content('span', span)
end

Writer.Inline.Str = function(str)
    return escape(str.text)
end

Writer.Inline.Strikeout = function(strikeout)
    local items = pandoc.List()
    items:insert(open('del'))
    items:insert(Writer.InlinesHook(strikeout.content))
    items:insert(close('del'))
    return items
end

Writer.Inline.Strong = function(strong)
    return inline_content('strong', strong)
end

Writer.Inline.Subscript = function(subscript)
    return inline_content('sub', subscript)
end

Writer.Inline.Superscript = function(superscript)
    return inline_content('sup', superscript)
end

Writer.Inline.Underline = function(underline)
    local items = pandoc.List()
    items:insert(open('u'))
    items:insert(Writer.InlinesHook(underline.content))
    items:insert(close('u'))
    return items
end

-- document

-- XXX apparently you can return vars as a second argument
Writer.Pandoc = function(doc, opts)
    -- temp('opts', opts)
    -- temp('meta', doc.meta)
    local html = Writer.BlocksHook(doc.blocks)
    local vars = pandoc.template.meta_to_context(
        doc.meta, Writer.BlocksHook, Writer.InlinesHook)
    -- XXX there must be more opts that need to be copied to vars; for a
    --     start there are opts.variables, which include css
    vars.toc = opts.table_of_contents
    vars['table-of-contents'] = logging.dump(table_of_contents)
    -- XXX Doc objects just show as 'Doc {}'; render it?
    -- temp('vars', vars)
    return html, vars
end

-- XXX documentation is confusing; this is only relevant for classic writers;
--     it does nothing (and isn't called) for old-style writers
function Doc(body, meta, vars)
    -- temp('vars', vars)
    vars.date = vars.date or meta.data or os.date '%B %e, %Y'
    return body, vars
end

-- the following code will produce runtime warnings when you haven't defined
-- all of the functions you need for the custom writer, so it's useful
-- to include when you're working on a writer
-- XXX I don't think this helps with new-style writers :(
local meta = {}
meta.__index =
    function(_, key)
        io.stderr:write(
            string.format("WARNING: Undefined function '%s'\n", key))
        return function() return "" end
    end
setmetatable(_G, meta)

-- this isn't needed to use this writer; it's for use by derived writers
return {
    -- derived writers' base writer and template
    Writer=Writer,
    Template=Template,

    -- utilities
    open=open,
    close=close,
    blocks_content=blocks_content,
    block_content=block_content,
    inline_content=inline_content,

    -- miscellaneous
    attr_empty=attr_empty
}
