// Installed by rex-agent-resume. Reports this pane's pi session so it can be resumed after a Rex restart.
import { spawn } from "node:child_process";
import path from "node:path";

const HOOK = "__REX_AGENT_RESUME_HOOK__";
let last: string | undefined;

function report(sessionRef: string | undefined, source?: string) {
  if (!process.env.REX_BLOCK || !sessionRef) return;
  const key = `${sessionRef}\n${source ?? ""}`;
  if (key === last) return;
  last = key;
  try {
    const child = spawn(HOOK, ["pi"], { stdio: ["pipe", "ignore", "ignore"] });
    child.on("error", () => {});
    child.stdin.on("error", () => {});
    child.stdin.end(JSON.stringify({ hook_event_name: "SessionStart", session_id: sessionRef, source }));
    child.unref();
  } catch {}
}

function sessionRef(ctx: any): string | undefined {
  try {
    const file = ctx?.sessionManager?.getSessionFile?.();
    if (typeof file === "string" && path.isAbsolute(file)) return file;
  } catch {}
  try {
    const id = ctx?.sessionManager?.getSessionId?.();
    if (typeof id === "string" && id) return id;
  } catch {}
  return undefined;
}

export default function (pi) {
  if (!process.env.REX_BLOCK) return;
  let root = false;

  pi.on("session_start", (event, ctx) => {
    if (ctx?.mode !== "tui") return;
    root = true;
    report(sessionRef(ctx), event?.reason);
  });

  pi.on("agent_start", (_event, ctx) => {
    if (root) report(sessionRef(ctx));
  });
}
