# iRead architecture

iPad reader app. SwiftUI, Swift 6, iOS 26, XcodeGen (`project.yml` → `iRead.xcodeproj`). Packages: EPUBKit (local, in `Packages/EPUBKit`, on ZIPFoundation) reads EPUB files; [UnderlineEngine](https://github.com/AftrHours/UnderlineEngine) (from GitHub, pinned to one commit in `project.yml`) finds the phrases to underline.

## Folders and dependency direction

```
App/
  iReadApp.swift      switches on AppNav.route, nothing else
  AppContainer.swift  builds every repo, service, Ctrl and VM (the only type that knows them all)
  AppNav.swift        route: .library or .reader(book:)
  Resources/          bundled sample EPUBs (listed in BookRecord.samples)

  Book/       per-book data shared by every feature (BookRecord, BookContent, Page, ReadingProgress,
              BookContentRepo, ProgRepo, EPUBParseSvc)
  Library/    library page: list, sort, grid/list, EPUB import
  Analysis/   the AI features: underlines with their reference passages (UnderlineEngine), and character symbols
    AI/       the character engine behind symbols (see below)
    Debug/    DEBUG-only underline debug sheet
  Reader/     reading page: paging, progress, settings, search, contents, reference cards
```

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
- Add a layer or type only when it does real work. A protocol is added when a test needs one.

## What the suffixes mean

| Suffix  | Job |
|---------|-----|
| `View`  | Renders only. Calls VM intents. |
| `VM`    | UI state, `@MainActor @Observable`. Receives intents (`xTapped`, `xChanged`, `onAppear`). |
| `Ctrl`  | One use case, orchestrating repos and services. |
| `Repo`  | Persists or caches data (files in Application Support, in-memory caches). Failed writes are logged to OSLog category `storage`. |
| `Svc`   | Wraps a system or framework API (EPUBKit, UIKit, OSLog, Foundation Models). |
| `Rules` | Pure functions, no state, no I/O. |
| `Models`| Plain data. |

## Reader split

| Type | Job | Depends on |
|---|---|---|
| `ReaderCtrl` | Book content, current position, pages, page counts, search, position ↔ page | `BookContentRepo`, `PagerSvc` |
| `ProgressCtrl` | Restore and save progress, log restore and finished events | `ProgRepo`, `EventSvc` |
| `ReaderStateCtrl` | Reading settings, brightness, the "return to reading" position, edited symbols, recent searches | `ReadingSettingsRepo`, `BrightnessSvc`, `BookStateRepo` |
| `ReaderVM` (parent) | Pages, shown page, viewport, labels, show/hide controls, sheets, menu, back, contents, search, saving progress in page-turn order | `ReaderCtrl`, `ProgressCtrl`, `ReaderStateCtrl` (handed to `SearchVM`), `AppNav` + 2 children |
| `ReaderSettingsVM` | Settings, layout settings, brightness, text size, line spacing, theme, symbols toggle | `ReaderStateCtrl` |
| `ReferenceVM` | Marks, following underlines for the shown chapter, reference and symbol cards, chapter characters, edited symbols, highlight, jump and return, toast | `RefCtrl`, `ReaderStateCtrl`, `ReaderCtrl` |
| `SearchVM` | Search query, results and recent searches | `ReaderCtrl`, `ReaderStateCtrl` |

`ReaderSettingsVM` and `ReferenceVM` share one `ReaderStateCtrl` per open book.

State flows one way. `ReaderVM` pushes the shown page, the loaded pages and whether symbols are shown into
`ReferenceVM.update(shownPage:loadedPages:areSymbolsShown:)`. `ReaderVM.marks` hides underlines while the controls
are hidden (turning a page hides both; tapping the middle of the page shows both). Symbols and highlights always show. The children report back only through output callbacks:
`ReferenceVM.onShowPage`, `ReferenceVM.onEditSymbol` and `ReaderSettingsVM.onSettingsChanged`, the same way
`SearchVM` reports `onResultPicked`.

## Main flows

**Launch → library**
1. `iReadApp.init` → `AppContainer.init` builds `EPUBParseSvc`, `ProgRepo`, `BookContentRepo`, `LibRepo`, `AnalysisRepo`, `UnderlineRepo` once.
2. `AppContainer.makeLibVM` → `LibView`.
3. `LibView.task` → `LibVM.onAppear` → `LibCtrl.loadLibrary` → `LibRepo.fetchBooks`
   (the built-in sample books plus the imported books in `Books/library.json`, then `ProgRepo.progress(for:)` per book).
4. `LibVM.books` → `LibrarySorter.sorted(_:by:pinning:)`.
5. `LibVM.loadCovers` → `LibCtrl.cover(for:)` → `BookContentRepo.cover(for:)` → `EPUBParseSvc.cover(from:)`, shrunk to a thumbnail once.

**Import an EPUB**
1. `LibView` + button → `EPUBDocumentPicker` → `LibVM.importFiles`.
2. → `LibCtrl.importBook(from:)` → `LibRepo.importBook` → `EPUBParseSvc.metadata(from:)`,
   copies to `Books/<id>/book.epub`, appends it to `library.json` (imported books only, never the samples).
3. → `LibCtrl.loadLibrary`. The new book stays pinned first until `LibVM.sortChanged`.

**Book "…" menu in the library**
- Share Book → `LibVM.shareTapped` → `LibCtrl.shareableFile(for:)` → `BookContentRepo.shareableFile(for:)` (a copy named after the title) → share sheet.
- Mark as Finished / Still Reading → `LibCtrl.setFinished` → `LibRepo` → `ProgRepo.setFinished` (keeps the reading position).
- Reset Progress → `LibCtrl.resetProgress` → `LibRepo` → `ProgRepo.resetProgress` (a saved 0% record, so samples don't fall back to mock progress).
- Remove → alert → `LibCtrl.remove` → `LibRepo.remove`: imported books are deleted; sample books are added to `Books/hidden-samples.json`.

**Open a book**
1. `LibVM.bookTapped` → `AppNav.openReader(book:)`.
2. `iReadApp` sees the route change → `AppContainer.makeReaderVM(book:)` (once per open) → `ReaderView`.
3. `ReaderView.task` → `ReaderVM.onAppear`:
   1. `ReferenceVM.onAppear` → `RefCtrl.startAnalysis` → `AnalysisRepo` (characters for symbols, whole book, in the background).
   2. `ReaderCtrl.openBook` → `BookContentRepo.content(for:)` → `EPUBParseSvc.parse`
      (imported `book.epub` first, then the bundled EPUB named in `BookRecord.samples`; one parse per book even with concurrent callers).
   3. `ReaderSettingsVM.bookOpened` → `ReaderStateCtrl.settings`.
   4. `ProgressCtrl.savedProgress` → `ReaderCtrl.restorePosition(from:)` → `ProgressCtrl.positionRestored`.
   5. `ReferenceVM.bookOpened` → `ReaderStateCtrl.load`.
   6. `ReaderVM.showCurrentPage` → `ReaderCtrl.currentPage` → `PagerSvc.pageRanges`.
   7. `ReferenceVM.update` sees a new chapter → `RefCtrl.underlineUpdates(from:)` → `ChapterInputMapper` → `UnderlineRepo.underline`
      (UnderlineEngine from the page's first sentence, then wrapping; a finished chapter loads from `Books/<id>/underlines/`).
      Each update → `ReferenceVM.loadMarks`.

**Turn a page and save progress**
1. `PageTurnView.onPageChanged` → `ReaderVM.pageChanged` → `ReaderVM.show` → `ReferenceVM.update`.
2. → `ReaderCtrl.pages(around:)` → `ReferenceVM.update` → `ReferenceVM.loadMarks` → `RefCtrl.marks(on:highlighting:includingSymbols:)`.
3. → after the previous turn's save finishes, `ReaderCtrl.pageChanged(to:)` → `ReadingProgressCalculator.progress(on:in:bookID:at:)`.
4. → `ProgressCtrl.pageRead` → `ReadingProgressCalculator.merged` → `ProgRepo.save` (debounced),
   and `EventSvc.log(.bookFinished)` the first time the book is finished.
5. Back or app backgrounded → `ProgressCtrl.saveNow` → `ProgRepo.saveNow`.

**Tap an underline, jump, and return**
1. Controls shown → `PageTextView` → `PageTurnView.onMarkTapped` → `ReferenceVM.markTapped`
   → `RefCtrl.underline(withID:)`, `ReaderCtrl.page(containing:)` → `RefCardView` (the phrase and the passage that explains it).
   A tapped symbol → `RefCtrl.symbolCard(forMention:)` → `SymCardView`.
2. Jump to Passage → `ReferenceVM.jumpToPassageTapped` → `ReaderCtrl.startPosition(of:)` → `ReaderStateCtrl.saveReturnPosition`
   → `ReaderCtrl.page(containing:)` → `onShowPage` → `ReaderVM.show(_:highlighting:)`.
3. Return to Reading → `ReferenceVM.returnToReadingTapped` → `ReaderStateCtrl.returnPosition` → `ReaderCtrl.page(ifValid:)`
   → `ReaderStateCtrl.clearReturnPosition` → `onShowPage` and a 2-second toast.

## Analysis

- `Repo/UnderlineRepo`: runs UnderlineEngine's `UnderlineCtrl` on one chapter at a time, keeps its underlines in memory,
  and saves each finished chapter. Starting another chapter stops the running one. In DEBUG it also keeps every phrase's
  record (kept or dropped, and why) for `Debug/UnderlineDebugView` (ladybug button, or ⌘⇧D).
- `Rules/ChapterInputMapper`: one chapter of `BookContent` → UnderlineEngine's `ChapterInput` (same indexes and ranges).
- `Repo/AnalysisRepo` + `AI/`: the character engine. It finds characters and their mentions and gives each a symbol.
  - `AI/Models`: the data passed between steps and the on-device model (requests, answers, resolved analysis).
  - `AI/Rules`: pure steps that find, link and name character mentions and map them to a `BookAnalysis`.
  - `AI/Svc`: wrappers for the on-device language model, word tagging, model availability and the per-chapter pass.

## Testing & CI

**Run the tests.** In Xcode, ⌘U runs the Unit plan. From the terminal:

```sh
xcodegen generate
xcodebuild test -project iRead.xcodeproj -scheme iRead -testPlan Unit -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)'
```

**Unit vs Full.** Both plans (`Tests/Unit.xctestplan`, `Tests/Full.xctestplan`) run every test in parallel, in random order,
with code coverage for `iRead`. Unit (the default) skips tests tagged `.golden`; Full runs them too. The golden tests compare
real books with stored snapshots: BK-13 (chapter counts of the bundled books) and CH-27 (*Little Women* chapter 1).

**How the tests are written.** Swift Testing (`@Suite`, `@Test`, `#expect`) in `Tests/`, in the same folders as `App/`.
Each test is named by its ID in `docs/TEST_CASES.md`. A real bug the tests found is wrapped in `withKnownIssue` until it is fixed.
- Every test gets its own temp folder (`TempFolder` in `Tests/Support/`); repos take it as `init(folder:)`.
- `EventSvc`, `EPUBParseSvc` and `PagerSvc` are protocols so tests can use the fakes in `Tests/Support/Fakes.swift`. The app uses
  `EventSvcOSLog`, `EPUBParseSvcEPUBKit` and `PagerSvcTextKit`.
- Tests never use Foundation Models (CI simulators don't have it): they use `LLMSvcUnavailable`.

**Fixtures** are small EPUBs in `Tests/Fixtures/`, made by `sh Tests/Fixtures/make-fixtures.sh` (the `.epub` files are committed too).
`BookContent.make(chapters:)` builds book content with the parser's own code, so its ranges match a parsed book.

**CI.** Xcode Cloud tests the `iRead` scheme on every pull request into `dev` or `main` and on every push to `dev`.
After cloning, it runs `ci_scripts/ci_post_clone.sh`: it installs XcodeGen, generates the project and lets the SwiftLint
plugin run without the "Trust & Enable" click. Xcode Cloud never resolves packages itself: it builds the versions in the committed
`iRead.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, the only committed file of the generated project.
After changing a package in `project.yml`, regenerate, let Xcode resolve, and commit `project.yml` and `Package.resolved` together.

**App identity.** The bundle ID (`com.aftrhours.reader`) and display name are set once, in `project.yml`. The display name can
change any time. **Never change the bundle ID after the first upload to App Store Connect.**
