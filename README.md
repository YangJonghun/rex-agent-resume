<p align="center">
  English · <a href="README.ko.md">한국어</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS-666666?labelColor=333333" alt="Platform: macOS" />
</p>

# rex-agent-resume

> [!WARNING]
> Rex is in beta. Its server API, Lua runtime, and restore behavior can change in any release, so rex-agent-resume may stop working after a Rex update without warning.

When the [Rex](https://www.superlogical.com/rex) server restarts, Rex brings back your sessions, windows, and panes, but every pane comes back as an empty shell. Whatever ran in it is gone.

rex-agent-resume remembers what ran in each pane and starts it again in the same pane after the restart.

- **AI coding agents.** Claude Code, Codex, and 16 others reopen the conversation you had, with nothing to set up after the install.
- **Your own agents and tools.** Vim or any other program reopens too, once it registers the command that reopens it.

## Get started

1. Check your Rex version. You need a build with session restore, ge6592f (2026-10-30) or later, and this must print `8` or more:

   ```sh
   rex api call server.status | jq .api_revision
   ```

2. Install. It finds the agents on this machine, connects them, and connects Rex.

   ```sh
   curl -fsSL https://raw.githubusercontent.com/YangJonghun/rex-agent-resume/main/install.sh | sh
   ```

3. That's it. Use your agents in Rex panes as usual.

Run the same command again to update. To install a specific [release](https://github.com/YangJonghun/rex-agent-resume/releases), set its version:

```sh
curl -fsSL https://raw.githubusercontent.com/YangJonghun/rex-agent-resume/main/install.sh | REX_AGENT_RESUME_REF=v0.1.0-beta.1 sh
```

It needs `jq`, which macOS ships at `/usr/bin/jq`.

## Usage

It applies automatically once installed. Sessions already running when you install may not be picked up, so restart those once.

With the actions below you can turn automatic resume off, or remove the hooks and plugins added to your agents.

### Actions

Open the command palette with ⌘⇧P and search for `Agent Resume`, or run `rex do <name>`.

| Palette title                                                      | Name                     | What it does                                       |
| ------------------------------------------------------------------ | ------------------------ | -------------------------------------------------- |
| Turn Off Agent Resume on Startup / Turn On Agent Resume on Startup | `agent_resume_toggle`    | Turns reopening on restart off or on               |
| Uninstall rex-agent-resume                                         | `agent_resume_uninstall` | Removes the hooks, plugins, and Rex config         |
| Register Resume Command for This Pane                              | `agent_resume_hint`      | Used by programs to register their reopen command  |

If the server restarted while it was off, turning it back on reopens right away.

## How it works

With Claude Code as the example, it works in this order:

1. **At install.** Our script (`rex-agent-resume-hook`) is added to Claude Code's session-start hook.
2. **When you start or switch a conversation.** Claude Code runs the hook with the session id. Our script writes down "this pane runs `claude`, session `abc`". A new conversation overwrites it.
3. **While the server runs.** A watcher inside the Rex server saves the list of panes that have an agent in front: 2 seconds after a change in a pane, and every 5 minutes anyway. A pane where you quit the agent and are back at the shell drops off the list.
4. **When the server stops.** Nothing happens. The list saved in step 3 is what remains.
5. **When the server starts again.** Rex brings the panes back as empty shells, and the watcher reads the saved list and types `claude --resume abc` into each pane.

Only step 2 differs between agents. Most use a hook, and a few such as OpenCode use a plugin, to call our script. Vim and your own tools [tell it themselves](#register-your-own-agent-or-tool).

In short, snapshots are recorded while the Rex server runs, and read back and run when it starts again. Nothing has to happen at the moment it stops, so it also works after a forced kill or a crash.

## Register your own agent or tool

Vim and your own tools have no session-start hook, so the program does [step 2](#how-it-works) itself. When it starts, it writes down which command reopens it. Steps 3 to 5 then run as for AI agents, and after a restart that command is typed into the same pane. It takes one line:

```sh
rex do agent_resume_hint 'argv=["my-agent","--session","abc123"]'
```

- `argv` is the command, one word per item. Use absolute paths for files.
- **The program itself** must run it. Typed at a shell prompt, it fails, because there is no program to register.
- Run it again when the session changes. The last command registered wins.

**Example: Vim.** With this in `~/.vimrc`, Vim registers the files it opened each time it starts. After a restart, `vim /absolute/path/to/file` runs again in the same pane.

```vim
if !empty($REX_BLOCK)
  autocmd VimEnter * call system('rex do agent_resume_hint --args ' . shellescape(json_encode({'argv': ['vim'] + map(argv(), {_, f -> fnamemodify(f, ':p')})})))
endif
```

Only the files Vim started with reopen. Files opened later with `:e`, the cursor position, and window splits do not come back.

**Example: your own agent.** Run the command when you create or switch a session. In Node.js:

```js
import { execFile } from "node:child_process";

if (process.env.REX_BLOCK) {
  execFile("rex", ["do", "agent_resume_hint", "--args", JSON.stringify({ argv: ["my-agent", "--session", sessionId] })]);
}
```

`REX_BLOCK` is set only inside Rex panes, so outside Rex this does nothing.

## Limitations

**When nothing reopens**

- **A server started with `--restore=false`.** Rex does not bring the panes back, so rex-agent-resume does nothing. The same goes for Rex below API revision 8.
- **The first restart after updating from a Rex below API revision 8.** That server did not save panes, so none come back. It works from the next restart.
- **Codex without `--no-daemon`.** Codex sessions reopen only when Codex runs as `codex --no-daemon`. Otherwise Codex runs the session in its shared background server, outside the pane, so the session is not remembered.
- **Programs that were not in front when the server stopped.** If you quit the agent and were back at the shell, it does not reopen.
- **Sessions with no conversation yet.** A Claude Code or Codex session with no message sent has no transcript and would fail with "No conversation found", so it is skipped.
- **Old records.** Reopening happens only within 2 minutes of the server starting, and not at all if the last snapshot is older than 3 days.

**What is remembered**

- **Only the latest per pane.** Starting a new conversation or switching sessions in a pane replaces the earlier record. Open earlier conversations from the agent's own resume list, such as `claude --resume`.
- **Agents running before the install.** Claude Code, and agents with a session id on their command line, are picked up right away. Restart the others once after installing.
- **A few seconds of blind spot.** If the server dies within about 3 seconds after an agent starts, that agent is not remembered. Within about 2 seconds after you quit an agent, it reopens anyway.
- **No screen state.** Scrollback, cursor position, and half-typed input do not come back.

**Environment**

- **Start Rex from the app.** A Rex server started from inside Claude Code or Codex passes their variables to every pane, and Claude Code then stops saving transcripts. Reopened agents start without those variables, but agents you start yourself in those panes are affected.
- **Local server only.** Panes on remote Rex hosts are not reopened.

## Uninstall

Run **Uninstall rex-agent-resume** from the command palette, or:

```sh
curl -fsSL https://raw.githubusercontent.com/YangJonghun/rex-agent-resume/main/install.sh | sh -s uninstall
```

This also deletes `~/.local/share/rex-agent-resume`.

## Credits

The per-agent resume commands, hook and plugin rules, process detection, and install targets are ported from [herdr](https://github.com/herdrdev/herdr) v0.9.5, which is licensed under the Apache License 2.0.
