#!/usr/bin/env python3
"""Usage: python3 tools/beta_report.py report1.json [report2.json ...]

Merge overlapping device exports by event ID. Percentages use 0–100; null
means the denominator was zero. Testers are installations; days are UTC.
"""
import argparse
import json
import math
import subprocess
from collections import Counter, defaultdict
from datetime import datetime, timezone
from itertools import chain
from pathlib import Path
from statistics import median


def percent(count, total):
    return round(100 * count / total, 2) if total else None


def timing(rows):
    values = sorted(r["milliseconds"] for r in rows if r.get("milliseconds") is not None)
    if not values:
        return {"samples": 0, "median_ms": None, "p95_ms": None}
    return {"samples": len(values), "median_ms": round(median(values), 2),
            "p95_ms": round(values[math.ceil(0.95 * len(values)) - 1], 2)}


def categories(rows):
    return dict(Counter(r.get("category", "unknown") for r in rows))


def keys(rows, *fields):
    return {tuple(r[f] for f in fields) for r in rows if all(r.get(f) for f in fields)}


def diagnostics(rows):
    groups = defaultdict(list)
    for row in rows:
        groups[(row["build"], row["device"], row["os"],
                row.get("feature", row["event"]), row.get("category", "unknown"))].append(row)
    return [dict(build=b, device=d, os=o, feature=f, category=c, count=len(items),
                 affected_testers=len(keys(items, "tester")))
            for (b, d, o, f, c), items in sorted(groups.items())]


def reliability(events, errors):
    launches = events["appStarted"]
    crashes = events["crash"]
    crashed_launches = set()
    unmatched = 0
    for crash in crashes:
        possible = [r for r in launches if r["tester"] == crash["tester"] and
                    r["build"] == crash["build"] and r.get("pid") == crash.get("pid") and
                    r["timestamp"] <= crash["timestamp"]]
        if len(possible) == 1:
            crashed_launches.add(possible[0]["launch"])
        else:
            unmatched += 1
    return {"app_sessions": len(launches), "reported_crashes": len(crashes),
            "testers_with_reported_crashes": len(keys(crashes, "tester")),
            "crash_free_app_sessions_pct": None if unmatched else percent(len(launches) - len(crashed_launches), len(launches)),
            "unmatched_crash_diagnostics": unmatched, "crashes_by_configuration": diagnostics(crashes),
            "recoverable_errors": len(errors), "affected_testers": len(keys(errors, "tester")),
            "errors_by_configuration": diagnostics(errors)}


def summarize(records):
    events = defaultdict(list)
    for r in sorted(records, key=lambda e: e["timestamp"]):
        events[r["event"]].append(r)
    picker, imports = events["pickerStarted"], events["importStarted"]
    imported, rejected = events["importSucceeded"], events["importFailed"]
    attempts, ready, failed = events["bookOpenRequested"], events["readerReady"], events["openingFailed"]
    sessions = events["sessionStarted"]
    readers = Counter(r["tester"] for r in sessions)
    daily = defaultdict(set)
    for r in sessions + events["activeReading"]:
        day = datetime.fromtimestamp(r["timestamp"] / 1000, timezone.utc).date().isoformat()
        daily[day].add(r["tester"])
    minutes = {r["session"]: 0 for r in sessions}
    per_tester = {tester: 0 for tester in readers}
    for r in events["activeReading"]:
        duration = r["milliseconds"] / 60000
        minutes[r["session"]] = minutes.get(r["session"], 0) + duration
        per_tester[r["tester"]] = per_tester.get(r["tester"], 0) + duration
    advanced = dict.fromkeys(minutes, 0)
    for r in events["pageAdvanced"]:
        advanced[r["session"]] = advanced.get(r["session"], 0) + 1
    shown = keys(events["underlineDisplayed"], "session", "reference")
    opened = events["referenceCardOpened"]
    tapped = keys(opened, "session", "reference")
    opened_refs = keys(opened, "tester", "reference")
    cards = keys(opened, "flow")
    jumps = keys(events["jumpCompleted"], "flow")
    returns = keys(events["returnCompleted"], "flow")
    latest = {(r["tester"], r["reference"]): r["category"] for r in events["ratingChanged"]}
    ratings = {k: v for k, v in latest.items() if v in ("up", "down")}
    visible_counts = Counter(s for s, _ in shown)
    errors = (events["recoverableError"] + events["progressSaveFailed"] + events["resumeFailed"] +
              events["pickerFailed"] + failed + [r for r in rejected if r.get("category") != "duplicate"])
    return {
        "imports": {"flows_started": len(picker) + sum(r.get("picker") is None for r in imports),
                    "picker_flows_started": len(picker), "file_attempts": len(imports),
                    "unique_testers_starting": len(keys(picker + imports, "tester")),
                    "attempts_by_source": categories(imports),
                    "succeeded": len(imported), "success_pct": percent(len(imported), len(imports)),
                    "failed": len(rejected), "failure_pct": percent(len(rejected), len(imports)),
                    "failure_categories": categories(rejected), "successful_processing": timing(imported),
                    "cancelled_pickers": len(events["pickerCancelled"]),
                    "picker_cancel_pct": percent(len(events["pickerCancelled"]), len(picker))},
        "opening": {"requested": len(attempts), "testers": len(keys(attempts, "tester")),
                    "ready": len(ready), "ready_pct": percent(len(ready), len(attempts)), "loading": timing(ready),
                    "failures": len(failed), "failure_pct": percent(len(failed), len(attempts)),
                    "affected_testers": len(keys(failed, "tester")), "failure_categories": categories(failed)},
        "sessions": {"started": len(sessions), "per_tester": readers, "daily_readers_utc": {d: len(v) for d, v in daily.items()},
                     "active_minutes_per_session": minutes, "active_minutes_per_tester": per_tester,
                     "forward_turns_per_session": advanced, "sessions_with_progress": sum(n > 0 for n in advanced.values())},
        "progress": {"saves": len(events["progressSaved"]), "save_failures": len(events["progressSaveFailed"]),
                     "save_time": timing(events["progressSaved"]), "resume_attempts": len(events["resumeAttempted"]),
                     "resume_succeeded": len(events["resumeSucceeded"]), "resume_failed": len(events["resumeFailed"]),
                     "resume_success_pct": percent(len(events["resumeSucceeded"]), len(events["resumeAttempted"])),
                     "resume_failure_pct": percent(len(events["resumeFailed"]), len(events["resumeAttempted"])),
                     "resume_failure_categories": categories(events["resumeFailed"])},
        "references": {"unique_visible_per_session": {r["session"]: visible_counts[r["session"]] for r in sessions},
                       "sessions_with_underlines": len({s for s, _ in shown}), "card_opens": len(opened),
                       "discovery_pct": percent(len(shown & tapped), len(shown)), "card_latency": timing(opened),
                       "completed_jumps": len(events["jumpCompleted"]), "card_opens_followed_by_jump_pct": percent(len(cards & jumps), len(cards)),
                       "jump_time": timing(events["jumpCompleted"]), "completed_returns": len(events["returnCompleted"]),
                       "jumps_followed_by_return_pct": percent(len(jumps & returns), len(jumps)), "return_time": timing(events["returnCompleted"])},
        "ratings": {"submitted_or_changed": len(events["ratingChanged"]), "current_ratings": len(ratings),
                    "helpful_pct": percent(sum(v == "up" for v in ratings.values()), len(ratings)),
                    "unique_opened_references": len(opened_refs),
                    "rating_coverage_pct": percent(len(opened_refs & ratings.keys()), len(opened_refs))},
        "reliability": reliability(events, errors),
        "performance": {"loading": timing(ready), "page_turn": timing(events["pageTurn"]),
                        "repagination": {kind: timing([r for r in events["repagination"] if r["category"] == kind])
                                         for kind in ("current_page", "book_totals")}}
    }


def cloud_reports(environment, query=subprocess.check_output):
    """Read every page using the developer's cktool credentials stored in Keychain."""
    command = ["xcrun", "cktool", "query-records", "--team-id", "X7WUH4Z65U",
               "--container-id", "iCloud.com.aftrhours.reader", "--environment", environment,
               "--database-type", "public", "--record-type", "BetaAnalyticsBatch", "--requested-fields", "report"]
    token = None
    while True:
        arguments = command + (["--continuation-token", token] if token else [])
        page = json.loads(query(arguments))
        for record in page["records"]:
            yield json.loads(record["fields"]["report"]["value"])
        token = page.get("continuationToken")
        if not token:
            return


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("exports", nargs="*", type=Path)
    parser.add_argument("--cloudkit", choices=("development", "production"),
                        help="Include team CloudKit batches using xcrun cktool")
    args = parser.parse_args()
    if not args.cloudkit and not args.exports:
        parser.error("Pass at least one JSON export or --cloudkit ENVIRONMENT.")
    reports = (json.loads(path.read_text(encoding="utf-8")) for path in args.exports)
    if args.cloudkit:
        reports = chain(reports, cloud_reports(args.cloudkit))
    records = {}
    for data in reports:
        if data.get("schemaVersion") != 1:
            parser.error("Unsupported beta report version")
        for row in data["events"]:
            records[(row["tester"], row["id"])] = row
    print(json.dumps(summarize(records.values()), indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
