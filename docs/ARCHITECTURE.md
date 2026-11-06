# iRead architecture

iPhone and iPad reader app (iPhone in portrait only). SwiftUI, Swift 6, iOS 26, XcodeGen (`project.yml` → `iRead.xcodeproj`). Packages: EPUBKit (local, in `Packages/EPUBKit`, on ZIPFoundation) reads EPUB files; [UnderlineEngine](https://github.com/AftrHours/UnderlineEngine) (from GitHub, pinned to one commit in `project.yml`) finds the phrases to underline.

## Folders and dependency direction

```
App/
  iReadApp.swift      shows onboarding on first launch, then switches on AppNav.route
  AppContainer.swift  builds every repo, service, Ctrl and VM (the only type that knows them all)
  AppNav.swift        route: .library or .reader(book:)
  Resources/          bundled sample EPUBs (listed in BookRecord.samples)
  LibraryPalette.swift colors shared by every feature

  Book/       per-book data shared by every feature (BookRecord, BookContent, Page, ReadingProgress,
              BookContentRepo, ProgRepo, EPUBParseSvc, BookFingerprint: names a book by its text)
  Onboarding/ first-launch introduction, with an EPUB import
  Library/    library page: list, search, sort, grid/list, EPUB import
  Analysis/   the AI feature: underlines with their reference passages (UnderlineEngine), and the readers' ratings of them
    Models/   SavedUnderline: the app's own copy of an underline the engine found; UnderlineRating; ContextPassage; Mark
    Svc/      ModelCheckSvc: one test call to the on-device model before the first chapter
              CloudSvc: iCloud records through CloudKit (the reader's private database, and the developers' public one)
    Debug/    DEBUG-only underline debug sheet
  Reader/     reading page: paging, progress, settings, search, contents, reference cards
```

Small reusable view pieces live in a feature's `Views/Components/` (for example `RefCardView`, `BookMenu`).

```
            App (iReadApp, AppContainer, AppNav)
            /                \
       Library              Reader
           \                  |
            \             Analysis
             \                |
              +---------->  Book
```

Arrows point at what a feature may use. No cycles. Inside a feature, folders are layers
(`Models/ Repo/ Svc/ Rules/ Ctrl/ VM/ Views/`), and a feature only has the layers it needs.

## The rule

- A type depends on about 3 things. If it needs more, it does more than one job: split it by job.
- Dependencies point down: `View → VM → Ctrl → Repo / Svc → Models`. `Rules` can be called from anywhere.
- A Ctrl never calls another Ctrl. A Repo never calls a VM. When two Ctrls must be combined, a VM does it.
- Only `AppContainer` knows every type.
- A View is handed the VMs it uses and never reaches one through another (no `readerVM.referenceVM.x`).
  `ReaderView` takes its children from `ReaderVM` once, in `init`, and passes each one down.
- Only `UnderlineRepo`, `ChapterInputMapper` and the DEBUG files in `Analysis/Debug/` import UnderlineEngine.
  Everything else uses `SavedUnderline`, so an engine update only touches those files.
- Add a layer or type only when it does real work. A protocol is added when a test needs one.

## Naming

A type's last word says its layer:

| Suffix  | Job |
|---------|-----|
| `View`  | Renders only. Calls VM intents. |
| `VM`    | UI state, `@MainActor @Observable`. Receives intents (`xTapped`, `xChanged`, `onAppear`). |
| `Ctrl`  | One use case, orchestrating repos and services. |
| `Repo`  | Persists or caches data (files in Application Support, in-memory caches). Failed writes are logged to OSLog category `storage`. |
| `Svc`   | Wraps a system or framework API (EPUBKit, UIKit, OSLog, Foundation Models, CloudKit). |
| `Rules` | Pure functions, no state, no I/O. |
| `Models`| Plain data. |
| `Knobs` | Constants worth tuning, next to the type that uses them (`UnderlineRepoKnobs.engineVersion`). |

Names that are easy to mix up:

- **Ref = Reference.** `RefCtrl`, `RefCardView`, `ReferenceVM` and `ReferenceCard` are all about the reference: the earlier
  passage that explains an underline. **Rating** is the reader's thumbs up / down on that reference (`RatingVM`, `RatingCtrl`,
  `RatingRepo`, `UnderlineRating`, `Verdict`).
- **Ours or the engine's.** `SavedUnderline` and `ContextPassage` are the app's. `Underline`, `AnswerPassage`, `UnderlineRecord`
  and `UnderlineCtrl` come from the UnderlineEngine package: `UnderlineCtrl` is the engine's entry point, not one of our Ctrls.
- **Book ID vs fingerprint.** `BookRecord.id` is a random UUID for one copy in the library. `BookContent.fingerprint` is a hash of
  the book's text, the same on every device, so underlines and ratings are kept under it.
- **Short forms.** `Lib` = Library, `Prog` = Progress (`ProgRepo` saves what `ProgressCtrl` decides).
- **Settings vs state.** `ReadingSettings` is how the page looks (text size, spacing, theme). `BookState` is one book's
  return-to-reading spot and recent searches. `ReaderStateCtrl` handles both.
- **Mark** is anything drawn on the page: an underline or a highlight.
- **Protocols and their types.** The protocol is `XSvc`; the app's real one adds the framework (`CloudSvcCloudKit`,
  `EPUBParseSvcEPUBKit`); test ones in `Tests/Support/Fakes.swift` add `Fake`, `Spy` or `Fixed`.
- **iCloud databases.** `CloudDatabase.reader` is the reader's private database (saved underlines);
  `.developers` is the public one (shared ratings).

## Reader split

| Type | Job | Depends on |
|---|---|---|
| `ReaderCtrl` | Book content, current position, pages, page counts, search, position ↔ page | `BookContentRepo`, `PagerSvc` |
| `ProgressCtrl` | Restore and save progress, log restore and finished events | `ProgRepo`, `EventSvc` |
| `ReaderStateCtrl` | Reading settings, brightness, the "return to reading" position, recent searches | `ReadingSettingsRepo`, `BrightnessSvc`, `BookStateRepo` |
| `ReaderVM` (parent) | Pages, shown page, viewport, labels, show/hide controls, sheets, menu, back, contents, search, saving progress in page-turn order | `ReaderCtrl`, `ProgressCtrl`, `ReaderStateCtrl` (handed to `SearchVM`), `AppNav` + 3 children |
| `ReaderSettingsVM` | Settings, layout settings, brightness, text size, line spacing, theme | `ReaderStateCtrl` |
| `ReferenceVM` | Marks, following underlines for the shown chapter, reference cards, highlight, jump and return, toast | `RefCtrl`, `ReaderStateCtrl`, `ReaderCtrl` |
| `RatingVM` | Thumbs on the shown card, the share question, the Share Ratings switch, the iCloud row in the menu | `RatingCtrl` |
| `SearchVM` | Search query (searched once typing pauses for 300 ms, 2 characters or more), results and recent searches | `ReaderCtrl.search` (passed in as a closure, so tests can count searches), `ReaderStateCtrl` |

`ReaderSettingsVM` and `ReferenceVM` share one `ReaderStateCtrl` per open book.
`RefCtrl` (underlines and marks: `BookContentRepo`, `UnderlineRepo`) and `RatingCtrl` (ratings: `BookContentRepo`, `UnderlineRepo`
to look up the rated underline, `RatingRepo`) share one `UnderlineRepo` for the whole app.
`RefCardView` and `ReaderMenuView` get `RatingVM` directly.

State flows one way. `ReaderVM` pushes the shown page and the loaded pages into
`ReferenceVM.update(shownPage:loadedPages:)`. Underlines and highlights always show, whether or not the controls do
(turning a page hides the controls; tapping the middle of the page shows them). The children report back only through output callbacks:
`ReferenceVM.onShowPage` and `ReaderSettingsVM.onSettingsChanged`, the same way
`SearchVM` reports `onResultPicked`.

## Main flows

**Launch → library**
1. `iReadApp.init` → `AppContainer.init` builds `EPUBParseSvc`, `ProgRepo`, `BookContentRepo`, `LibRepo`, `UnderlineRepo`, `RatingRepo` once.
2. `AppContainer.makeLibVM` → `LibView`. On the first launch (`hasCompletedHiFiOnboarding` is false), `OnboardingView` shows first;
   `OnboardingVM` (from `AppContainer.makeOnboardingVM(using:)`) imports through the same `LibVM.importFiles`. Skip or finish → `LibView`.
3. `LibView.task` → `LibVM.onAppear` → `LibCtrl.loadLibrary` → `LibRepo.fetchBooks`
   (the built-in sample books plus the imported books in `Books/library.json`), then `ProgRepo.progress(for:)` per book,
   merged in by `LibCtrl` (a finished book shows as fully read).
4. `LibVM.books` → `LibrarySorter.sorted(_:by:pinning:)`.
5. `LibVM.loadCovers` → `LibCtrl.cover(for:)` → `BookContentRepo.cover(for:)` → `EPUBParseSvc.cover(from:)`, shrunk to a thumbnail once.

**Import an EPUB**
1. `LibView` + button → `LibVM.importTapped` → `EPUBDocumentPicker` → `LibVM.importPickerCompleted` → `LibVM.importFiles`.
2. → `LibCtrl.importBook(from:)` → `LibRepo.importBook` → `EPUBParseSvc.metadata(from:)`,
   copies to `Books/<id>/book.epub`, appends it to `library.json` (imported books only, never the samples).
3. → `LibCtrl.loadLibrary`. The new book stays pinned first until `LibVM.sortChanged`.

**Book "…" menu in the library**
- Mark as Finished / Still Reading → `LibCtrl.setFinished` → `ProgRepo.setFinished` (keeps the reading position).
- Reset Progress → `LibCtrl.resetProgress` → `ProgRepo.resetProgress` (a saved 0% record, so samples don't fall back to mock progress).
- Remove → alert → `LibCtrl.remove` → `LibRepo.remove`: imported books are deleted; sample books are added to `Books/hidden-samples.json`.
  Then `BookContentRepo.forget` drops the book's parse and cover from memory.

**Open a book**
1. `LibVM.bookTapped` → `AppNav.openReader(book:)`.
2. `iReadApp` sees the route change → `AppContainer.makeReaderVM(book:)` (once per open) → `ReaderView`.
3. `ReaderView.task` → `ReaderVM.onAppear`:
   1. `ReaderCtrl.openBook` → `BookContentRepo.content(for:)` → `EPUBParseSvc.parse`
      (imported `book.epub` first, then the bundled EPUB named in `BookRecord.samples`; one parse per book even with concurrent callers;
      only the 2 most recently used books stay parsed in memory).
   2. `ReaderSettingsVM.bookOpened` → `ReaderStateCtrl.settings`.
   3. `ProgressCtrl.savedProgress` → `ReaderCtrl.restorePosition(from:)` → `ProgressCtrl.positionRestored`.
   4. `ReferenceVM.bookOpened` → `ReaderStateCtrl.load`. `RatingVM.bookOpened` → `RatingCtrl.sharesRatings`, then in the background
      `RatingCtrl.cloudAccount` and `RatingCtrl.sendUnsentRatings` (again on `appForegrounded`).
   5. `ReaderVM.showCurrentPage` → `ReaderCtrl.currentPage` → `PagerSvc.pageRanges`.
   6. `ReferenceVM.update` sees a new chapter → `RefCtrl.underlineUpdates(from:)` → `UnderlineRepo.underline(chapter:of:startingAt:)`
      (a finished chapter loads from `Underlines/<fingerprint>/`, or else from the reader's iCloud; otherwise `ChapterInputMapper`
      → UnderlineEngine runs from the page's first sentence, then wraps, and each result becomes `SavedUnderline`). Books are named by `BookContent.fingerprint`, so the same book matches on every device.
      Each update → `ReferenceVM.loadMarks`.

**Turn a page and save progress**
1. `PageTurnView.onPageChanged` → `ReaderVM.pageChanged` → `ReaderVM.show` → `ReferenceVM.update`.
2. → `ReaderCtrl.pages(around:)` → `ReferenceVM.update` → `ReferenceVM.loadMarks` → `RefCtrl.marks(on:highlighting:)`.
3. → after the previous turn's save finishes, `ReaderCtrl.pageChanged(to:)` → `ReadingProgressCalculator.progress(on:in:bookID:at:)`.
4. → `ProgressCtrl.pageRead` → `ReadingProgressCalculator.merged` → `ProgRepo.save` (debounced),
   and `EventSvc.log(.bookFinished)` the first time the book is finished.
5. Back → `ReaderVM.backTapped` waits for the last turn's save, then `ProgressCtrl.saveNow` → `ProgRepo.saveNow`,
   then `ReferenceVM.close` (cancels the underline task for good), then `AppNav.closeReader`.
   App backgrounded → `ProgressCtrl.saveNow` → `ProgRepo.saveNow`, and `ReferenceVM.appBackgrounded` pauses the underlining
   until `appForegrounded`.

**Tap an underline, jump, and return**
1. `PageTextView` → `PageTurnView.onMarkTapped` → `ReferenceVM.markTapped`
   → `RefCtrl.underline(withID:)`, `ReaderCtrl.page(containing:)` → `RefCardView`
   (the phrase, the passage that explains it, and thumbs up / down).
   The card's `.task` → `RatingVM.cardShown` → `RatingCtrl.verdict(onUnderline:)` fills in a saved thumb.
   Thumb → `RatingVM.verdictTapped` → `RatingCtrl.rate` → `RatingRepo.save`. The first rating asks once whether to share ratings
   (`RatingVM.sharingChosen`; also the Share Ratings switch in the reader menu).
2. Jump to Passage → `ReferenceVM.jumpToPassageTapped` → `ReaderCtrl.startPosition(of:)` → `ReaderStateCtrl.saveReturnPosition`
   → `ReaderCtrl.page(containing:)` → `onShowPage` → `ReaderVM.show(_:highlighting:)`.
3. Return to Reading → `ReferenceVM.returnToReadingTapped` → `ReaderStateCtrl.returnPosition` → `ReaderCtrl.page(ifValid:)`
   → `ReaderStateCtrl.clearReturnPosition` → `onShowPage` and a 2-second toast.

## Analysis

- `Repo/UnderlineRepo`: runs UnderlineEngine's `UnderlineCtrl` one chapter at a time (starting another stops the running one),
  and turns each `Underline` it returns into `SavedUnderline` (only what the app uses: phrase, kind, decided by, its reference
  passage). Only `SavedUnderline` is kept in memory, saved and uploaded. A finished chapter is saved on disk (`Underlines/<fingerprint>/`) and in the reader's iCloud (private database, record type
  `ChapterUnderlines`, named `<fingerprint>-<chapter>`), with the parser and engine versions (`UnderlineRepoKnobs.engineVersion`,
  bumped with the UnderlineEngine pin in `project.yml` or when `SavedUnderline` changes). A chapter not on disk is looked for in iCloud before the engine runs,
  so another device, a reinstall or a re-import doesn't underline it again. A chapter from another version is underlined again.
  Without iCloud everything still works on the device.
- `Svc/ModelCheckSvc`: one tiny call to Apple's on-device model before the first chapter. The system can say the model is
  available while every call fails (the Simulator does this), and UnderlineEngine drops a phrase whose model call fails, so then
  the engine uses its rules only. A chapter where a model call still fails isn't saved. AppContainer passes it in; tests don't,
  so they never call the model.
- `Svc/CloudSvc`: CloudKit records, with a 10-second timeout so the app never waits long for iCloud. The reader menu shows
  `CloudSvc.account` (checked in the background when a book opens and when the app comes back; only Settings can sign in).
- `Repo/RatingRepo`: the reader's thumbs up / down, in `ratings.json`. The first rating asks whether to share. Shared ratings go to
  the public database (record type `UnderlineRating`) with the phrase, its sentence and the reference passage, sentences counted
  from the chapter's start like UnderlineEngine's golden set. Taking a rating back deletes its record. One send runs at a time;
  what can't be sent yet is retried when a book opens. See `docs/ICLOUD.md` for the CloudKit Console.
- `Ctrl/RefCtrl`: underline updates for a page, marks, and an underline by ID. `Ctrl/RatingCtrl`: builds an `UnderlineRating`
  from a `SavedUnderline` and the book's text, and the share answer, unsent ratings and iCloud account.
- `Debug/UnderlineDebugView` (DEBUG; ladybug button or ⌘⇧D, made by `ReaderVM.makeUnderlineDebugVM`): every phrase the engine
  considered, kept or dropped and why, plus an iCloud section: the account, where this chapter's underlines came from or went,
  and the ratings waiting to be sent. Its `RefCtrl` and `RatingCtrl` reads live in `UnderlineDebugVM.swift`, as they use
  UnderlineEngine's records.
- `Rules/ChapterInputMapper`: one chapter of `BookContent` → UnderlineEngine's `ChapterInput` (same indexes and ranges), for
  `UnderlineRepo`; and the first sentence on a page, for `RefCtrl`.

## Testing & CI

**Run the tests.** In Xcode, ⌘U runs the Unit plan. From the terminal:

```sh
xcodegen generate
xcodebuild test -project iRead.xcodeproj -scheme iRead -testPlan Unit -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)'
```

**Unit vs Full.** Both plans (`Unit.xctestplan`, `Full.xctestplan`, next to `project.yml`) run every test in parallel, in random order,
with code coverage for `iRead`. Unit (the default) skips tests tagged `.golden`; Full runs them too. The golden tests compare
real books with stored snapshots: BK-13 (chapter counts of the bundled books).

**How the tests are written.** Swift Testing (`@Suite`, `@Test`, `#expect`) in `Tests/`, in the same folders as `App/`.
Each test is named by its ID in `docs/TEST_CASES.md`. A real bug the tests found is wrapped in `withKnownIssue` until it is fixed.
- Every test gets its own temp folder (`TempFolder` in `Tests/Support/`); repos take it as `init(folder:)`.
- `EventSvc`, `EPUBParseSvc`, `PagerSvc` and `CloudSvc` are protocols so tests can use the fakes in `Tests/Support/Fakes.swift`.
  The app uses `EventSvcOSLog`, `EPUBParseSvcEPUBKit`, `PagerSvcTextKit` and `CloudSvcCloudKit`. Tests never reach iCloud.
- Tests never call Foundation Models directly (CI simulators don't have it).

**Fixtures** are small EPUBs in `Tests/Fixtures/`, made by `sh Tests/Fixtures/make-fixtures.sh` (the `.epub` files are committed too).
`BookContent.make(chapters:)` builds book content with the parser's own code, so its ranges match a parsed book.

**CI.** Xcode Cloud tests the `iRead` scheme on every pull request into `dev` or `main` and on every push to `dev`.
After cloning, it runs `ci_scripts/ci_post_clone.sh`: it installs XcodeGen, generates the project and lets the SwiftLint
plugin run without the "Trust & Enable" click. Xcode Cloud never resolves packages itself: it builds the versions in the committed
`iRead.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, the only committed file of the generated project.
After changing a package in `project.yml`, regenerate, let Xcode resolve, and commit `project.yml` and `Package.resolved` together.

**App identity.** The bundle ID (`com.aftrhours.reader`) and display name are set once, in `project.yml`. The display name can
change any time. **Never change the bundle ID after the first upload to App Store Connect.**
