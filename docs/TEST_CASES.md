# iRead test cases

Major logic only, no small UI. **P0** must exist before CI is switched on; **P1** comes next.
Golden tests (marked "Full plan") run only in the Full test plan.
UnderlineEngine's own phrase picking is tested in its own repo; here we only test how iRead calls it and stores results.

Test setup this list assumes:
- Repos take a folder (`init(folder:)`) so each test uses a fresh temp folder.
- Protocols exist for `EventSvc` (count events), `EPUBParseSvc` (count parses), `PagerSvc` (fixed page ranges) and
  `CloudSvc` (`CloudSvcFake`: iCloud in memory, or offline). Tests never reach iCloud.
- Never call Foundation Models directly (CI simulators don't have it).
- Fixtures in `Tests/Fixtures`: `minimal.epub` (2 chapters × 3 paragraphs), `no-chapters.epub`, `corrupt.epub`,
  `epub2-cover.epub`, `epub3-cover.epub`, `no-metadata.epub`; plus a `BookContent.make(chapters:)` helper.

## Library

| ID | Pri | Unit | Given / When | Expected |
| --- | --- | --- | --- | --- |
| LIB-01 | P0 | `LibrarySorter` | Titles "banana", "Apple", "cherry"; sort `.title` | Apple, banana, cherry (case ignored) |
| LIB-02 | P0 | `LibrarySorter` | Sort `.author` | Alphabetical by author, case ignored |
| LIB-03 | P0 | `LibrarySorter` | Sort `.dateAdded` | Newest first |
| LIB-04 | P0 | `LibrarySorter` | Sort `.latestRead`; one book never read (`lastReadAt` nil) | Most recent first; unread last |
| LIB-05 | P0 | `LibrarySorter` | Sort `.readProgress` with 0.2, 0.9, 0.5 | 0.9, 0.5, 0.2 |
| LIB-06 | P0 | `LibrarySorter` | Any sort, `pinning:` the book that would sort last | Pinned book first; rest keep sort order |
| LIB-07 | P0 | `LibRepo.fetchBooks` | No files on disk | All bundled samples, none imported |
| LIB-08 | P0 | `LibCtrl.loadLibrary` | Saved progress has `finishedAt` set and `progress` 0.4 | Shows 1.0; `lastReadAt` from the progress file |
| LIB-09 | P0 | `LibRepo.importBook` | Import `minimal.epub` | `Books/<id>/book.epub` exists; `library.json` has one entry with EPUB title/author, progress 0 |
| LIB-10 | P0 | `LibRepo.importBook` | Import `no-metadata.epub` named "My Book.epub" | Title "My Book", author "Unknown Author" |
| LIB-11 | P0 | `LibRepo.importBook` | Import `corrupt.epub` | Throws `ContentError.unreadable`; nothing copied; `library.json` unchanged |
| LIB-12 | P0 | `LibRepo.remove` | Remove an imported book | Folder deleted; gone from `library.json` and `fetchBooks` |
| LIB-13 | P0 | `LibRepo.remove` | Remove a sample book | ID added to `hidden-samples.json`; not returned by `fetchBooks`; bundle untouched |
| LIB-14 | P1 | `LibRepo.fetchBooks` | Old `library.json` also lists sample IDs | Each sample appears once |
| LIB-15 | P1 | `LibRepo.importBook` | Import the same file twice | Two books with different IDs (or a clear error, if the team decides to block duplicates) |
| LIB-16 | P1 | `LibVM` | Import, then change sort | New book first after import; after `sortChanged` it moves to its sorted place |
| LIB-17 | P1 | `LibCtrl` + `ProgRepo` | Mark finished, then "Still Reading" | Shows 1.0, then returns to saved progress and position |
| LIB-18 | P0 | `LibCtrl.remove` | Imported book parsed and cover read; remove it | Cover nil; content throws `ContentError.notFound` (not served from memory) |
| LIB-19 | P1 | `LibCtrl.loadLibrary` | Saved progress for one sample only; one imported book | That sample shows its saved progress; other books keep their own; `LibRepo.fetchBooks` alone returns no progress |

## Book parsing

| ID | Pri | Unit | Given / When | Expected |
| --- | --- | --- | --- | --- |
| BK-01 | P0 | `EPUBParseSvc.parse` | `minimal.epub` | 2 chapters × 3 paragraphs; each paragraph's `chapterIndex` right; `chapter.paragraphs` covers exactly its own |
| BK-02 | P0 | `EPUBParseSvc.parse` | `minimal.epub` | Substring at each paragraph `range` equals source paragraph; paragraphs separated by one `\n` |
| BK-03 | P0 | `EPUBParseSvc.parse` | Any book | Every sentence range inside its paragraph; no leading/trailing whitespace |
| BK-04 | P0 | `EPUBParseSvc.parse` | "Mr. Darcy bowed. She left." | 2 sentences, not 3; ranges match original text |
| BK-05 | P0 | `EPUBParseSvc.parse` | `no-chapters.epub` / `corrupt.epub` (also `metadata` and `cover` for `corrupt.epub`) | All throw `ContentError.unreadable` |
| BK-06 | P1 | `EPUBParseSvc.parse` | Text with emoji and accents | UTF-16 ranges still line up |
| BK-07 | P1 | `EPUBParseSvc.metadata` / `.cover` | EPUB2 cover, EPUB3 cover, no cover | Title/author read; cover found for both styles; nil when none |
| BK-08 | P0 | `BookContentRepo.content` | Two concurrent calls for one book | One parse (spy = 1); same content to both |
| BK-09 | P1 | `BookContentRepo.content` | First parse fails, retry succeeds | Failure not cached |
| BK-10 | P0 | `BookContentRepo` | Unknown book ID | Throws `ContentError.notFound` |
| BK-11 | P1 | `BookContentRepo` | ID both imported and sample | Imported `book.epub` used |
| BK-13 | P1 | Golden (Full plan) | Parse all 5 bundled samples | No throw; chapter counts match stored snapshot (a change means bump `parserVersion`) |
| BK-14 | P0 | `BookContentRepo.content` | Open books A, B, C, then B, C, then A twice at once, then C, then B | Only 2 books kept: A parsed again once (shared by both callers), then B parsed again |
| BK-15 | P1 | `BookContentRepo.forget` | Book parsed and cover read; forget | Parsed again on next call; cover not served from memory |
| BK-16 | P0 | `BookFingerprint` | Same chapters twice; one word changed; same text in other chapter breaks | Same fingerprint; different; different |

## Reading progress

| ID | Pri | Unit | Given / When | Expected |
| --- | --- | --- | --- | --- |
| PR-01 | P0 | `ReadingProgressCalculator.progress` | First page | progress 0; position (0, 0); `finishedAt` nil |
| PR-02 | P0 | `ReadingProgressCalculator.progress` | Page starting at paragraph 3 | progress = words in paragraphs 0–2 ÷ total words |
| PR-03 | P0 | `ReadingProgressCalculator.progress` | Last page of last chapter | `finishedAt` = given date |
| PR-04 | P0 | `ReadingProgressCalculator.progress` | progress ≥ 0.99, not last page | `finishedAt` set |
| PR-05 | P0 | `ReadingProgressCalculator.merged` | Previous frontier 40, new 25 | Frontier stays 40; position is the new page's |
| PR-06 | P0 | `ReadingProgressCalculator.merged` | Previous `finishedAt` set, new not finished | Earlier `finishedAt` kept |
| PR-07 | P0 | `ReadingProgressCalculator.position` | Offset at paragraph start; on the `\n`; 0 | Right paragraph and `charOffset`; never negative |
| PR-08 | P0 | `ProgRepo` | `saveNow` then `progress(for:)` | Equal (ISO 8601 dates round-trip) |
| PR-09 | P0 | `ProgRepo.save` | Three quick saves | File holds the third |
| PR-10 | P0 | `ProgRepo.setFinished` | At paragraph 120: true, then false | `finishedAt` set then nil; position stays 120 |
| PR-11 | P0 | `ProgRepo.resetProgress` | Book at 60% | File exists with 0 / (0,0) / frontier 0 / not finished; `lastReadAt` kept |
| PR-12 | P1 | `ProgRepo.progress` | Invalid JSON on disk | nil, no crash |
| PR-13 | P0 | `ProgressCtrl.pageRead` | Read to last page, then last page again | `bookFinished` logged exactly once |
| PR-14 | P1 | `ProgressCtrl.pageRead` | Book already finished before opening | No `bookFinished` |
| PR-15 | P1 | `ProgressCtrl.saveNow` | Before any page read | Writes nothing, no crash |

## Reader

Use a fake `PagerSvc` that splits every N characters for `ReaderCtrl`; test the real `PagerSvc` alone (RD-10..12).

| ID | Pri | Unit | Given / When | Expected |
| --- | --- | --- | --- | --- |
| RD-01 | P0 | `ReaderCtrl.restorePosition` | Valid saved position | true; `currentPage` contains it |
| RD-02 | P0 | `ReaderCtrl.restorePosition` | Paragraph past end, or `charOffset` past length | false; opens at start of saved chapter |
| RD-03 | P0 | `ReaderCtrl.restorePosition` | Invalid position and `chapterIndex` | Chapter 0, no crash |
| RD-04 | P0 | `ReaderCtrl.pages(around:)` | Middle / first / last page | 5 pages / first + 2 after / 2 before + last |
| RD-05 | P0 | `ReaderCtrl` | Last page of ch 1 → next | Ch 2 first page; page numbers continue |
| RD-06 | P0 | `ReaderCtrl.currentPage` | Change text size, spacing, theme or viewport | Re-laid out; page still contains position |
| RD-08 | P0 | `ReaderCtrl.range(from:length:on:)` | On page / other chapter / crossing page end | Page-relative range / nil / clipped |
| RD-09 | P0 | `ReaderCtrl.pageChanged` | Turn to a page | Progress has page's start; next `currentPage` is that page |
| RD-10 | P0 | `PagerSvc.pageRanges` | Long text, fixed iPad viewport | Contiguous 0→end; no gaps, overlaps, empty pages |
| RD-11 | P1 | `PagerSvc.pageRanges` | Empty string | One range of length 0 |
| RD-12 | P1 | `PagerSvc.pageRanges` | Text size index 3 vs 8 | More pages at 8 |
| RD-13 | P0 | `BookSearch.matches` | "cafe" vs "Café" and "CAFE" | Both match; snippet is the sentence |
| RD-14 | P0 | `BookSearch.matches` | Match mid-sentence in paragraph 7 | Position (7, match offset); length = match length |
| RD-15 | P1 | `BookSearch.matches` | No match / empty query | Empty, no crash (decide empty-query behavior) |
| RD-16 | P0 | `ReaderCtrl.search` | Match in chapter 3 | `pageNumber` == `page(containing:)` number |
| RD-17 | P0 | `ReaderStateCtrl` recents | Save "Darcy", "bingley", "darcy" | "darcy", "bingley" |
| RD-18 | P1 | `ReaderStateCtrl` recents | 12 queries | 10 kept, newest first; clear empties |
| RD-19 | P0 | `ReaderStateCtrl` return position | Save A, save B, reload | A kept; survives reload; clear removes |
| RD-21 | P1 | `ReadingSettings` | `textSizeIndex` -1 and 99 | 17 and 56 |
| RD-22 | P1 | `ReadingSettingsRepo` | No file / save then read | Defaults / saved |
| RD-23 | P1 | `ReferenceVM` | Jump to passage, then Return | Return position saved on jump; return shows original page and clears it |
| RD-24 | P0 | `ReferenceVM.close` | Chapter underlining running; close the reader | Underline task cancelled and not restarted by a page update or `appForegrounded`; `ReferenceVM` released |
| RD-25 | P0 | `ReaderCtrl.search` | Search cancelled before it runs | No results; no chapters laid out; a later search still finds matches |
| RD-26 | P0 | `SearchVM` | Results shown; query changes to " A " | Results cleared; no search |
| RD-27 | P0 | `SearchVM` | Type "A", "An", "Ann", "Anna" quickly | One search, for "Anna", after the typing pause |
| RD-28 | P0 | `SearchVM` | Slow search for "Anna", then "Darcy" from recent searches | "Darcy" results stay after the "Anna" search returns |
| RD-29 | P0 | `RatingVM` | Thumbs up on a card; answer "Don't Share"; thumbs down; thumbs down again | Filled and asked once; switches without asking; rating taken back |
| RD-30 | P1 | `RatingVM.cardShown` | Thumbs up, then show the same card again at once | Thumbs up shown, read back after the save |

## Underlines and references

The app's only AI feature: phrases worth underlining, each with the earlier passage that explains it.

| ID | Pri | Unit | Given / When | Expected |
| --- | --- | --- | --- | --- |
| AN-01 | P0 | `ChapterInputMapper.input` | 3-chapter book, map ch 1 | Only ch 1 paragraphs/sentences; global indexes kept; text equals substring |
| AN-02 | P0 | `ChapterInputMapper.firstSentence` | Page starts mid-sentence | That sentence's index |
| AN-03 | P0 | `UnderlineRepo` | Finish a chapter; new repo, same folder | Yields once and finishes without running engine; loads from disk |
| AN-04 | P0 | `UnderlineRepo` | Stored chapter has older `parserVersion` | Underlined again |
| AN-05 | P1 | `UnderlineRepo` | Start ch 2 while ch 1 runs; restart ch 1 | Ch 1 not saved half-done; no duplicate IDs |
| AN-06 | P0 | `RefCtrl.marks` | Underline on page + one in other chapter | One `.underline` mark, page-relative; none for other |
| AN-07 | P0 | `RefCtrl.marks` | `highlighting:` an underline whose reference is on page | `.highlight` for it only |
| AN-09 | P1 | `RefCtrl.underline(withID:)` | Unknown ID | `ContentError.notFound` |
| AN-14 | P0 | `UnderlineRepo` | Stored chapter with the same / older / missing `engineVersion` (`UnderlineRepoKnobs`) | Loaded from disk / underlined again and saved with the current version |
| AN-15 | P0 | `UnderlineRepo` | Chapter in the reader's iCloud with the same / older engine version | Used without the engine and saved on disk / underlined again (debug sheet says which) |
| AN-16 | P0 | `UnderlineRepo` | Finish a chapter; a second device (new folder) with the same iCloud | Record saved in iCloud; the second device gets the same underlines |
| AN-17 | P1 | `UnderlineRepo` | iCloud offline or signed out | Chapter still underlined and saved on disk |
| AN-18 | P0 | `RatingRepo` | Rate before answering; then agree to share | Kept on device, nothing sent; then sent with its sentence and passage |
| AN-19 | P0 | `RatingRepo` | Sharing; rate up, then down, then take back | One record, "down"; then deleted |
| AN-20 | P1 | `RatingRepo` | Sharing; rate while offline; a later launch sends | Nothing sent while offline; sent later |
| AN-21 | P0 | `RatingRepo` | Say no; rate; turn sharing on; rate another | Nothing sent; only the new rating is sent |
| AN-22 | P0 | `RatingCtrl.rate` | Rate an underline in chapter 2 | Phrase, sentence and passage texts; sentence numbers count from the chapter's start |
| AN-23 | P1 | `UnderlineRepo.cloudAccount` | iCloud signed in; signed out; no iCloud | `.signedIn`; `.signedOut`; nil |
| AN-24 | P1 | `RatingRepo` | Rate up; rate down while the first send is still running | One record, "down"; nothing left waiting |
| AN-25 | P1 | `RatingCtrl.rate` | Underline not loaded | `ContentError.notFound` |
