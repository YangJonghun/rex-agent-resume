// Installed by rex-agent-resume. Reports this pane's omp session so it can be resumed after a Rex restart.
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
    const child = spawn(HOOK, ["omp"], { stdio: ["pipe", "ignore", "ignore"] });
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
  // omp sets OMPCODE=1 in every shell it spawns, so an omp started from one is not the pane's agent.
  if (!process.env.REX_BLOCK || process.env.OMPCODE === "1") return;
  let root = false;

  function activate(ctx: any, source = "startup"): boolean {
    if (ctx?.hasUI !== true) return false;
    root = true;
    report(sessionRef(ctx), source);
    return true;
  }

  pi.on("session_start", (_event, ctx) => {
    activate(ctx);
  });

  pi.on("session_switch", (event, ctx) => {
    activate(ctx, event?.reason || "resume");
  });

  pi.on("agent_start", (_event, ctx) => {
    if (root || activate(ctx)) report(sessionRef(ctx), "startup");
  });
}
