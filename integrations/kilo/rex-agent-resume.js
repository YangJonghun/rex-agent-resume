// Installed by rex-agent-resume. Reports this pane's Kilo session so it can be resumed after a Rex restart.
import { spawn } from "node:child_process";

const HOOK = "__REX_AGENT_RESUME_HOOK__";
let last;

function report(sessionId, source) {
  if (!process.env.REX_BLOCK || typeof sessionId !== "string" || !sessionId) return;
  const key = `${sessionId}\n${source ?? ""}`;
  if (key === last) return;
  last = key;
  try {
    const child = spawn(HOOK, ["kilo"], { stdio: ["pipe", "ignore", "ignore"] });
    child.on("error", () => {});
    child.stdin.on("error", () => {});
    child.stdin.end(JSON.stringify({ hook_event_name: "SessionStart", session_id: sessionId, source }));
    child.unref();
  } catch {}
}

export const RexAgentResumePlugin = async () => {
  if (!process.env.REX_BLOCK) return {};
  return {
    "chat.message": async ({ sessionID }) => report(sessionID, "startup"),
    event: async ({ event }) => report(event?.properties?.sessionID, "startup"),
  };
};
