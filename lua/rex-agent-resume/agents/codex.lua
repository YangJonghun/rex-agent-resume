-- Rules ported from herdr v0.9.5 (src/agent_resume.rs, src/integration/).
return {
  resume = { "codex", "resume", "{id}" },
  launch_flags = { "--no-daemon" },
  transcript_fields = { "transcript_path" },
  transcript = "sessions/*/*/*/rollout-*-{id}.jsonl",
  replace_on = { "startup", "clear", "resume", "compact" },
  events = { "sessionstart", "" },
  id_fields = { "session_id" },
  require = { "transcript_path" },
  thread_env = "CODEX_THREAD_ID",
  install = {
    dir = { env = "CODEX_HOME", default = ".codex" },
    file = "hooks.json",
    lists = { { "hooks", "SessionStart" } },
    entry = function(cmd) return { hooks = { { type = "command", command = cmd, timeout = 10 } } } end,
    codex_features = true,
  },
}
