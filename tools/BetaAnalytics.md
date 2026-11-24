# Beta analytics

The app sends anonymous usage, performance and crash events to the team without asking. There is no export and no on-device
history: events wait in a small queue until they are sent.

## How events reach CloudKit

Every event goes into an outbox on the device (`Application Support/BetaAnalytics/outbox`, excluded from backup). The app seals
it into batches of up to 32 KB and sends each one to the public database of `iCloud.com.aftrhours.reader` as a
`BetaAnalyticsBatch` record: about 10 seconds after new events, at launch, and when the app returns to the foreground. Each sealed
batch has a stable record name across retries, and a failed send is retried later, waiting longer each time (up to 15 minutes).
A device that isn't signed in to iCloud, or is offline, keeps at most 30 batches and drops the oldest. Uninstalling removes them.

Reports include a random installation ID, event timing, build, device model and OS. They exclude book titles, passages,
filenames, searches and raw errors. In debug builds, the reader's debug sheet (ladybug → iCloud → Analytics) shows how many
batches are waiting and how the last send went.

### Enable the team build

1. Use the container-owning team's signing configuration. The main app needs the `CloudKit` service and `iCloud.com.aftrhours.reader` entitlement. The app's normal `AppContainer` initializer supplies `CloudSvcCloudKit()`; a local build that explicitly supplies `nil` supports manual export only.
2. In CloudKit Console, open the container's **Development → Schema**. Create the `BetaAnalyticsBatch` record type with one String field named `report`. Add a Queryable index on `recordName`.
3. Configure record permissions before inviting testers. Allow Authenticated users to create and Creators to update their own records for retries. Remove general Read from both World and Authenticated. Use a team reporting account authorized to read across creators. Verify with two accounts that a tester cannot query another tester's batch and the reporting account can.
4. On a signed-in device, run the app for about 10 seconds, open a book, and tap a reference. In CloudKit Console, check **Development → Public Database → _defaultZone → BetaAnalyticsBatch**. Then deploy the schema and permissions to Production, upload the team-signed build, and repeat the check under **Production**.

### Retrieve the team's report

On a Mac with Xcode, save the reporting account's CloudKit user token to Keychain once. From the iRead checkout, run:

```sh
xcrun cktool save-token --type user
python3 tools/beta_report.py --cloudkit production > beta-summary.json
```

Use `--cloudkit development` for Xcode test builds. The tool follows CloudKit's continuation tokens, combines batches, and deduplicates events by installation and event ID. Keep the reporting token on the team's Mac.

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
