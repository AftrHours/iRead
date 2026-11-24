# Beta analytics

In the Library, open the ellipsis menu, choose **Export Beta Analytics**, then save the JSON file in Files. Each export contains this installation’s event history. From the iRead checkout, combine exports into one summary with Python 3. No packages or account are required.

```sh
python3 tools/beta_report.py ~/Downloads/refrn-reports/*.json > beta-summary.json
```

Overlapping exports are deduplicated by installation and event ID. A tester is one random installation ID. A reinstall or a second device can count as a separate tester. The journal is local to the app and excluded from device backup. Exported fields include build, device model, OS, timestamps, durations, and opaque identifiers. Book titles, authors, filenames, searches, underlined text, quotes, and raw error messages are excluded. An export is cumulative. Uninstalling removes the journal and any batches still waiting on that device.

## Share beta analytics through CloudKit

In an iCloud-enabled build, open **Library → … → Share Beta Analytics** and confirm. The choice is specific to this installation and independent of reference-rating consent. Only events observed from that point are eligible. Delayed crash diagnostics are eligible only when their reporting interval began after opt-in. Reports include a random installation ID, event timing, build, device model, and OS. They exclude book titles, passages, filenames, searches, and raw errors.

The recorder seals small batches and sends them to the public database of `iCloud.com.aftrhours.reader`. Each sealed batch has a stable CloudKit record name across retries. A signed-out or offline device keeps eligible batches locally and retries while the app runs and when it returns to the foreground. **Stop Sharing Beta Analytics** discards queued batches and stops future uploads. A request already accepted by CloudKit may finish. Previously received records remain available to the team. Manual export still includes the full local journal.

### Enable the team build

1. Use the container-owning team's signing configuration. The main app needs the `CloudKit` service and `iCloud.com.aftrhours.reader` entitlement. The app's normal `AppContainer` initializer supplies `CloudSvcCloudKit()`; a local build that explicitly supplies `nil` supports manual export only.
2. In CloudKit Console, open the container's **Development → Schema**. Create the `BetaAnalyticsBatch` record type with one String field named `report`. Add a Queryable index on `recordName`.
3. Configure record permissions before inviting testers. Allow Authenticated users to create and Creators to update their own records for retries. Remove general Read from both World and Authenticated. Use a team reporting account authorized to read across creators. Verify with two accounts that a tester cannot query another tester's batch and the reporting account can.
4. On a signed-in device, opt in, open a book, and tap a reference. In CloudKit Console, check **Development → Public Database → _defaultZone → BetaAnalyticsBatch**. Then deploy the schema and permissions to Production for TestFlight, upload the team-signed build, and repeat the check under **Production**.

### Retrieve the team's report

On a Mac with Xcode, save the reporting account's CloudKit user token to Keychain once. From the iRead checkout, run:

```sh
xcrun cktool save-token --type user
python3 tools/beta_report.py --cloudkit production > beta-summary.json
```

Use `--cloudkit development` for Xcode test builds. The tool follows CloudKit's continuation tokens, combines batches, and deduplicates events by installation and event ID. You can also pass local JSON exports to the same command. Keep the reporting token on the team's Mac.

| Measurement | Definition |
| --- | --- |
| Import | A picker start counts once per presentation. Cancellation uses picker starts as its denominator. Each selected file, externally opened EPUB, or queued shared EPUB is a separate processing attempt. Duplicates appear in the duplicate category. Processing time starts when a file begins processing. |
| Open and resume | Opening starts at the book tap and reaches ready when a page is presented in the active reader. A valid saved position must resolve to that page and chapter. First opens have no resume attempt. A missing position can be identified after this version has recorded a successful save. |
| Reading | One session per reader opening. Only foreground time is credited. Activity can contribute up to two minutes before another interaction. Thirty-second checkpoints preserve most activity if the app exits abruptly. Forward turns count user navigation through the pager. Reference, search, and chapter jumps have separate paths. Days use UTC. |
| Reference discovery | Each distinct visible underline counts once per session, including a repeated visit to the same page. Prefetched pages and hidden marks are excluded. Discovery divides the distinct impressions that opened a card by all distinct impressions. |
| Jumps and returns | Each card opening has an ID. A jump or return completes when the destination page is shown. A saved return carries its originating ID across reader launches. Returns from positions saved by older versions can have no associated jump. |
| Ratings | Latest up or down vote per installation and book reference. Withdrawing a vote removes it from the current total. Coverage divides currently rated opened references by all distinct opened references. |
| Performance | Times are milliseconds. Median uses the middle of the sample. The 95th percentile uses nearest rank. Repaginating the current page and computing whole-book page totals are reported separately. |
| Reliability | An app session is a process launch. Only crash diagnostics supplied by MetricKit are counted. Attribution uses installation, build, process ID, and reporting time. An unmatched diagnostic leaves the crash-free percentage unknown. A later export can include newly delivered diagnostics. |

Percentages are on a 0–100 scale. A null value means there were no eligible observations or the rate could not be established. An interrupted flow can have a start and no outcome. For crash analysis, include an export after relaunching the app.
