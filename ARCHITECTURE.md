# iRead architecture

iPad reader app. SwiftUI, Swift 6, iOS 26, XcodeGen (`project.yml` → `iRead.xcodeproj`), ZIPFoundation for EPUB.

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
  Analysis/   the AI feature: characters, mentions, symbols, reference passages
    AI/       analysis internals (see below)
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
| `Svc`   | Wraps a system or framework API (ZIPFoundation, UIKit, OSLog, Foundation Models). |
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
| `ReferenceVM` | Marks, reference and symbol cards, chapter characters, edited symbols, highlight, jump and return, toast | `RefCtrl`, `ReaderStateCtrl`, `ReaderCtrl` |
| `SearchVM` | Search query, results and recent searches | `ReaderCtrl`, `ReaderStateCtrl` |

`ReaderSettingsVM` and `ReferenceVM` share one `ReaderStateCtrl` per open book.

State flows one way. `ReaderVM` pushes the shown page, the loaded pages and whether symbols are shown into
`ReferenceVM.update(shownPage:loadedPages:areSymbolsShown:)`. The children report back only through output callbacks:
`ReferenceVM.onShowPage`, `ReferenceVM.onEditSymbol` and `ReaderSettingsVM.onSettingsChanged`, the same way
`SearchVM` reports `onResultPicked`.

## Main flows

**Launch → library**
1. `iReadApp.init` → `AppContainer.init` builds `EPUBParseSvc`, `ProgRepo`, `BookContentRepo`, `LibRepo`, `AnalysisRepo` once.
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
   1. `ReferenceVM.onAppear` → `RefCtrl.prepare` / `refine` → `AnalysisRepo` (in the background).
   2. `ReaderCtrl.openBook` → `BookContentRepo.content(for:)` → `EPUBParseSvc.parse`
      (imported `book.epub` first, then the bundled EPUB named in `BookRecord.samples`; one parse per book even with concurrent callers).
   3. `ReaderSettingsVM.bookOpened` → `ReaderStateCtrl.settings`.
   4. `ProgressCtrl.savedProgress` → `ReaderCtrl.restorePosition(from:)` → `ProgressCtrl.positionRestored`.
   5. `ReferenceVM.bookOpened` → `ReaderStateCtrl.load`.
   6. `ReaderVM.showCurrentPage` → `ReaderCtrl.currentPage` → `PagerSvc.pageRanges`.

**Turn a page and save progress**
1. `PageTurnView.onPageChanged` → `ReaderVM.pageChanged` → `ReaderVM.show` → `ReferenceVM.update`.
2. → `ReaderCtrl.pages(around:)` → `ReferenceVM.update` → `ReferenceVM.loadMarks` → `RefCtrl.marks(on:highlighting:includingSymbols:)`.
3. → after the previous turn's save finishes, `ReaderCtrl.pageChanged(to:)` → `ReadingProgressCalculator.progress(on:in:bookID:at:)`.
4. → `ProgressCtrl.pageRead` → `ReadingProgressCalculator.merged` → `ProgRepo.save` (debounced),
   and `EventSvc.log(.bookFinished)` the first time the book is finished.
5. Back or app backgrounded → `ProgressCtrl.saveNow` → `ProgRepo.saveNow`.

**Tap an underlined mention, jump, and return**
1. `PageTextView` → `PageTurnView.onMarkTapped` → `ReferenceVM.markTapped`
   → `RefCtrl.entity(forMention:)`, `RefCtrl.passage(forMention:)`, `ReaderCtrl.page(containing:)` → `RefCardView`.
2. Jump to Passage → `ReferenceVM.jumpToPassageTapped` → `ReaderCtrl.startPosition(of:)` → `ReaderStateCtrl.saveReturnPosition`
   → `ReaderCtrl.page(containing:)` → `onShowPage` → `ReaderVM.show(_:highlighting:)`.
3. Return to Reading → `ReferenceVM.returnToReadingTapped` → `ReaderStateCtrl.returnPosition` → `ReaderCtrl.page(ifValid:)`
   → `ReaderStateCtrl.clearReturnPosition` → `onShowPage` and a 2-second toast.

## Analysis/AI

- `AI/Models`: the data passed between analysis steps and the on-device model (requests, answers, rules pass, resolved analysis).
- `AI/Rules`: pure steps that find, link and name character mentions and map them to a `BookAnalysis`.
- `AI/Svc`: wrappers for the on-device language model, word tagging, model availability, tie-breaks and analysis scheduling.
