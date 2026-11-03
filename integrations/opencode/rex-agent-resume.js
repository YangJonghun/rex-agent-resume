// Installed by rex-agent-resume. Reports this pane's OpenCode session in `opencode run` and --mini;
// the full TUI reports through rex-agent-resume-tui.js instead.
import { spawn } from "node:child_process";

const HOOK = "__REX_AGENT_RESUME_HOOK__";
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

function ownsLocalLifecycle() {
  const args = process.argv.slice(2);
  const separator = args.indexOf("--");
  if (separator !== -1) args.splice(separator);
  if (args.some((arg) => arg === "--attach" || arg.startsWith("--attach="))) return false;
  while (args[0] === "--print-logs" || args[0] === "--log-level" || args[0]?.startsWith("--log-level=")) {
    args.splice(0, args[0] === "--log-level" ? 2 : 1);
  }
  return args[0] === "run" || (!["serve", "web", "attach"].includes(args[0]) && args.includes("--mini"));
}

export const RexAgentResumePlugin = async () => {
  if (!ownsLocalLifecycle() || !process.env.REX_BLOCK) return {};
  const children = new Set();
  const seen = (sessionId) => {
    if (!children.has(sessionId)) report(sessionId);
  };
  return {
    "chat.message": async ({ sessionID }) => seen(sessionID),
    event: async ({ event }) => {
      const properties = event?.properties ?? {};
      if (properties.info?.id && properties.info.parentID) children.add(properties.info.id);
      if (event?.type === "session.updated" || event?.type === "session.status") seen(properties.sessionID);
    },
  };
};

export default {
  id: "rex-agent-resume.opencode",
  server: RexAgentResumePlugin,
  setup() {},
};
