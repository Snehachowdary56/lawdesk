import { useCallback, useEffect, useRef, useState } from "react";
import { FlatList, Pressable, SafeAreaView, StyleSheet, Text, TextInput, View } from "react-native";
import { fetchMatters, post as apiPost, type Matter } from "./src/api";
import { billableMinutes, formatClock, hours } from "./src/billing";
import { emptyQueue, enqueue, flush, newRef, type Poster, type QueueState } from "./src/queue";
import { loadQueue, saveQueue } from "./src/storage";

type Props = {
  loadMatters?: () => Promise<Matter[]>;
  poster?: Poster;
  now?: () => number;
  rateCents?: number;
};

export default function App({ loadMatters = fetchMatters, poster = apiPost, now = Date.now, rateCents = 25000 }: Props) {
  const [matters, setMatters] = useState<Matter[]>([]);
  const [selected, setSelected] = useState<Matter | null>(null);
  const [startedAt, setStartedAt] = useState<number | null>(null);
  const [elapsed, setElapsed] = useState(0);
  const [description, setDescription] = useState("");
  const [queue, setQueue] = useState<QueueState>(emptyQueue());
  const [message, setMessage] = useState<string | null>(null);
  const tick = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    loadMatters().then(setMatters).catch((e: Error) => setMessage(e.message));
    loadQueue().then(setQueue);
  }, [loadMatters]);

  useEffect(() => {
    if (startedAt === null) return;
    tick.current = setInterval(() => setElapsed(now() - startedAt), 1000);
    return () => {
      if (tick.current) clearInterval(tick.current);
    };
  }, [startedAt, now]);

  const update = useCallback((next: QueueState) => {
    setQueue(next);
    saveQueue(next);
  }, []);

  const start = () => {
    setStartedAt(now());
    setElapsed(0);
    setMessage(null);
  };

  const stop = () => {
    if (startedAt === null || !selected) return;
    const minutes = billableMinutes(now() - startedAt);
    setStartedAt(null);
    setElapsed(0);
    const d = new Date(now());
    const worked_on = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
    update(enqueue(queue, { client_ref: newRef(), matter_id: selected.id, worked_on, minutes, rate_cents: rateCents,
                            description: description.trim() || "Work on matter" }));
    setDescription("");
    setMessage(`Saved ${hours(minutes)} h on ${selected.title}. It will sync when you are online.`);
  };

  const sync = async () => {
    const result = await flush(queue, poster);
    update(result.state);
    const plural = (n: number) => `${n} ${n === 1 ? "entry" : "entries"}`;
    setMessage(result.offline ? `Offline: ${plural(result.state.pending.length)} kept on this phone.` : `Synced ${plural(result.sent)}.`);
  };

  const running = startedAt !== null;
  return (
    <SafeAreaView style={styles.screen}>
      <Text style={styles.h1}>LawDesk Time</Text>
      <Text style={styles.label}>Matter</Text>
      <FlatList
        data={matters}
        keyExtractor={(m) => String(m.id)}
        style={styles.list}
        renderItem={({ item }) => (
          <Pressable
            accessibilityRole="button"
            accessibilityState={{ selected: selected?.id === item.id }}
            onPress={() => !running && setSelected(item)}
            style={[styles.matter, selected?.id === item.id && styles.selected]}
          >
            <Text style={styles.matterTitle}>{item.title}</Text>
            <Text style={styles.muted}>{item.practice_area}</Text>
          </Pressable>
        )}
      />
      <Text accessibilityLabel="timer" style={styles.clock}>{formatClock(elapsed)}</Text>
      <TextInput
        accessibilityLabel="What are you working on?"
        placeholder="What are you working on?"
        value={description}
        onChangeText={setDescription}
        style={styles.input}
      />
      <Pressable
        accessibilityRole="button"
        disabled={!selected}
        onPress={running ? stop : start}
        style={[styles.button, !selected && styles.disabled]}
      >
        <Text style={styles.buttonText}>{running ? "Stop and save" : selected ? "Start timer" : "Choose a matter first"}</Text>
      </Pressable>
      <View style={styles.row}>
        <Text style={styles.muted}>{queue.pending.length} waiting to sync · {queue.failed.length} need attention</Text>
        <Pressable accessibilityRole="button" onPress={sync} disabled={queue.pending.length === 0}>
          <Text style={styles.link}>Sync now</Text>
        </Pressable>
      </View>
      {message && <Text accessibilityRole="alert" style={styles.message}>{message}</Text>}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, padding: 20, backgroundColor: "#f8fafc" },
  h1: { fontSize: 24, fontWeight: "700", marginBottom: 12, color: "#0f172a" },
  label: { fontWeight: "600", marginBottom: 6 },
  list: { maxHeight: 220, marginBottom: 12 },
  matter: { padding: 12, borderRadius: 8, borderWidth: 1, borderColor: "#e2e8f0", backgroundColor: "#fff", marginBottom: 6 },
  selected: { borderColor: "#1d4ed8", borderWidth: 2 },
  matterTitle: { fontWeight: "600" },
  muted: { color: "#64748b" },
  clock: { fontSize: 40, fontVariant: ["tabular-nums"], textAlign: "center", marginVertical: 12 },
  input: { borderWidth: 1, borderColor: "#cbd5e1", borderRadius: 8, padding: 12, backgroundColor: "#fff", marginBottom: 12 },
  button: { backgroundColor: "#1d4ed8", padding: 14, borderRadius: 8, alignItems: "center", minHeight: 48 },
  disabled: { backgroundColor: "#94a3b8" },
  buttonText: { color: "#fff", fontWeight: "700" },
  row: { flexDirection: "row", justifyContent: "space-between", marginTop: 16 },
  link: { color: "#1d4ed8", fontWeight: "600" },
  message: { marginTop: 12, color: "#0f172a" },
});
