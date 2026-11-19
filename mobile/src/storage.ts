import AsyncStorage from "@react-native-async-storage/async-storage";
import { emptyQueue, type QueueState } from "./queue";

const KEY = "lawdesk.queue.v1";

export async function loadQueue(): Promise<QueueState> {
  try {
    const raw = await AsyncStorage.getItem(KEY);
    return raw ? (JSON.parse(raw) as QueueState) : emptyQueue();
  } catch {
    return emptyQueue();
  }
}

export async function saveQueue(state: QueueState): Promise<void> {
  await AsyncStorage.setItem(KEY, JSON.stringify(state));
}
