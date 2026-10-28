import { useAuth } from "@clerk/clerk-react";
import { useCallback, useEffect, useRef, useState } from "react";
import { fixtureEnabled } from "../devFixture";
import { listSessions, sendMessage } from "../gateway";

/** The app asks for a goal's view this many times before it leaves the rest to the person's own button. */
const MAX_ATTEMPTS = 2;
const TICK_MS = 4000;
/** A request the assistant has had this long without producing a view is counted as failed. */
const GIVE_UP_MS = 3 * 60_000;

const attemptsKey = (goalId: string) => `goalView.attempts.${goalId}`;

function readAttempts(goalId: string): number {
  try {
    return Number(localStorage.getItem(attemptsKey(goalId)) ?? 0) || 0;
  } catch {
    return 0;
  }
}

function writeAttempts(goalId: string, n: number) {
  try {
    if (n > 0) localStorage.setItem(attemptsKey(goalId), String(n));
    else localStorage.removeItem(attemptsKey(goalId));
  } catch {
    // The count is only a brake on asking again; without storage the page asks at most once per visit.
  }
}

/**
 * A goal with no view gets one composed: the page asks the assistant itself, once the main conversation is idle (a
 * message sent mid-reply would interrupt it), then reads the goal until the view appears. It asks at most twice in all;
 * after that `composing` is false and the person's own button is what is left.
 */
export function useAutoComposeView(options: {
  goalId: string;
  prompt: string;
  /** The goal's view has been read, and it is known whether it has one. */
  ready: boolean;
  hasView: boolean;
  refetch: () => unknown;
}) {
  const { goalId, prompt, ready, hasView, refetch } = options;
  const { getToken } = useAuth();
  const [composing, setComposing] = useState(false);
  const startedAt = useRef<number | null>(null);
  const busy = useRef(false);

  useEffect(() => {
    if (hasView) {
      startedAt.current = null;
      writeAttempts(goalId, 0);
    }
  }, [hasView, goalId]);

  const request = useCallback(async () => {
    if (busy.current) return;
    busy.current = true;
    try {
      const sessions = await listSessions(() => getToken());
      if (sessions.find((s) => !s.parent_session_id)?.is_running) return;
      writeAttempts(goalId, readAttempts(goalId) + 1);
      await sendMessage(() => getToken(), prompt, crypto.randomUUID());
      startedAt.current = Date.now();
      setComposing(true);
    } catch {
      // Not sent: the next tick tries again, and the attempt count only rose if the send was made.
    } finally {
      busy.current = false;
    }
  }, [getToken, goalId, prompt]);

  useEffect(() => {
    if (!ready || hasView || fixtureEnabled()) return;
    const tick = () => {
      if (startedAt.current !== null) {
        if (Date.now() - startedAt.current < GIVE_UP_MS) {
          void refetch();
          return;
        }
        startedAt.current = null;
        setComposing(false);
      }
      if (readAttempts(goalId) < MAX_ATTEMPTS) void request();
    };
    tick();
    const id = window.setInterval(tick, TICK_MS);
    return () => window.clearInterval(id);
  }, [ready, hasView, goalId, refetch, request]);

  /** The person's own button: forgets the earlier tries and asks again. */
  const again = useCallback(() => {
    writeAttempts(goalId, 0);
    startedAt.current = null;
    setComposing(false);
    void request();
  }, [goalId, request]);

  return { composing: composing && !hasView, again };
}
