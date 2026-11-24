# iRead architecture

iPhone and iPad reader app (iPhone in portrait only). SwiftUI, Swift 6, iOS 26, XcodeGen (`project.yml` → `iRead.xcodeproj`). Packages: EPUBKit (local, in `Packages/EPUBKit`, on ZIPFoundation) reads EPUB files; [UnderlineEngine](https://github.com/AftrHours/UnderlineEngine) (from GitHub, pinned to one commit in `project.yml`) finds the phrases to underline. The app links only its `UnderlineKit` library, the engine's contract (see `CONTRACT.md` in that repo).

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
  Analysis/   the AI feature: underlines with their reference passages (UnderlineKit), and the readers' ratings of them
    Models/   SavedUnderline: the app's own copy of an underline the engine found; UnderlineRating; ContextPassage; Mark
    Svc/      CloudSvc: iCloud records through CloudKit (the reader's private database, and the developers' public one)
    Debug/    DEBUG-only underline debug sheet
  Reader/     reading page: paging, progress, settings, search, contents, reference cards

Shared/       compiled into both the app and the Share extension
  AppGroup.swift      the folder the two share (group.com.aftrhours.reader)
  Import/     sharing a book from Apple Books: AppleBooksLink, EditionMatcher and DuplicateRules (Rules),
              BookLookupSvc (iTunes Lookup, Gutenberg search) and DownloadSvc, PendingImportRepo and LibraryIndexRepo (App Group files),
              ShareCtrl and ShareVM (the sheet's logic, here so iReadTests can test it)
ShareExtension/  the Share extension target (iReadShare): ShareViewController reads the shared link, ShareView is the sheet
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
- Only `UnderlineRepo`, `ChapterInputMapper`, the DEBUG files in `Analysis/Debug/` and `AppContainer` (which picks the engine)
  import `UnderlineKit`. Nothing imports `UnderlineEngine`: its types are the engine's internals, behind the contract.
  Everything else uses `SavedUnderline`, so an engine update only touches those files, and usually none of them.
- Add a layer or type only when it does real work. A protocol is added when a test needs one.

## Naming

A type's last word says its layer:

| Suffix  | Job |
|---------|-----|
| `View`  | Renders only. Calls VM intents. |
| `VM`    | UI state, `@MainActor @Observable`. Receives intents (`xTapped`, `xChanged`, `onAppear`). |
| `Ctrl`  | One use case, orchestrating repos and services. |
| `Repo`  | Persists or caches data (files in Application Support, in-memory caches). Failed writes are logged to OSLog category `storage`. |
| `Svc`   | Wraps a system or framework API (EPUBKit, UIKit, OSLog, CloudKit). |
| `Rules` | Pure functions, no state, no I/O. |
| `Models`| Plain data. |
| `Knobs` | Constants worth tuning, next to the type that uses them (`UnderlineRepoKnobs.engineVersion`). |

Names that are easy to mix up:

- **Ref = Reference.** `RefCtrl`, `RefCardView`, `ReferenceVM` and `ReferenceCard` are all about the reference: the earlier
  passage that explains an underline. **Rating** is the reader's thumbs up / down on that reference (`RatingVM`, `RatingCtrl`,
  `RatingRepo`, `UnderlineRating`, `Verdict`).
- **Ours or the engine's.** `SavedUnderline` and `ContextPassage` are the app's. `Underlining`, `Underliner`, `BookSource`,
  `ChapterText`, `UnderlineResult`, `UnderlineBatch` and `ConsideredPhrase` come from `UnderlineKit`: `Underliner` is the
  engine's entry point, not one of our types.
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
| `ReaderVM` (parent) | Pages, shown page, the screen's `PageLayout`, what the pagers draw (`PageContent`), light or dark page, settings panel or sheet, show/hide controls, menu, back, contents, search, saving progress in page-turn order | `ReaderCtrl`, `ProgressCtrl`, `ReaderStateCtrl` (handed to `SearchVM`), `AppNav` + 3 children |
| `ReaderSettingsVM` | Settings, layout settings, brightness, text size, line spacing, theme | `ReaderStateCtrl` |
| `ReferenceVM` | Marks, following underlines for the shown chapter, reference cards, highlight, jump and return (`returnPrompt`: none, the return button on, or "Returned to page N"; `returnPageNumber` for the progress bar's mark). `jumpToPassage(_:)` is the one jump, used by the card and the character list | `RefCtrl`, `ReaderStateCtrl`, `ReaderCtrl` |
| `CharacterVM` | "Characters so far": the characters up to the shown page, the most recently mentioned first, one opened row, search with its own recent searches. Jump to Passage goes through `onJump` → `ReferenceVM.jumpToPassage` | `CharacterCtrl`, `ReaderStateCtrl` |
| `RatingVM` | Thumbs on the shown card, the share question, the Share Ratings switch, the iCloud row in the menu | `RatingCtrl` |
| `SearchVM` | Search query (searched once typing pauses for 300 ms, 2 characters or more), results and recent searches | `ReaderCtrl.search` (passed in as a closure, so tests can count searches), `ReaderStateCtrl` |

`ReaderSettingsVM` and `ReferenceVM` share one `ReaderStateCtrl` per open book.
`RefCtrl` (underlines and marks: `BookContentRepo`, `UnderlineRepo`) and `RatingCtrl` (ratings: `BookContentRepo`, `UnderlineRepo`
to look up the rated underline, `RatingRepo`) share one `UnderlineRepo` for the whole app.
`RefCardView` and `ReaderMenuView` get `RatingVM` directly.

### The page on screen

Pages fill the whole screen, and each carries its own book and chapter titles and page label, so all of it turns together.
Nothing is decided in a view: `ReaderVM` holds the state and the views draw it.

| Type | Layer | Job |
|---|---|---|
| `ScreenGeometry` | Models | The screen's size and safe area. `ReaderView` reads it (only a view can) and hands it to `ReaderVM.screenChanged` |
| `PageLayout` | Models | Where the header, text and footer go, from the screen alone. Its `viewport` is what pagination uses. Sizes are in `PageLayoutKnobs`, which the bars use too |
| `PageContent`, `PageChrome` | Models | Everything the pagers draw: pages, shown page, settings, layout, marks, titles and labels, the underline last tapped. Plain data, so a pager can tell nothing changed |
| `PageTurnRules`, `PageTurnKnobs` | Rules | Whether a released Slide carries on, which way a Fast Fade swipe points, how far a drag has gone, where a tap lands; and how long and how far a turn feels |
| `PageArea` | View | Shows the pager of the chosen style and hosts the reference card |
| `PageSlideView` → `PageSlider` | View (UIKit) | Slide and Fast Fade: moves the pages and runs the animation (one `Turn` state: idle, dragging, animating) |
| `PageTurnView` | View (UIKit) | Curl, on `UIPageViewController` |
| `PageViewCache`, `PageTextView` | View (UIKit) | Built pages kept ready; one page drawn, tapped and highlighted |

The two pagers take one input, `PageContent`, and report through `PageActions` (page turned, middle tapped, underline tapped).
What stays in the UIKit views is drawing and animation: the gestures, the animators and the text layout.

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
2. → `ImportCtrl.importBook(from:)` → `LibRepo.readEPUB(at:)` (`EPUBParseSvc.metadata` and one full parse for the fingerprint,
   plus the Gutenberg number from `dc:identifier`) → `DuplicateRules.checkDuplicates` against the visible books: a match throws
   `ImportError.alreadyInLibrary`; a match with a hidden sample shows the sample again instead (`LibRepo.showHiddenSample`).
3. → `LibRepo.saveBook(from:as:)` copies to `Books/<id>/book.epub` and appends it to `library.json` (imported books only, never the samples).
4. → `LibCtrl.loadLibrary`, then `ImportCtrl.refreshIndex`. The new book stays pinned first until `LibVM.sortChanged`.
5. A duplicate never stops the files after it; problems are listed in one alert at the end. Every import (picker,
   Open in iRead, shared books) runs one at a time through `LibVM.oneAtATime`, so two can't add the same book together.

**Open in iRead** (an EPUB from Files, Safari, Mail or AirDrop)
- `project.yml` registers `org.idpf.epub-container` (`LSHandlerRank: Alternate`, not opened in place), so iOS copies the file
  into `Documents/Inbox` and opens the app. `iReadApp.onOpenURL` → `LibVM.fileOpened` → the same `ImportCtrl.importBook`.
  The Inbox copy is deleted afterwards. A duplicate shows the "Couldn’t import EPUB" alert. The reader is never opened.

**Share from Apple Books** (Share Book → iRead; Apple Books shares a store link, never the file)
1. `ShareViewController.collectAttachments` → `AppleBooksLink.readLink` (every attachment in every type; the Apple Books
   link wins) → `ShareView` → `ShareVM.onAppear`.
2. → `ShareCtrl.findFreeEdition`, within 30 s: `AppleBooksLink.readListingID` (ID and country) → `BookLookupSvc.lookUpListing`
   (iTunes Lookup) → `BookLookupSvc.searchGutenberg` (Gutenberg's OPDS search) → `EditionMatcher.matchEdition` →
   `DuplicateRules.checkDuplicates` against `LibraryIndexRepo.readIndex` (the index the app writes) → `DownloadSvc.downloadEPUB`
   (100 MB at most). Every failure is a message in the sheet (`ShareVM.sheetText`) with Send off.
3. Send → `ShareCtrl.saveForApp` → `PendingImportRepo.writePending`: `PendingImports/<id>/book.epub` and `edition.json` in the App Group.
   The sheet closes; the reader stays in Apple Books.
4. Next time the app is active (`LibVM.onAppear`, or `LibView` seeing `scenePhase == .active`) → `LibVM.appBecameActive` →
   `ImportCtrl.importPending`: `PendingImportRepo.readPending`, each file goes through `importBook`, then `removePending`; a duplicate or broken file is logged (`storage`) and dropped,
   with nothing shown. Then `ImportCtrl.refreshIndex` → `LibraryIndexRepo.writeIndex`.

**Book "…" menu in the library**
- Mark as Finished / Still Reading → `LibCtrl.setFinished` → `ProgRepo.setFinished` (keeps the reading position).
- Reset Progress → `LibCtrl.resetProgress` → `ProgRepo.resetProgress` (a saved 0% record, so samples don't fall back to mock progress).
- Remove → alert → `LibCtrl.remove` → `LibRepo.remove`: imported books are deleted; sample books are added to `Books/hidden-samples.json`.
  Then `BookContentRepo.forget` drops the book's parse and cover from memory.

**Open a book**
1. `LibVM.bookTapped` → `AppNav.openReader(book:)`.
2. `iReadApp` sees the route change → `AppContainer.makeReaderVM(book:)` (once per open) → `ReaderView`.
3. `ReaderView.task` → `ReaderVM.onAppear` (the book opens, and the first page waits for the screen to be measured):
   1. `ReaderCtrl.openBook` → `BookContentRepo.content(for:)` → `EPUBParseSvc.parse`
      (imported `book.epub` first, then the bundled EPUB named in `BookRecord.samples`; one parse per book even with concurrent callers;
      only the 2 most recently used books stay parsed in memory).
   2. `ReaderSettingsVM.bookOpened` → `ReaderStateCtrl.settings`.
   3. `ProgressCtrl.savedProgress` → `ReaderCtrl.restorePosition(from:)` → `ProgressCtrl.positionRestored`.
   4. `ReferenceVM.bookOpened` → `ReaderStateCtrl.load`. `RatingVM.bookOpened` → `RatingCtrl.sharesRatings`, then in the background
      `RatingCtrl.cloudAccount` and `RatingCtrl.sendUnsentRatings` (again on `appForegrounded`).
   5. `ReaderVM.showCurrentPage` (once the screen has been measured: `ReaderVM.screenChanged`) → `ReaderCtrl.currentPage(viewport: layout.viewport)` → `PagerSvc.pageRanges`.
   6. `ReferenceVM.update` sees a new chapter → `RefCtrl.underlineUpdates(from:)` → `UnderlineRepo.underline(chapter:of:startingAt:)`
      (a finished chapter loads from `Underlines/<fingerprint>/`, or else from the reader's iCloud; otherwise the engine's
      `underlines(inChapter:of:startingAt:)` runs from the page's first sentence, then wraps, reading the book through
      `BookContent`'s `BookSource` conformance, and each `UnderlineResult` becomes `SavedUnderline`). Books are named by `BookContent.fingerprint`, so the same book matches on every device.
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
   → `ReaderStateCtrl.clearReturnPosition` → `onShowPage`, and the page label reads "Returned to page N" for 2 seconds.

## Analysis

- `Repo/UnderlineRepo`: asks the engine for one chapter at a time (starting another stops the running one) through
  `UnderlineKit`'s `Underlining`, and turns each `UnderlineResult` it returns into `SavedUnderline` (only what the app uses:
  phrase, kind, decided by, its reference passage). Only `SavedUnderline` is kept in memory, saved and uploaded.
  The engine is made once, the first time a chapter needs it, by the `makeUnderliner` closure: `AppContainer` passes
  `Underliner.make(.release)`; tests get the default `.testing`, the same method with an embedding that needs no download.
  Which method and embedding `.release` means (today rules only, contextual embedding) is decided inside the engine; the app
  doesn't ask Apple's on-device model.
  A finished chapter is saved on disk (`Underlines/<fingerprint>/`) and in the reader's iCloud (private database, record type
  `ChapterUnderlines`, named `<fingerprint>-<chapter>`), with the parser and engine versions. `UnderlineRepoKnobs.engineVersion`
  is the engine's own `Underliner.releaseVersion`, so an engine release that changes the underlines redoes chapters by itself,
  and the bundled seeds in `App/Resources/UnderlineSeed/` are ignored until they are regenerated. A chapter not on disk is looked for in iCloud
  before the engine runs, so another device, a reinstall or a re-import doesn't underline it again. A chapter from another
  version is underlined again. Without iCloud everything still works on the device.
- `Svc/CloudSvc`: CloudKit records, with a 10-second timeout so the app never waits long for iCloud. The reader menu shows
  `CloudSvc.account` (checked in the background when a book opens and when the app comes back; only Settings can sign in).
- `Repo/RatingRepo`: the reader's thumbs up / down, in `ratings.json`. The first rating asks whether to share. Shared ratings go to
  the public database (record type `UnderlineRating`) with the phrase, its sentence and the reference passage, sentences counted
  from the chapter's start like UnderlineEngine's golden set. Taking a rating back deletes its record. One send runs at a time;
  what can't be sent yet is retried when a book opens. See `docs/ICLOUD.md` for the CloudKit Console.
- Characters: `Svc/NameSvc` finds people's names in a chapter with NaturalLanguage (the tagger the engine uses inside; the engine
  doesn't hand names out) and keeps a title in front ("Mr. Laurence"). `Rules/CharacterRules` joins a person's names: common English
  nicknames (`CharacterRulesKnobs`) and pet forms of a name in the book ("Johnny" for John), unless the book tells them apart
  (different surnames, "Josie Pye"/"Josephine Barry", or a name mostly said with a title, "Lady Catherine"/Kitty); names the book says are one person ("…so I made them say Laurie instead"), "Miss Jo" with Jo; a titled
  surname stays its own person and a bare surname joins its one owner or is left out ("March"). `CharacterRules+People` keeps
  only people: not ordinary words ("Good": mostly written in lowercase), places ("in Washington"), groups ("Germans",
  "the Brookes"), parts of longer names ("Christmas Eve"), titles alone, or names only in dialogue. Ordered by latest mention.
  The Project Gutenberg licence is skipped.
  `Rules/DescriptionRules` picks the passage that describes each one, the way novels do: the name as the subject of "was"/"had",
  looks and temperament words in their own part of the sentence, an age, "a … girl", carried on into the sentences about them;
  not dialogue-only lines, nor sentences mostly about "her" for a man (and the other way round). A strong description that names
  no one goes to the nearest character named before it whose gender matches (from a title, else "he"/"she" after the name).
  The engine's passages explain underlined phrases and rarely hold these introductions, so the text is read directly.
  `Ctrl/CharacterCtrl` runs it from the first chapter to the end of the shown page. Jump to Passage goes through
  `ReferenceVM.jumpToPassage`, the same jump as the reference card.
- `Ctrl/RefCtrl`: underline updates for a page, marks, and an underline by ID. `Ctrl/RatingCtrl`: builds an `UnderlineRating`
  from a `SavedUnderline` and the book's text, and the share answer, unsent ratings and iCloud account.
- `Debug/UnderlineDebugView` (DEBUG; ladybug button or ⌘⇧D, made by `ReaderVM.makeUnderlineDebugVM`): the engine's one-line
  `summary`, every phrase it considered, kept or dropped and why (its `ConsideredPhrase` lines, shown as they come: their wording
  is the engine's and isn't parsed), plus an iCloud section: the account, where this chapter's underlines came from or went,
  and the ratings waiting to be sent. Its `RefCtrl` and `RatingCtrl` reads live in `UnderlineDebugVM.swift`, as they use
  `UnderlineKit`'s debug types.
- `Rules/ChapterInputMapper`: `BookContent`'s conformance to `UnderlineKit`'s `BookSource`, so the engine reads one chapter's
  paragraphs and sentences when it asks for them (same global indexes and UTF-16 ranges, nothing converted); and
  `firstSentence(on:in:)`, the first sentence on a page, for `RefCtrl`.

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
- Tests never call Foundation Models (CI simulators don't have it). Tests that underline use the engine's `.testing` preset;
  `UnderlineKit`'s `StubUnderliner` is there for a test that needs no engine at all.

**Fixtures** are small EPUBs in `Tests/Fixtures/`, made by `sh Tests/Fixtures/make-fixtures.sh` (the `.epub` files are committed too).
`BookContent.make(chapters:)` builds book content with the parser's own code, so its ranges match a parsed book.

**CI.** Xcode Cloud tests the `iRead` scheme on every pull request into `dev` or `main` and on every push to `dev`.
After cloning, it runs `ci_scripts/ci_post_clone.sh`: it installs XcodeGen, generates the project and lets the SwiftLint
plugin run without the "Trust & Enable" click. Xcode Cloud never resolves packages itself: it builds the versions in the committed
`iRead.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`, the only committed file of the generated project.
After changing a package in `project.yml`, regenerate, let Xcode resolve, and commit `project.yml` and `Package.resolved` together.

**App identity.** The bundle ID (`com.aftrhours.reader`) and display name are set once, in `project.yml`. The display name can
change any time. **Never change the bundle ID after the first upload to App Store Connect.**
