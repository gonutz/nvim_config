-- Forward declarations:
_G.edit_config = nil
_G.source_config = nil
_G.open_explorer = nil
_G.open_console = nil
_G.run = nil
_G.open_recent_file = nil
_G.get_tabline = nil

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.mouse = 'a'
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = false
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = false
vim.opt.termguicolors = true
vim.opt.fileformat = "unix"
vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"
vim.opt.tabline = "%!v:lua.get_tabline()"
vim.api.nvim_set_option("clipboard", "unnamedplus")

vim.g.neovide_cursor_animation_length = 0
vim.g.neovide_cursor_trail_size = 0
vim.g.neovide_cursor_animate_in_insert_mode = false
vim.g.neovide_cursor_animate_command_line = false
vim.g.neovide_ligatures_enabled = false
vim.opt.guifont = "Consolas:h14"

vim.g.mapleader = ' '

-- Edit this config with F9, reload it with F10.
vim.keymap.set('n', '<f9>', ':lua edit_config()<cr>')
vim.keymap.set('n', '<f10>', ':lua source_config()<cr>')

vim.keymap.set({'n', 'i', 'x', 's', 'v', 't', 'o'}, 'ö', '<esc>')
vim.keymap.set('n', '<f11>', ":lua open_explorer()<cr>")
vim.keymap.set('n', '<f12>', ":lua open_console()<cr>")
vim.keymap.set('n', '<c-s>', ':w<cr>')
vim.keymap.set('i', '<c-s>', '<esc><cmd>w<cr>a')
vim.keymap.set('n', '<c-l>', '<c-w>l')
vim.keymap.set('n', '<c-h>', '<c-w>h')
vim.keymap.set('n', 'Ö', 'gt')
vim.keymap.set('n', 'Ä', 'gT')
vim.keymap.set('n', '<leader>a', ':%y<cr>')
vim.keymap.set({'n', 'i'}, '<c-j>', '<c-e>')
vim.keymap.set({'n', 'i'}, '<c-k>', '<c-y>')
vim.keymap.set('n', '<leader>q', ':q<cr>')
vim.keymap.set('n', '<leader>n', ':tabnew<cr>')
vim.keymap.set('n', '<leader>r', ':lua run("run")<cr>', { silent = true })
vim.keymap.set('n', '<leader>b', ':lua run("build")<cr>', { silent = true })
vim.keymap.set('n', '<leader>t', ':lua run("test")<cr>', { silent = true })
vim.keymap.set('n', '<leader>i', ':lua run("install")<cr>', { silent = true })
vim.keymap.set('n', '<leader>f', ':lua run("format")<cr>', { silent = true })
vim.keymap.set('i', '<tab>', [[pumvisible() ? "\<c-n>" : "\<c-x>\<c-o>"]], { expr = true, noremap = true })
vim.keymap.set('n', '<a-v>', '<c-v>')
vim.keymap.set({'c', 'i'}, '<C-v>', '<C-r>+', { noremap = true, silent = true })
vim.keymap.set('n', '<leader>o', ':lua open_recent_file()<cr>')

function get_tabline()
	local s = ''
	local active_tab = vim.fn.tabpagenr()
	for i = 1, vim.fn.tabpagenr('$') do
		local winnr = vim.fn.tabpagewinnr(i)
		local bufnr = vim.fn.tabpagebuflist(i)[winnr]
		local name = vim.fn.fnamemodify(vim.fn.bufname(bufnr), ':t')

		-- Put the active tab in brackets.
		if i == active_tab then
			s = s .. '%#TabLineSel#' .. '%' .. i .. 'T' .. '[' .. name .. ']'
		else
			s = s .. '%#TabLine#' .. '%' .. i .. 'T' .. ' ' .. name .. ' '
		end
	end
	return s
end

local function is_space(c)
	return c == " " or c == "\t"
end

local function split_indent(line)
	local indent = ""
	local rest = line

	for i = 1, #line do
		local c = line:sub(i, i)
		if is_space(c) then
			indent = indent .. c
			rest = line:sub(i + 1, #line)
		else
			break
		end
	end

	return indent, rest
end

local function has_comment(line, slashes)
	local _, rest = split_indent(line)
	return rest:sub(1, #slashes) == slashes
end

local function remove_comment(indent, rest, slashes)
	local meat = rest:sub(#slashes + 1, #rest)

	while is_space(meat:sub(1, 1)) do
		meat = meat:sub(2, #meat)
	end

	return indent .. meat
end

local function common_prefix(a, b)
	for i = 1, math.min(#a, #b) do
		local ca = a:sub(i, i)
		local cb = b:sub(i, i)
		if ca ~= cb then
			return a:sub(1, i - 1)
		end
	end

	return a:sub(1, math.min(#a, #b))
end

local function space_after_comment(line, slashes)
	local _, rest = split_indent(line)
	local indent = split_indent(rest:sub(#slashes + 1, #rest))
	return indent
end

function toggle_comments(slashes, start_line, end_line)
	if not start_line then
		start_line = vim.fn.line("'<")
		end_line = vim.fn.line("'>")
	end

	local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)

	local all_comments = true
	for i = 1, #lines do
		all_comments = all_comments and has_comment(lines[i], slashes)
	end

	if all_comments then
		-- Remove the comments.
		local common_space_after_comment = space_after_comment(lines[1], slashes)
		for i = 2, #lines do
			local space_after_comment = space_after_comment(lines[i], slashes)
			common_space_after_comment = common_prefix(common_space_after_comment, space_after_comment)
		end

		for i = 1, #lines do
			local indent, rest = split_indent(lines[i])
			lines[i] = indent .. rest:sub(#slashes + 1 + #common_space_after_comment, #rest)
		end
	else
		-- Add comments.
		local common_indent = split_indent(lines[1])
		for i = 2, #lines do
			local indent = split_indent(lines[i])
			common_indent = common_prefix(common_indent, indent)
		end

		for i = 1, #lines do
			lines[i] = common_indent .. slashes .. " " .. lines[i]:sub(#common_indent + 1, #lines[i])
		end
	end

	vim.api.nvim_buf_set_lines(0, start_line - 1, end_line, false, lines)
end

function toggle_comment(slashes)
	local line_num = vim.api.nvim_win_get_cursor(0)[1] - 1

	if vim.v.count > 1 then
		local line_count = vim.api.nvim_buf_line_count(0)
		toggle_comments(slashes, line_num + 1, math.min(line_count, line_num + vim.v.count))
		do return end
	end

	local line = vim.api.nvim_buf_get_lines(0, line_num, line_num + 1, false)[1]

	local indent, line_meat = split_indent(line)

	if has_comment(line_meat, slashes) then
		line = remove_comment(indent, line_meat, slashes)
	else
		line = indent .. slashes .. " " .. line_meat
	end

	vim.api.nvim_buf_set_lines(0, line_num, line_num + 1, false, {line})
end

local function on_windows()
	local os = vim.loop.os_uname().sysname
	return os:match("Windows")
end

local function to_windows_path(path)
	path, _ = path:gsub("/", "\\")
	return path
end

local function current_folder()
	local path = vim.fn.expand("%:p:h")
	if on_windows() then
		path = to_windows_path(path)
	end
	return path
end

local function current_file()
	local path = vim.fn.expand("%:p")
	if on_windows() then
		path = to_windows_path(path)
	end
	return path
end

local function tab_or_edit()
	local buffer = vim.api.nvim_buf_get_name(0)
	local empty = vim.api.nvim_buf_line_count(0) == 1 and vim.api.nvim_buf_get_lines(0, 0, -1, false)[1] == ""
	if buffer == "" and empty then
		return "edit "
	else
		return "tabnew "
	end
end

function open_explorer()
	vim.fn.system('explorer /select,"' .. current_file() .. '"')
end

function open_console()
	vim.fn.system("start /MAX cmd /k cd /d " .. current_folder())
end

function edit_config()
	vim.cmd(tab_or_edit() .. vim.fn.stdpath("config") .. "/init.lua")
end

function source_config()
	vim.cmd("wa")
	vim.cmd("source " .. vim.fn.stdpath("config") .. "/init.lua")
end

local function file_exists(path)
	return vim.loop.fs_stat(path) ~= nil
end

local function execute(cmd)
	print(cmd)
	local output = vim.fn.system(cmd)
	print(output)
end

function run(cmd)
	vim.cmd("wa")

	-- Try running "run.bat" if it exists.
	local run_file = to_windows_path(vim.fn.expand("%:p:h")) .. "\\" .. cmd .. ".bat"
	if file_exists(run_file) then
		execute(run_file)
	else
		-- If no "run.bat" exists, try the standard language way to run it.
		local ft = vim.bo.filetype
		if ft == "go" then
			if cmd == "format" then
				execute("go fmt .")
				vim.cmd("edit!")
			else
				execute("go " .. cmd .. " .")
			end
		elseif ft == "dosbatch" then
			execute(vim.fn.expand("%:p"))
		else
			print("error: no " .. cmd .. ".bat and no idea how to " .. cmd .. " file type " .. ft)
		end
	end

	vim.cmd("e")
end

function open_recent_file()
	local recents = vim.v.oldfiles
	for i, file in ipairs(recents) do
		if i >= 10 then
			break
		end
		print(i .. ": " .. file)
	end
	local choice = tonumber(vim.fn.input(""))
	if choice and recents[choice] then
		vim.cmd(tab_or_edit() .. recents[choice])
	end
end

local function set_comment_prefix(slashes)
	vim.keymap.set('n', '<leader>c', function()
		toggle_comment(slashes)
	end)
	vim.keymap.set('x', '<leader>c', ':lua toggle_comments("' .. slashes .. '")<cr>')
end

local function set_indent(indent)
	if indent:sub(1, 1) == " " then
		vim.opt.tabstop = #indent
		vim.opt.shiftwidth = #indent
		vim.opt.expandtab = true
	else
		vim.opt.tabstop = 4
		vim.opt.shiftwidth = 4
		vim.opt.expandtab = false
	end
end

local function set_filetype_settings(ft)
	if ft == "dosbatch" then
		set_comment_prefix("REM")
		vim.keymap.set('i', 'q<tab>', '(<esc>o)<esc>O')
		set_indent("  ")
	elseif ft == "lua" then
		set_comment_prefix("--")
		vim.keymap.set('i', 'q<tab>', '<esc>oend<esc>O')
		set_indent("\t")

		vim.api.nvim_create_user_command("F", function(opts)
			local row, col = unpack(vim.api.nvim_win_get_cursor(0))

			if #opts.args == 0 then
				local text = "\nlocal function ()\nend\n"
				local lines = vim.split(text, "\n")
				vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, lines)
				vim.api.nvim_win_set_cursor(0, { row + 1, 15 })
				vim.api.nvim_feedkeys("i", "n", true)
			else
				local text = "\nlocal function " .. opts.args .. "()\n\nend\n"
				local lines = vim.split(text, "\n")
				vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, lines)
				vim.api.nvim_win_set_cursor(0, { row + 2, 0 })
				vim.api.nvim_feedkeys("S", "n", true)
			end
		end, { nargs = "?" })
	elseif ft == "pascal" then
		set_comment_prefix("//")
		vim.keymap.set('i', 'q<tab>', 'begin<esc>oend;<esc>O')
		set_indent("  ")

		vim.api.nvim_create_user_command("En", function(opts)
			local row, col = unpack(vim.api.nvim_win_get_cursor(0))
			local text = "\ntype\n  " .. opts.args .. " = ();\n"
			local lines = vim.split(text, "\n")
			vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, lines)
			vim.api.nvim_win_set_cursor(0, { row + 2, 0 })
			vim.api.nvim_feedkeys("$hi", "n", true)
		end, { nargs = 1 })

		vim.api.nvim_create_user_command("F", function(opts)
			local row, col = unpack(vim.api.nvim_win_get_cursor(0))

			if #opts.args == 0 then
				local text = "\nfunction (): ;\nbegin\nend;\n"
				local lines = vim.split(text, "\n")
				vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, lines)
				vim.api.nvim_win_set_cursor(0, { row + 1, 9 })
				vim.api.nvim_feedkeys("i", "n", true)
			else
				local text = "\nfunction " .. opts.args .. "(): ;\nbegin\nend;\n"
				local lines = vim.split(text, "\n")
				vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, lines)
				vim.api.nvim_win_set_cursor(0, { row + 1, 0 })
				vim.api.nvim_feedkeys("$i", "n", true)
			end
		end, { nargs = "?" })
	elseif ft == "go" then
		set_comment_prefix("//")
		vim.keymap.set('i', 'q<tab>', '{<esc>o}<esc>O')
		set_indent("\t")
		vim.keymap.set('i', 'pl<tab>', 'fmt.Println()<esc>i')

		vim.api.nvim_create_user_command("En", function(opts)
			local row, col = unpack(vim.api.nvim_win_get_cursor(0))
			local text = "\ntype " .. opts.args .. " int\n\nconst (\n\t " .. opts.args .. " = iota\n)\n"
			local lines = vim.split(text, "\n")
			vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, lines)
			vim.api.nvim_win_set_cursor(0, { row + 4, 1 })
			vim.api.nvim_feedkeys("i", "n", true)
		end, { nargs = 1 })

		vim.api.nvim_create_user_command("F", function(opts)
			local row, col = unpack(vim.api.nvim_win_get_cursor(0))

			if #opts.args == 0 then
				local text = "\nfunc () {\n}\n"
				local lines = vim.split(text, "\n")
				vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, lines)
				vim.api.nvim_win_set_cursor(0, { row + 1, 5 })
				vim.api.nvim_feedkeys("i", "n", true)
			else
				local text = "\nfunc " .. opts.args .. "() {\n\n}\n"
				local lines = vim.split(text, "\n")
				vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, lines)
				vim.api.nvim_win_set_cursor(0, { row + 2, 0 })
				vim.api.nvim_feedkeys("S", "n", true)
			end
		end, { nargs = "?" })
	else
		-- For other languages assume // and {} and tabs for indentation.
		set_comment_prefix("//")
		vim.keymap.set('i', 'q<tab>', '{<esc>o}<esc>O')
		set_indent("\t")
	end
end

vim.api.nvim_create_user_command("E", function(opts)
	vim.cmd(tab_or_edit() .. opts.args)
end, { nargs = 1, complete = "file" })

vim.api.nvim_create_autocmd("BufEnter", {
	callback = function()
		local path = vim.fn.expand("%:p:h")
		vim.cmd("cd " .. path)
		local ft = vim.bo.filetype
		set_filetype_settings(ft)
	end
})

vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.hl.on_yank({
			higroup = "IncSearch",
			timeout = 200,
		})
	end
})

vim.lsp.config['gopls'] = {
	cmd = { "gopls" },
	filetypes = { "go" },
	root_markers = { "go.mod" },
}
vim.lsp.enable("gopls")

vim.lsp.config['mylsp'] = {
	cmd = { "lsp" },
	filetypes = { "test" },
}
vim.lsp.enable("mylsp")
