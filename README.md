# basecamp.yazi

Project-relative navigation for [yazi](https://yazi-rs.github.io/).

Register your project roots once, then jump between projects and navigate to common subdirectories with just a few keystrokes — no matter how deep you are in the file tree.

## Features

- **Project jumps** — Switch between registered projects in 3 keystrokes (`gp` + key), or fuzzy search with `Space`
- **Relative bookmarks** — Jump to common subdirectories relative to the current project root (`g.` + key)
- **Fuzzy search** — Filter bookmarks and projects with fzf (`Space` in any menu)
- **Recursive directory search** — Browse all subdirectories under the project root with fzf (`g.` + `/`)
- **Go to root** — Return to the project root from anywhere within it (`g.` + `.`)
- **Smart filtering** — Only bookmarks that exist in the current project are shown
- **Tab-independent** — Roots are resolved by path ancestry, so tab open/close never breaks anything
- **Git worktree jumps** — List and jump to git worktrees with fzf (`gw`), automatically registered as project roots
- **Dynamic roots** — Optionally register ad-hoc roots at runtime for unlisted projects

## Requirements

- [fzf](https://github.com/junegunn/fzf) — for fuzzy search features
- [fd](https://github.com/sharkdp/fd) — for recursive directory search (`g.` + `/`)
- [git](https://git-scm.com/) — for worktree listing (`gw`)

## Installation

```sh
ya pkg add yosagi/basecamp
```

Or clone manually into your yazi plugins directory:

```sh
git clone https://github.com/yosagi/basecamp.yazi.git ~/.config/yazi/plugins/basecamp.yazi
```

## Configuration

### init.lua

```lua
require("basecamp"):setup({
    projects = {
        { key = "n", path = "~/.config/nvim", desc = "nvim" },
        { key = "1", path = "~/work/project-alpha", desc = "Alpha" },
        { key = "2", path = "~/work/project-beta", desc = "Beta" },
    },
    bookmarks = {
        { key = "s", path = "src", desc = "Source" },
        { key = "t", path = "tests", desc = "Tests" },
        { key = "d", path = "docs", desc = "Docs" },
        { key = "g", path = ".github/workflows", desc = "CI workflows" },
        { key = "c", path = ".claude", desc = "Claude config" },
    },
})
```

You can freely define many bookmarks — only those that actually exist in the current project will appear in the menu. This means you can share one bookmark list across all projects without worrying about clutter.

### keymap.toml

```toml
[[mgr.prepend_keymap]]
on   = [ "g", "p" ]
run  = "plugin basecamp -- projects"
desc = "Jump to a project"

[[mgr.prepend_keymap]]
on   = [ "g", "." ]
run  = "plugin basecamp -- bookmarks"
desc = "Project-relative bookmarks"

# Optional: jump to a git worktree and set as project root
[[mgr.prepend_keymap]]
on   = [ "g", "w" ]
run  = "plugin basecamp -- worktrees"
desc = "Jump to a git worktree"

# Optional: dynamically register current directory as a root
[[mgr.prepend_keymap]]
on   = [ "g", "r" ]
run  = "plugin basecamp -- set"
desc = "Set/unset project root"
```

## Usage

### Jump to a project (`gp`)

Press `gp` to see all registered projects, then press the assigned key to jump:

```
gp → [SPC] Fuzzy search  [n] nvim  [1] Alpha  [2] Beta
```

- **`Space`** — Fuzzy search projects with fzf
- **Any project key** — Jump directly to that project

### Navigate within a project (`g.`)

Press `g.` anywhere inside a project to see bookmarks, plus built-in actions:

```
g. → [SPC] Fuzzy search bookmarks  [.] Go to root  [/] Relative cd...  [s] Source  [t] Tests ...
```

- **`Space`** — Fuzzy search existing bookmarks with fzf
- **`.`** — Jump to the project root
- **`/`** — Browse all subdirectories under the project root with fzf
- **Any bookmark key** — Jump to that subdirectory

### Jump to a git worktree (`gw`)

Press `gw` to list all git worktrees for the current repository and select one with fzf:

```
gw → fzf: master  /home/user/work/myproject
           feature /home/user/work/myproject-feature
```

The selected worktree is automatically registered as a project root, so `g.` bookmarks and root navigation work immediately after jumping.

### Dynamic roots (`gr`)

For directories not in your `projects` list, navigate there and press `gr` to register it as a temporary root. Press `gr` again at the same directory to unregister.

## How it works

Basecamp finds your current project by checking which registered root is the deepest ancestor of your working directory. This means:

- Nested projects work correctly (the most specific root wins)
- Multiple tabs in the same project share the same root
- Tab open/close has no effect on root resolution
- Bookmarks that don't exist in a particular project are automatically hidden from the menu

## License

MIT
