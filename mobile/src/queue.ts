// Offline-first time entries: every entry is saved on the phone first, then synced to the API.
// Each entry carries a client_ref (unique id), so if the phone retries after a lost reply, the API
// recognises it and does not create a second entry.

export type PendingEntry = {
  client_ref: string;
  matter_id: number;
  worked_on: string; // YYYY-MM-DD
  minutes: number;
  rate_cents: number;
  description: string;
};

export type QueueState = { pending: PendingEntry[]; failed: { entry: PendingEntry; error: string }[] };

export type Poster = (path: string, body: unknown) => Promise<{ status: number; json: () => Promise<any> }>;

export const emptyQueue = (): QueueState => ({ pending: [], failed: [] });

export function enqueue(state: QueueState, entry: PendingEntry): QueueState {
  if (state.pending.some((e) => e.client_ref === entry.client_ref)) return state;
  return { ...state, pending: [...state.pending, entry] };
}

// Sends entries in order. Network errors and server errors (5xx) stop the sync and keep the entries for
// later; validation errors (4xx) move that entry to `failed` so it does not block the rest.
export async function flush(state: QueueState, post: Poster): Promise<{ state: QueueState; sent: number; offline: boolean }> {
  const pending = [...state.pending];
  const failed = [...state.failed];
  let sent = 0;
  while (pending.length) {
    const entry = pending[0];
    let res;
    try {
      res = await post(`/matters/${entry.matter_id}/time_entries`, { time_entry: entry });
    } catch {
      return { state: { pending, failed }, sent, offline: true };
    }
    if (res.status >= 500) return { state: { pending, failed }, sent, offline: true };
    pending.shift();
    if (res.status === 200 || res.status === 201) {
      sent += 1;
    } else {
      const body = await res.json().catch(() => ({}));
      failed.push({ entry, error: body?.error ?? `HTTP ${res.status}` });
    }
  }
  return { state: { pending, failed }, sent, offline: false };
}

export function newRef(now = Date.now(), rand = Math.random): string {
  return `${now.toString(36)}-${Math.floor(rand() * 1e9).toString(36)}`;
}
