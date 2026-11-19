/* LawDesk web dashboard (AngularJS 1.8): open matters, a matter's billing summary and its deadlines. */
(function (angular) {
  "use strict";

  var app = angular.module("lawdesk", []);

  app.constant("API_URL", (typeof window !== "undefined" && window.LAWDESK_API) || "http://localhost:3000");

  // Today's date, injectable so tests can fix it.
  app.factory("today", function () {
    return function () {
      var d = new Date();
      return new Date(d.getFullYear(), d.getMonth(), d.getDate());
    };
  });

  app.factory("lawdeskApi", ["$http", "API_URL", function ($http, API_URL) {
    function data(res) { return res.data; }
    return {
      matters: function (status) { return $http.get(API_URL + "/matters", { params: { status: status || "open" } }).then(data); },
      matter: function (id) { return $http.get(API_URL + "/matters/" + id).then(data); },
      tasks: function (id) { return $http.get(API_URL + "/matters/" + id + "/tasks").then(data); },
      search: function (q) { return $http.get(API_URL + "/documents/search", { params: { q: q } }).then(data); }
    };
  }]);

  // 12345 -> "$123.45"
  app.filter("cents", function () {
    return function (cents) {
      var n = Number(cents) || 0;
      return (n < 0 ? "-$" : "$") + (Math.abs(n) / 100).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    };
  });

  // Days from today to a YYYY-MM-DD date (negative = overdue).
  app.factory("daysUntil", ["today", function (today) {
    return function (iso) {
      var p = String(iso).split("-");
      var due = new Date(+p[0], +p[1] - 1, +p[2]);
      return Math.round((due - today()) / 86400000);
    };
  }]);

  app.filter("dueLabel", ["daysUntil", function (daysUntil) {
    return function (iso) {
      var d = daysUntil(iso);
      if (d < 0) return "Overdue by " + -d + (d === -1 ? " day" : " days");
      if (d === 0) return "Due today";
      if (d === 1) return "Due tomorrow";
      return "Due in " + d + " days";
    };
  }]);

  app.component("matterDashboard", {
    template:
      '<section class="dash">' +
      '  <p class="error" role="alert" ng-if="$ctrl.error">{{$ctrl.error}}</p>' +
      '  <aside>' +
      '    <h2>Open matters ({{$ctrl.matters.length}})</h2>' +
      '    <ul><li ng-repeat="m in $ctrl.matters track by m.id">' +
      '      <button type="button" ng-click="$ctrl.select(m)" ng-class="{active: $ctrl.current.id === m.id}" aria-pressed="{{$ctrl.current.id === m.id}}">' +
      '        <strong>{{m.title}}</strong><span>{{m.practice_area}}</span></button>' +
      '    </li></ul>' +
      '  </aside>' +
      '  <div class="detail" ng-if="$ctrl.current">' +
      '    <h2>{{$ctrl.current.title}}</h2>' +
      '    <dl class="tiles">' +
      '      <div><dt>Billable hours</dt><dd>{{$ctrl.current.summary.billable_hours}}</dd></div>' +
      '      <div><dt>Unbilled</dt><dd>{{$ctrl.current.summary.unbilled_cents | cents}}</dd></div>' +
      '      <div><dt>Billed</dt><dd>{{$ctrl.current.summary.billed_cents | cents}}</dd></div>' +
      '    </dl>' +
      '    <h3>Deadlines</h3>' +
      '    <p ng-if="!$ctrl.tasks.length">No open deadlines.</p>' +
      '    <ul class="tasks"><li ng-repeat="t in $ctrl.tasks track by t.id" ng-class="$ctrl.urgency(t)">' +
      '      <span class="due">{{t.due_on}} · {{t.due_on | dueLabel}}</span> {{t.title}}' +
      '      <small ng-if="t.source !== \'manual\'">found by {{t.source === \'llm\' ? \'AI\' : \'rules\'}}</small>' +
      '    </li></ul>' +
      '  </div>' +
      "</section>",
    controller: ["lawdeskApi", "daysUntil", "$q", function (api, daysUntil, $q) {
      var ctrl = this;
      ctrl.matters = [];
      ctrl.tasks = [];

      ctrl.$onInit = function () {
        return api.matters("open").then(function (list) {
          ctrl.matters = list;
          if (list.length) return ctrl.select(list[0]);
        }).catch(function () { ctrl.error = "Could not load matters. Is the LawDesk API running?"; });
      };

      ctrl.select = function (m) {
        ctrl.error = null;
        return $q.all([api.matter(m.id), api.tasks(m.id)]).then(function (res) {
          ctrl.current = res[0];
          ctrl.tasks = res[1].slice().sort(function (a, b) { return a.due_on < b.due_on ? -1 : 1; });
        }).catch(function () { ctrl.error = "Could not load that matter."; });
      };

      // overdue (red), due within 7 days (amber), later (normal)
      ctrl.urgency = function (t) {
        var d = daysUntil(t.due_on);
        return d < 0 ? "overdue" : d <= 7 ? "soon" : "later";
      };
    }]
  });
})(window.angular);
