import { act, fireEvent, render, screen, waitFor } from "@testing-library/react-native";
import App from "../App";

jest.mock("@react-native-async-storage/async-storage", () =>
  require("@react-native-async-storage/async-storage/jest/async-storage-mock"),
);

const matters = [
  { id: 1, title: "Smith v. Harbour Properties", practice_area: "Litigation", status: "open" },
  { id: 2, title: "Estate of R. Patel", practice_area: "Wills and Estates", status: "open" },
];

function setup(poster = jest.fn(async () => ({ status: 201, json: async () => ({}) }))) {
  let clock = Date.UTC(2027, 0, 10, 15, 0, 0);
  const now = () => clock;
  const advance = (ms: number) => { clock += ms; };
  render(<App loadMatters={async () => matters} poster={poster} now={now} />);
  return { advance, poster };
}

test("asks for a matter before the timer can start", async () => {
  setup();
  expect(await screen.findByText("Choose a matter first")).toBeTruthy();
});

test("times work on a matter, rounds to billing units and syncs it", async () => {
  const { advance, poster } = setup();
  fireEvent.press(await screen.findByText("Smith v. Harbour Properties"));
  fireEvent.press(screen.getByText("Start timer"));
  fireEvent.changeText(screen.getByLabelText("What are you working on?"), "Review lease");
  act(() => advance(14 * 60_000));
  fireEvent.press(screen.getByText("Stop and save"));

  expect(screen.getByText(/Saved 0.3 h on Smith v. Harbour Properties/)).toBeTruthy();   // 14 min -> 18 min
  expect(screen.getByText("1 waiting to sync · 0 need attention")).toBeTruthy();

  fireEvent.press(screen.getByText("Sync now"));
  await waitFor(() => expect(screen.getByText("Synced 1 entry.")).toBeTruthy());
  expect(poster).toHaveBeenCalledWith("/matters/1/time_entries", {
    time_entry: expect.objectContaining({ matter_id: 1, minutes: 18, description: "Review lease", rate_cents: 25000 }),
  });
});

test("keeps the entry when offline", async () => {
  const { advance } = setup(jest.fn(async () => { throw new Error("offline"); }));
  fireEvent.press(await screen.findByText("Estate of R. Patel"));
  fireEvent.press(screen.getByText("Start timer"));
  act(() => advance(5 * 60_000));
  fireEvent.press(screen.getByText("Stop and save"));
  fireEvent.press(screen.getByText("Sync now"));
  await waitFor(() => expect(screen.getByText("Offline: 1 entry kept on this phone.")).toBeTruthy());
});
