import type { Poster } from "./queue";

export const API_URL = process.env.EXPO_PUBLIC_API_URL ?? "http://localhost:3000";

export type Matter = { id: number; title: string; practice_area: string; status: string };

export async function fetchMatters(fetcher: typeof fetch = fetch): Promise<Matter[]> {
  const res = await fetcher(`${API_URL}/matters?status=open`);
  if (!res.ok) throw new Error(`Could not load matters (${res.status})`);
  return res.json();
}

export const post: Poster = (path, body) =>
  fetch(`${API_URL}${path}`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) });
