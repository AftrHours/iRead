import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from beta_report import cloud_reports, summarize


def event(name, index, **fields):
    return {"event": name, "id": str(index), "timestamp": 1000 + index, "build": "3",
            "tester": "tester1", "device": "iPhone", "launch": "launch1", "os": "iOS", **fields}


class BetaReportTests(unittest.TestCase):
    def test_denominators_and_repeated_exports(self):
        rows = [event("pickerStarted", 1), event("pickerStarted", 2), event("pickerCancelled", 3),
                event("importStarted", 4), event("importStarted", 5), event("importSucceeded", 6, milliseconds=42),
                event("importFailed", 7, category="invalid_content"), event("bookOpenRequested", 8),
                event("bookOpenRequested", 9), event("readerReady", 10, milliseconds=28),
                event("openingFailed", 11, category="missing_file")]
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "beta.json"
            path.write_text(json.dumps({"schemaVersion": 1, "events": rows}))
            command = [sys.executable, str(Path(__file__).with_name("beta_report.py")), str(path), str(path)]
            report = json.loads(subprocess.check_output(command))
        self.assertEqual(report["imports"]["file_attempts"], 2)
        self.assertEqual(report["imports"]["picker_cancel_pct"], 50)
        self.assertEqual(report["opening"]["ready_pct"], 50)
        self.assertEqual(report["opening"]["loading"]["p95_ms"], 28)
        self.assertEqual(report["reliability"]["recoverable_errors"], 2)

    def test_cloudkit_follows_continuation_tokens(self):
        reports = [{"schemaVersion": 1, "events": [event("readerReady", i)]} for i in (1, 2)]
        calls = []

        def query(arguments):
            index = len(calls)
            calls.append(arguments)
            page = {"records": [{"fields": {"report": {"value": json.dumps(reports[index])}}}]}
            if index == 0:
                page["continuationToken"] = "page-two"
            return json.dumps(page)

        self.assertEqual(list(cloud_reports("development", query)), reports)
        self.assertEqual(calls[1][-2:], ["--continuation-token", "page-two"])
        self.assertIn("BetaAnalyticsBatch", calls[0])

    def test_reference_discovery_changes_and_removals(self):
        names = ["sessionStarted", "underlineDisplayed", "underlineDisplayed", "referenceCardOpened",
                 "referenceCardOpened", "jumpCompleted", "returnCompleted", "ratingChanged",
                 "ratingChanged", "ratingChanged", "sessionStarted"]
        rows = [event(name, i, session="s", flow=str(i), reference="r1") for i, name in enumerate(names)]
        rows[2]["reference"] = "r2"
        rows[5]["flow"] = rows[6]["flow"] = rows[4]["flow"]
        rows[7]["category"], rows[8]["category"], rows[9]["category"] = "up", "down", "removed"
        rows[10]["session"] = "s2"
        report = summarize(rows)
        self.assertEqual(report["references"]["unique_visible_per_session"], {"s": 2, "s2": 0})
        self.assertEqual(report["references"]["discovery_pct"], 50)
        self.assertEqual(report["references"]["card_opens_followed_by_jump_pct"], 50)
        self.assertEqual(report["references"]["jumps_followed_by_return_pct"], 100)
        self.assertEqual(summarize(rows[:9])["ratings"]["helpful_pct"], 0)
        self.assertEqual(report["ratings"]["rating_coverage_pct"], 0)
        self.assertIsNone(report["ratings"]["helpful_pct"])

    def test_crash_attribution_and_missing_denominators(self):
        rows = [event("appStarted", 1, pid=7), event("appStarted", 2, pid=8, launch="launch2"),
                event("crash", 3, pid=7, launch="")]
        self.assertEqual(summarize(rows)["reliability"]["crash_free_app_sessions_pct"], 50)
        rows.append(event("crash", 4, pid=99, launch=""))
        result = summarize(rows)
        self.assertIsNone(result["reliability"]["crash_free_app_sessions_pct"])
        self.assertIsNone(result["progress"]["resume_success_pct"])


if __name__ == "__main__":
    unittest.main()
