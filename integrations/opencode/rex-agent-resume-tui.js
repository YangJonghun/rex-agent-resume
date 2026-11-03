// Installed by rex-agent-resume. Reports the session selected in this pane's OpenCode TUI.
import { spawn } from "node:child_process";

const HOOK = "__REX_AGENT_RESUME_HOOK__";
const POLL_MS = 250;
let last;

function report(sessionId, source) {
  if (!process.env.REX_BLOCK || typeof sessionId !== "string" || !sessionId) return;
  const key = `${sessionId}\n${source ?? ""}`;
  if (key === last) return;
  last = key;
  try {
    const child = spawn(HOOK, ["opencode"], { stdio: ["pipe", "ignore", "ignore"] });
    child.on("error", () => {});
    child.stdin.on("error", () => {});
    child.stdin.end(JSON.stringify({ hook_event_name: "SessionStart", session_id: sessionId, source }));
    child.unref();
  } catch {}
}

export default {
  id: "rex-agent-resume.opencode.session-selection",
  setup,
  tui,
};

// OpenCode 1.x.
async function tui(api) {
  if (!process.env.REX_BLOCK) return;
  let route;
  let owner;

  async function parentOf(id) {
    const cached = api.state?.session?.get?.(id);
    if (cached) return cached.parentID;
    const result = await api.client.session.get({ sessionID: id }, { throwOnError: true, signal: AbortSignal.timeout(5_000) });
    return result?.data?.parentID;
  }

  async function within(id, ancestor) {
    const seen = new Set();
    while (typeof id === "string" && !seen.has(id)) {
      if (id === ancestor) return true;
      seen.add(id);
      id = await parentOf(id);
    }
    return false;
  }

  async function sync() {
    const current = api.route.current;
    const id = current?.name === "session" ? current.params?.sessionID : undefined;
    if (!id) {
      route = owner = undefined;
      return;
    }
    if (id === route) return;
    route = id;
    try {
      if (owner && await within(id, owner)) return;
      if (route !== id) return;
      owner = id;
      report(id, "select");
    } catch {
      if (route === id) route = undefined;
    }
  }

  const timer = setInterval(() => void sync(), POLL_MS);
  api.lifecycle?.onDispose?.(() => clearInterval(timer));
  void sync();
}

// OpenCode 2.x.
function setup(api) {
  if (!process.env.REX_BLOCK) return;
  const parents = new Map();
  const unsubscribe = api.data.listen(({ details: event }) => {
    if (event?.type === "session.created" && event.data) parents.set(event.data.sessionID, event.data.parentID);
  });

  function root(id) {
    const seen = new Set();
    while (typeof id === "string" && !seen.has(id)) {
      seen.add(id);
      const session = api.data.session.get(id) ?? (parents.has(id) ? { parentID: parents.get(id) } : undefined);
      if (!session) return undefined;
      if (!session.parentID) return id;
      id = session.parentID;
    }
    return undefined;
  }

  const sync = () => {
    const current = api.ui.router.current();
    if (current?.type === "session") report(root(current.sessionID), "select");
  };
  const timer = setInterval(sync, POLL_MS);
  sync();
  return () => {
    clearInterval(timer);
    unsubscribe?.();
  };
}
