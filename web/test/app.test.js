// AngularJS unit tests with ngMock ($httpBackend, $componentController), run in Jest + jsdom.
require("angular");
require("angular-mocks");
require("../src/app.js");

const angular = window.angular;
const API = "http://localhost:3000";

function boot(todayIso = "2027-01-10") {
  const [y, m, d] = todayIso.split("-").map(Number);
  const injector = angular.injector(["ng", "ngMock", "lawdesk", ($provide) => {
    $provide.value("today", () => new Date(y, m - 1, d));
  }]);
  return injector;
}

const matters = [
  { id: 1, title: "Smith v. Harbour Properties", practice_area: "Litigation", status: "open" },
  { id: 2, title: "Estate of R. Patel", practice_area: "Wills and Estates", status: "open" },
];
const detail = { id: 1, title: "Smith v. Harbour Properties", summary: { billable_hours: 3.5, unbilled_cents: 87500, billed_cents: 125000 } };
const tasks = [
  { id: 9, title: "Trial", due_on: "2027-06-07", source: "rules" },
  { id: 8, title: "Serve and file a Statement of Defence", due_on: "2027-01-28", source: "rules" },
  { id: 7, title: "Deliver documents", due_on: "2027-01-08", source: "llm" },
];

test("cents filter formats money", () => {
  const cents = boot().get("$filter")("cents");
  expect(cents(125000)).toBe("$1,250.00");
  expect(cents(5)).toBe("$0.05");
  expect(cents(undefined)).toBe("$0.00");
});

test("dueLabel explains how far away a deadline is", () => {
  const label = boot("2027-01-10").get("$filter")("dueLabel");
  expect(label("2027-01-08")).toBe("Overdue by 2 days");
  expect(label("2027-01-10")).toBe("Due today");
  expect(label("2027-01-11")).toBe("Due tomorrow");
  expect(label("2027-01-28")).toBe("Due in 18 days");
});

test("dashboard loads open matters, selects the first and sorts its deadlines", () => {
  const inj = boot();
  const $httpBackend = inj.get("$httpBackend");
  $httpBackend.expectGET(`${API}/matters?status=open`).respond(matters);
  $httpBackend.expectGET(`${API}/matters/1`).respond(detail);
  $httpBackend.expectGET(`${API}/matters/1/tasks`).respond(tasks);

  const ctrl = inj.get("$componentController")("matterDashboard", null);
  ctrl.$onInit();
  $httpBackend.flush();

  expect(ctrl.matters).toHaveLength(2);
  expect(ctrl.current.summary.billable_hours).toBe(3.5);
  expect(ctrl.tasks.map((t) => t.due_on)).toEqual(["2027-01-08", "2027-01-28", "2027-06-07"]);
  expect(ctrl.tasks.map((t) => ctrl.urgency(t))).toEqual(["overdue", "later", "later"]);
  $httpBackend.verifyNoOutstandingExpectation();
});

test("deadline within a week is marked soon", () => {
  const ctrl = boot("2027-01-24").get("$componentController")("matterDashboard", null);
  expect(ctrl.urgency({ due_on: "2027-01-28" })).toBe("soon");
});

test("shows a clear error when the API is down", () => {
  const inj = boot();
  const $httpBackend = inj.get("$httpBackend");
  $httpBackend.expectGET(`${API}/matters?status=open`).respond(500);
  const ctrl = inj.get("$componentController")("matterDashboard", null);
  ctrl.$onInit();
  $httpBackend.flush();
  expect(ctrl.error).toMatch("Could not load matters");
});

test("renders the template: list, money tiles and deadline labels", () => {
  const inj = boot();
  const $httpBackend = inj.get("$httpBackend");
  $httpBackend.whenGET(`${API}/matters?status=open`).respond(matters);
  $httpBackend.whenGET(`${API}/matters/1`).respond(detail);
  $httpBackend.whenGET(`${API}/matters/1/tasks`).respond(tasks);
  const scope = inj.get("$rootScope").$new();
  const el = inj.get("$compile")("<matter-dashboard></matter-dashboard>")(scope);
  scope.$digest();
  $httpBackend.flush();
  const text = el.text().replace(/\s+/g, " ");
  expect(text).toContain("Open matters (2)");
  expect(text).toContain("$875.00");
  expect(text).toContain("Overdue by 2 days");
  expect(text).toContain("found by AI");
  expect(el[0].querySelectorAll(".tasks li.overdue")).toHaveLength(1);
});
