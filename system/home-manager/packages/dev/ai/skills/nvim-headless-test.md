---
name: nvim-headless-test
description: Use when modifying Neovim Lua configuration that affects window management, autocmds, buffer behavior, statusline, or any UI-observable behavior — and when debugging why an autocmd or window event fires unexpectedly. Runs the real config in a headless nvim so assertions reflect actual behavior.
---

# Neovim Headless Testing

## How to run

```bash
nvim --headless -u init.lua -c "luafile test_file.lua" 2>&1
```

## Writing a test script

1. Set a known screen size: `vim.o.columns = 160; vim.o.lines = 40`
2. Create windows/buffers programmatically via `nvim_create_buf`, `nvim_open_win`
3. Trigger autocmds by setting filetypes: `vim.bo[buf].filetype = 'name'`
4. Switch focus with `vim.api.nvim_set_current_win(win)`
5. After focus changes, call `vim.wait(200, function() return false end)` so `vim.schedule` callbacks execute
6. Emit state with `io.write()` / `io.flush()` to inspect it
7. Exit with `vim.cmd('qa!')`

## Gotchas

- Do **not** call `vim.cmd('doautocmd WinEnter')` after `nvim_set_current_win` — the API call already fires `WinEnter`. Doubling it causes stale-state bugs that look like race conditions.
- Delete the test script once debugging is done; leaving scratch `.lua` files around clutters the config.
