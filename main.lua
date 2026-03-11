--- @since 25.5.31

-- basecamp.yazi - Project-relative navigation for yazi
--
-- Register project roots and navigate with relative bookmarks.
-- Roots are matched by path ancestry, independent of tabs.
--
-- Commands:
--   projects   : Jump to a registered project (Space for fzf search)
--   bookmarks  : Navigate relative to current project root (Space for fzf)
--   worktrees  : Jump to a git worktree (fzf) and set as temporary root
--   root       : Jump to current project root
--   set        : Dynamically register/unregister current directory as root

local get_state = ya.sync(function(state, key) return state[key] end)
local set_state = ya.sync(function(state, key, val) state[key] = val end)
local get_cwd = ya.sync(function() return tostring(cx.active.current.cwd) end)

local function normalize(path)
	if #path > 1 and path:sub(-1) == "/" then
		return path:sub(1, -2)
	end
	return path
end

local function expand_home(path)
	if path:sub(1, 1) == "~" then
		return os.getenv("HOME") .. path:sub(2)
	end
	return path
end

-- Check if cwd is within (or equal to) root
local function is_within(cwd, root)
	return cwd == root or (cwd:sub(1, #root) == root and cwd:sub(#root + 1, #root + 1) == "/")
end

-- Find the deepest registered root that is an ancestor of cwd
local function find_root(roots, cwd)
	local best, best_len = nil, 0
	for root in pairs(roots) do
		if is_within(cwd, root) and #root > best_len then
			best = root
			best_len = #root
		end
	end
	return best
end

local function notify_no_root()
	ya.notify { title = "Basecamp", content = "No project root found (use projects to jump)", timeout = 3, level = "warn" }
end

-- fzf でプロジェクト一覧を絞り込み選択
local function select_project_fuzzy(projects)
	local permit = ui.hide()
	local input_lines = {}
	for _, p in ipairs(projects) do
		local cha = fs.cha(Url(p.path), true)
		if cha and cha.is_dir then
			input_lines[#input_lines + 1] = p.desc .. "\t" .. p.path
		end
	end

	if #input_lines == 0 then
		permit:drop()
		ya.notify { title = "Basecamp", content = "No existing projects found", timeout = 3, level = "warn" }
		return nil
	end

	local child = Command("fzf")
		:arg("--prompt"):arg("Project > ")
		:stdin(Command.PIPED):stdout(Command.PIPED):stderr(Command.INHERIT)
		:spawn()
	if not child then
		permit:drop()
		return nil
	end

	child:write_all(table.concat(input_lines, "\n"))
	child:flush()
	local output = child:wait_with_output()
	permit:drop()

	if not output or not output.status.success then return nil end
	local selected = output.stdout:gsub("[\r\n]+$", "")
	local path = selected:match("\t(.+)$")
	return path
end

-- fzf で登録済みブックマークを絞り込み選択（実在するもののみ）
local function select_bookmark_fuzzy(bookmarks, root)
	local permit = ui.hide()
	local input_lines = {}
	for _, bm in ipairs(bookmarks) do
		local full_path = root .. "/" .. bm.path
		local cha = fs.cha(Url(full_path), true)
		if cha and cha.is_dir then
			local desc = bm.desc or bm.path
			input_lines[#input_lines + 1] = desc .. "\t" .. bm.path
		end
	end

	if #input_lines == 0 then
		permit:drop()
		ya.notify { title = "Basecamp", content = "No existing bookmarks found", timeout = 3, level = "warn" }
		return nil
	end

	local child = Command("fzf")
		:arg("--prompt"):arg("Bookmark > ")
		:stdin(Command.PIPED):stdout(Command.PIPED):stderr(Command.INHERIT)
		:spawn()
	if not child then
		permit:drop()
		return nil
	end

	child:write_all(table.concat(input_lines, "\n"))
	child:flush()
	local output = child:wait_with_output()
	permit:drop()

	if not output or not output.status.success then return nil end
	local selected = output.stdout:gsub("[\r\n]+$", "")
	local rel_path = selected:match("\t(.+)$")
	if rel_path then return root .. "/" .. rel_path end
	return nil
end

-- git worktree list --porcelain をパースして worktree 一覧を返す
local function list_worktrees()
	local child = Command("git")
		:arg("worktree"):arg("list"):arg("--porcelain")
		:stdout(Command.PIPED):stderr(Command.PIPED)
		:spawn()
	if not child then return nil end

	local output = child:wait_with_output()
	if not output or not output.status.success then return nil end

	local worktrees = {}
	local current = nil
	for line in output.stdout:gmatch("[^\n]+") do
		local path = line:match("^worktree (.+)")
		local branch = line:match("^branch refs/heads/(.+)")
		local bare = line:match("^bare$")
		local detached = line:match("^HEAD (.+)")
		if path then
			-- 新しい worktree エントリ開始 → 前のエントリを確定
			if current then
				if not current.branch and current.head then
					current.branch = current.head:sub(1, 8) .. "..."
				end
				worktrees[#worktrees + 1] = current
			end
			current = { path = normalize(path) }
		elseif current and branch then
			current.branch = branch
		elseif current and bare then
			current.branch = "(bare)"
		elseif current and detached then
			current.head = detached
		end
	end
	-- 最後のエントリ
	if current then
		if not current.branch and current.head then
			current.branch = current.head:sub(1, 8) .. "..."
		end
		worktrees[#worktrees + 1] = current
	end
	return worktrees
end

-- fzf で git worktree を選択
local function select_worktree_fuzzy(worktrees)
	local permit = ui.hide()
	local input_lines = {}
	for _, wt in ipairs(worktrees) do
		local label = (wt.branch or "detached") .. "\t" .. wt.path
		input_lines[#input_lines + 1] = label
	end

	local child = Command("fzf")
		:arg("--prompt"):arg("Worktree > ")
		:stdin(Command.PIPED):stdout(Command.PIPED):stderr(Command.INHERIT)
		:spawn()
	if not child then
		permit:drop()
		return nil
	end

	child:write_all(table.concat(input_lines, "\n"))
	child:flush()
	local output = child:wait_with_output()
	permit:drop()

	if not output or not output.status.success then return nil end
	local selected = output.stdout:gsub("[\r\n]+$", "")
	local path = selected:match("\t(.+)$")
	return path
end

-- fzf でプロジェクトルート以下のディレクトリを選択
local function select_relative_fuzzy(root)
	local short = root:match("[^/]+$") or root
	local cmd = string.format(
		"(fd --type d --no-ignore --exclude .git --base-directory '%s' 2>/dev/null || fdfind --type d --no-ignore --exclude .git --base-directory '%s' 2>/dev/null) | fzf --prompt='%s/ > '",
		root, root, short
	)
	local permit = ui.hide()
	local child = Command("sh")
		:arg("-c"):arg(cmd)
		:stdin(Command.INHERIT):stdout(Command.PIPED):stderr(Command.INHERIT)
		:spawn()
	if not child then
		permit:drop()
		return nil
	end

	local output = child:wait_with_output()
	permit:drop()

	if not output or not output.status.success or output.stdout == "" then return nil end
	local target = output.stdout:gsub("\n$", "")
	return root .. "/" .. target
end

return {
	setup = function(state, opts)
		state.bookmarks = opts and opts.bookmarks or {}

		local projects = {}
		local roots = {}
		for _, p in ipairs(opts and opts.projects or {}) do
			local path = normalize(expand_home(p.path))
			projects[#projects + 1] = { key = p.key, path = path, desc = p.desc or path }
			roots[path] = true
		end
		state.projects = projects
		state.roots = roots
	end,

	entry = function(_, job)
		local cmd = job.args[1]

		if cmd == "projects" then
			local projects = get_state("projects") or {}
			if #projects == 0 then
				ya.notify { title = "Basecamp", content = "No projects registered", timeout = 3, level = "warn" }
				return
			end

			local cands = {
				{ on = "<Space>", desc = "Fuzzy search" },
			}
			for _, p in ipairs(projects) do
				local cha = fs.cha(Url(p.path), true)
				if cha and cha.is_dir then
					cands[#cands + 1] = { on = p.key, desc = p.desc }
				end
			end

			local idx = ya.which { cands = cands }
			if not idx then return end

			if idx == 1 then
				local path = select_project_fuzzy(projects)
				if path then ya.emit("cd", { path }) end
			else
				local p = projects[idx - 1]
				if p then ya.emit("cd", { p.path }) end
			end

		elseif cmd == "bookmarks" then
			local roots = get_state("roots") or {}
			local cwd = normalize(get_cwd())
			local root = find_root(roots, cwd)
			if not root then
				notify_no_root()
				return
			end

			local bookmarks = get_state("bookmarks") or {}
			local cands = {
				{ on = "<Space>", desc = "Fuzzy search bookmarks", action = "fuzzy" },
				{ on = ".", desc = "Go to root: " .. root, action = "root" },
				{ on = "/", desc = "Relative cd (recursive)...", action = "relative" },
			}
			for _, bm in ipairs(bookmarks) do
				local full_path = root .. "/" .. bm.path
				local cha = fs.cha(Url(full_path), true)
				if cha and cha.is_dir then
					cands[#cands + 1] = { on = bm.key, desc = bm.desc or bm.path, action = "bookmark", path = bm.path }
				end
			end

			local idx = ya.which { cands = cands }
			if not idx then return end

			local selected = cands[idx]
			if selected.action == "fuzzy" then
				local path = select_bookmark_fuzzy(bookmarks, root)
				if path then ya.emit("cd", { path }) end
			elseif selected.action == "root" then
				ya.emit("cd", { root })
			elseif selected.action == "relative" then
				local path = select_relative_fuzzy(root)
				if path then ya.emit("cd", { path }) end
			elseif selected.action == "bookmark" then
				ya.emit("cd", { root .. "/" .. selected.path })
			end

		elseif cmd == "worktrees" then
			local worktrees = list_worktrees()
			if not worktrees or #worktrees == 0 then
				ya.notify { title = "Basecamp", content = "No git worktrees found", timeout = 3, level = "warn" }
				return
			end

			local path = select_worktree_fuzzy(worktrees)
			if path then
				-- roots に追加して cd
				local roots = get_state("roots") or {}
				roots[path] = true
				set_state("roots", roots)
				ya.emit("cd", { path })
			end

		elseif cmd == "root" then
			local roots = get_state("roots") or {}
			local cwd = normalize(get_cwd())
			local root = find_root(roots, cwd)
			if not root then
				notify_no_root()
				return
			end
			ya.emit("cd", { root })

		elseif not cmd or cmd == "set" then
			local roots = get_state("roots") or {}
			local cwd = normalize(get_cwd())
			if roots[cwd] then
				roots[cwd] = nil
				ya.notify { title = "Basecamp", content = "Removed: " .. cwd, timeout = 3, level = "info" }
			else
				roots[cwd] = true
				ya.notify { title = "Basecamp", content = "Set: " .. cwd, timeout = 3, level = "info" }
			end
			set_state("roots", roots)
		end
	end,
}
