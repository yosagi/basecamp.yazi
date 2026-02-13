# basecamp.yazi

Project-relative navigation for [yazi](https://yazi-rs.github.io/).

Register your project roots once, then jump between projects and navigate to common subdirectories with just a few keystrokes — no matter how deep you are in the file tree.

## Features

- **Project jumps** — Switch between registered projects in 3 keystrokes (`gp` + key)
- **Relative bookmarks** — Jump to common subdirectories relative to the current project root (`g.` + key)
- **Go to root** — Return to the project root from anywhere within it (`g.` + `Space`)
- **Freeform relative cd** — Type any relative path to navigate from the project root (`g.` + `/`)
- **Tab-independent** — Roots are resolved by path ancestry, so tab open/close never breaks anything
- **Dynamic roots** — Optionally register ad-hoc roots at runtime for unlisted projects

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
gp → [n] nvim  [1] Alpha  [2] Beta
```

### Navigate within a project (`g.`)

Press `g.` anywhere inside a project to see bookmarks, plus built-in actions:

```
g. → [SPC] Go to root  [/] Relative cd...  [s] Source  [t] Tests  [d] Docs ...
```

- **`Space`** — Jump to the project root
- **`/`** — Type a relative path (e.g. `src/components`)
- **Any bookmark key** — Jump to that subdirectory

### Dynamic roots (`gr`)

For directories not in your `projects` list, navigate there and press `gr` to register it as a temporary root. Press `gr` again at the same directory to unregister.

## How it works

Basecamp finds your current project by checking which registered root is the deepest ancestor of your working directory. This means:

- Nested projects work correctly (the most specific root wins)
- Multiple tabs in the same project share the same root
- Tab open/close has no effect on root resolution
- Bookmarks that don't exist in a particular project simply fail gracefully

## License

MIT
