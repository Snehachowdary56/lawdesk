import { emptyQueue, enqueue, flush, type PendingEntry, type Poster } from "../src/queue";

const entry = (ref: string, matter_id = 1): PendingEntry => ({
  client_ref: ref, matter_id, worked_on: "2027-01-10", minutes: 12, rate_cents: 25000, description: "Draft letter",
});
const reply = (status: number, body: unknown = {}) => ({ status, json: async () => body });

test("the same entry is never queued twice", () => {
  const q = enqueue(enqueue(emptyQueue(), entry("a")), entry("a"));
  expect(q.pending).toHaveLength(1);
});

test("syncs everything when online", async () => {
  const post: Poster = jest.fn(async () => reply(201));
  const { state, sent, offline } = await flush(enqueue(enqueue(emptyQueue(), entry("a")), entry("b")), post);
  expect([sent, offline, state.pending.length]).toEqual([2, false, 0]);
  expect(post).toHaveBeenCalledWith("/matters/1/time_entries", { time_entry: entry("a") });
});

test("keeps entries on the phone when the network is down", async () => {
  const post: Poster = async () => { throw new Error("Network request failed"); };
  const { state, offline } = await flush(enqueue(emptyQueue(), entry("a")), post);
  expect(offline).toBe(true);
  expect(state.pending).toHaveLength(1);
});

test("stops on a server error and resumes later without losing order", async () => {
  const replies = [reply(201), reply(503)];
  const post: Poster = async () => replies.shift()!;
  const q = [entry("a"), entry("b"), entry("c")].reduce(enqueue, emptyQueue());
  const { state, sent } = await flush(q, post);
  expect(sent).toBe(1);
  expect(state.pending.map((e) => e.client_ref)).toEqual(["b", "c"]);
});

test("a rejected entry moves to failed and does not block the rest", async () => {
  const replies = [reply(422, { error: "Validation failed" }), reply(201)];
  const post: Poster = async () => replies.shift()!;
  const { state, sent } = await flush([entry("bad"), entry("good")].reduce(enqueue, emptyQueue()), post);
  expect(sent).toBe(1);
  expect(state.failed).toEqual([{ entry: entry("bad"), error: "Validation failed" }]);
});

test("a retried entry the server already has counts as sent (200)", async () => {
  const { sent, state } = await flush(enqueue(emptyQueue(), entry("a")), async () => reply(200));
  expect([sent, state.pending.length]).toEqual([1, 0]);
});
