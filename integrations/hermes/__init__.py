"""Installed by rex-agent-resume. Reports this pane's Hermes session so it can be resumed after a Rex restart."""

import json
import os
import subprocess

HOOK = "__REX_AGENT_RESUME_HOOK__"
_INTERACTIVE_PLATFORMS = {"cli", "tui", "desktop", "acp"}
_last = None


def _report(source, **kwargs):
    global _last
    if not os.environ.get("REX_BLOCK") or kwargs.get("platform") not in _INTERACTIVE_PLATFORMS:
        return
    session_id = kwargs.get("session_id")
    if not isinstance(session_id, str) or not session_id or (session_id, source) == _last:
        return
    _last = (session_id, source)
    payload = json.dumps({"hook_event_name": "SessionStart", "session_id": session_id, "source": source})
    try:
        child = subprocess.Popen([HOOK, "hermes"], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        child.stdin.write(payload.encode())
        child.stdin.close()
    except Exception:
        pass


def _session_started(**kwargs):
    _report("startup", **kwargs)


def _session_reset(**kwargs):
    _report("new", **kwargs)


def _session_observed(**kwargs):
    if kwargs.get("platform") == "cli":
        _report("resume", **kwargs)


def register(ctx):
    ctx.register_hook("on_session_start", _session_started)
    ctx.register_hook("on_session_reset", _session_reset)
    ctx.register_hook("pre_llm_call", _session_observed)
