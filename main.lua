--- @since 25.5.31

-- basecamp.yazi - Project-relative navigation for yazi
--
-- Register project roots and navigate with relative bookmarks.
-- Roots are matched by path ancestry, independent of tabs.
--
-- Commands:
--   projects   : Jump to a registered project
--   bookmarks  : Navigate relative to current project root
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

			local cands = {}
			for _, p in ipairs(projects) do
				cands[#cands + 1] = { on = p.key, desc = p.desc }
			end

			local idx = ya.which { cands = cands }
			if idx then
				ya.emit("cd", { projects[idx].path })
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
				{ on = "<Space>", desc = "Go to root: " .. root },
				{ on = "/", desc = "Relative cd..." },
			}
			for _, bm in ipairs(bookmarks) do
				cands[#cands + 1] = { on = bm.key, desc = bm.desc or bm.path }
			end

			local idx = ya.which { cands = cands }
			if not idx then return end

			if idx == 1 then
				ya.emit("cd", { root })
			elseif idx == 2 then
				local value, event = ya.input {
					title = "cd (from " .. root .. "/)",
					pos = { "top-center", y = 3, w = 50 },
				}
				if event == 1 and value and value ~= "" then
					ya.emit("cd", { root .. "/" .. value })
				end
			else
				local bm = bookmarks[idx - 2]
				ya.emit("cd", { root .. "/" .. bm.path })
			end

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
