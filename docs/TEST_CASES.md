# iRead test cases

Major logic only, no small UI. **P0** must exist before CI is switched on; **P1** comes next.
Golden tests (marked "Full plan") run only in the Full test plan.
UnderlineEngine's own phrase picking is tested in its own repo; here we only test how iRead calls it and stores results.

Test setup this list assumes:
- Repos take a folder (`init(folder:)`) so each test uses a fresh temp folder.
- Protocols exist for `EventSvc` (count events), `EPUBParseSvc` (count parses) and `PagerSvc` (fixed page ranges).
- `LLMSvcUnavailable` or a scripted fake `LLMSvc`; never Foundation Models.
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
| LIB-08 | P0 | `LibRepo.fetchBooks` | Saved progress has `finishedAt` set and `progress` 0.4 | Shows 1.0; `lastReadAt` from the progress file |
| LIB-09 | P0 | `LibRepo.importBook` | Import `minimal.epub` | `Books/<id>/book.epub` exists; `library.json` has one entry with EPUB title/author, progress 0 |
| LIB-10 | P0 | `LibRepo.importBook` | Import `no-metadata.epub` named "My Book.epub" | Title "My Book", author "Unknown Author" |
| LIB-11 | P0 | `LibRepo.importBook` | Import `corrupt.epub` | Throws `ContentError.unreadable`; nothing copied; `library.json` unchanged |
| LIB-12 | P0 | `LibRepo.remove` | Remove an imported book | Folder deleted; gone from `library.json` and `fetchBooks` |
| LIB-13 | P0 | `LibRepo.remove` | Remove a sample book | ID added to `hidden-samples.json`; not returned by `fetchBooks`; bundle untouched |
| LIB-14 | P1 | `LibRepo.fetchBooks` | Old `library.json` also lists sample IDs | Each sample appears once |
| LIB-15 | P1 | `LibRepo.importBook` | Import the same file twice | Two books with different IDs (or a clear error, if the team decides to block duplicates) |
| LIB-16 | P1 | `LibVM` | Import, then change sort | New book first after import; after `sortChanged` it moves to its sorted place |
| LIB-17 | P1 | `LibRepo` + `ProgRepo` | Mark finished, then "Still Reading" | Shows 1.0, then returns to saved progress and position |

## Book parsing

| ID | Pri | Unit | Given / When | Expected |
| --- | --- | --- | --- | --- |
| BK-01 | P0 | `EPUBParseSvc.parse` | `minimal.epub` | 2 chapters × 3 paragraphs; each paragraph's `chapterIndex` right; `chapter.paragraphs` covers exactly its own |
| BK-02 | P0 | `EPUBParseSvc.parse` | `minimal.epub` | Substring at each paragraph `range` equals source paragraph; paragraphs separated by one `\n` |
| BK-03 | P0 | `EPUBParseSvc.parse` | Any book | Every sentence range inside its paragraph; no leading/trailing whitespace |
| BK-04 | P0 | `EPUBParseSvc.parse` | "Mr. Darcy bowed. She left." | 2 sentences, not 3; ranges match original text |
| BK-05 | P0 | `EPUBParseSvc.parse` | `no-chapters.epub` / `corrupt.epub` | Both throw `ContentError.unreadable` |
| BK-06 | P1 | `EPUBParseSvc.parse` | Text with emoji and accents | UTF-16 ranges still line up |
| BK-07 | P1 | `EPUBParseSvc.metadata` / `.cover` | EPUB2 cover, EPUB3 cover, no cover | Title/author read; cover found for both styles; nil when none |
| BK-08 | P0 | `BookContentRepo.content` | Two concurrent calls for one book | One parse (spy = 1); same content to both |
| BK-09 | P1 | `BookContentRepo.content` | First parse fails, retry succeeds | Failure not cached |
| BK-10 | P0 | `BookContentRepo` | Unknown book ID | Throws `ContentError.notFound` |
| BK-11 | P1 | `BookContentRepo` | ID both imported and sample | Imported `book.epub` used |
| BK-12 | P1 | `BookContentRepo.shareableFile` | Title "Good/Bad: A Tale" | File `Good-Bad- A Tale.epub`; same bytes |
| BK-13 | P1 | Golden (Full plan) | Parse all 5 bundled samples | No throw; chapter counts match stored snapshot (a change means bump `parserVersion`) |

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
| RD-07 | P1 | `ReaderCtrl.currentPage` | Toggle only `areSymbolsShown` | No re-layout (pager spy not called) |
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
| RD-20 | P1 | `ReaderStateCtrl` edited symbols | Edit in book 1 | Persisted for book 1 only |
| RD-21 | P1 | `ReadingSettings` | `textSizeIndex` -1 and 99 | 17 and 56 |
| RD-22 | P1 | `ReadingSettingsRepo` | No file / save then read | Defaults / saved |
| RD-23 | P1 | `ReferenceVM` | Jump to passage, then Return | Return position saved on jump; return shows original page and clears it |

## Underlines and references

| ID | Pri | Unit | Given / When | Expected |
| --- | --- | --- | --- | --- |
| AN-01 | P0 | `ChapterInputMapper.input` | 3-chapter book, map ch 1 | Only ch 1 paragraphs/sentences; global indexes kept; text equals substring |
| AN-02 | P0 | `ChapterInputMapper.firstSentence` | Page starts mid-sentence | That sentence's index |
| AN-03 | P0 | `UnderlineRepo` | Finish a chapter; new repo, same folder | Yields once and finishes without running engine; loads from disk |
| AN-04 | P0 | `UnderlineRepo` | Stored chapter has older `parserVersion` | Underlined again |
| AN-05 | P1 | `UnderlineRepo` | Start ch 2 while ch 1 runs; restart ch 1 | Ch 1 not saved half-done; no duplicate IDs |
| AN-06 | P0 | `RefCtrl.marks` | Underline on page + one in other chapter | One `.underline` mark, page-relative; none for other |
| AN-07 | P0 | `RefCtrl.marks` | `highlighting:` an underline whose reference is on page | `.highlight` for it only |
| AN-08 | P0 | `RefCtrl.marks` | `includingSymbols: false` | No `.symbol` marks |
| AN-09 | P1 | `RefCtrl.underline(withID:)` | Unknown ID | `ContentError.notFound` |
| AN-10 | P1 | `RefCtrl.symbolCard` | Index out of range | `ContentError.notFound` |
| AN-11 | P1 | `RefCtrl.entities(inChapter:)` | Mentions B, A, B | B, A |
| AN-12 | P1 | `SymbolPalette.style` | With / without edited style | Edited wins; else colour = symbol index mod 10 |
| AN-13 | P1 | `SymbolPalette.color(at:)` | Index 99 | Fallback colour |

## Character engine

No-spoiler cases (CH-14, CH-16) matter most: a symbol card must never show a passage the reader hasn't reached.

| ID | Pri | Unit | Given / When | Expected |
| --- | --- | --- | --- | --- |
| CH-01 | P0 | `NameKey.of` | "Mr. Darcy", "MR  DARCY", "mr darcy" | All "mr darcy" |
| CH-02 | P0 | `ChapterSlicer.slices` | 40, 40, 40 chars; max 100 | [40, 40], [40] |
| CH-03 | P0 | `ChapterSlicer.slices` | One 300-char sentence; empty input | Own slice; `[]` |
| CH-04 | P1 | `StoryStart.firstStoryChapter` | Title page, contents chapter, story | 2 |
| CH-05 | P1 | `StoryStart.firstStoryChapter` | No contents chapter | 0 |
| CH-06 | P0 | `MentionFinder.mentions` | "Mr. Darcy looked at Elizabeth." | Heads "mr darcy", "elizabeth"; "Mr." alone never a mention |
| CH-07 | P1 | `MentionFinder.mentions` | "Everyone saw the tall girl." | No mention for "Everyone"; description with head "girl" |
| CH-08 | P1 | `NameVocabularyBuilder.build` | "Will" capitalized twice, "will" 20× | Not a known name |
| CH-09 | P0 | `CastBuilder.extend` | Name seen once vs twice | Entity only at ≥ 2 |
| CH-10 | P0 | `CastBuilder.extend` | "Elizabeth, or Lizzy, laughed." | One entity with both names |
| CH-11 | P1 | `MentionLinker.link` | "Anne, the red-haired girl, ran." | Description links to Anne |
| CH-12 | P0 | `ResolvedAnalysis` merges | Merge 2 into 1 at sentence 10 | asOf 5 → 2, asOf 10 → 1; `finalKey(2)` = 1; chains followed |
| CH-13 | P0 | `ResolvedAnalysis` merges | 1→2 then 2→1; merge into self | Terminates; self-merge no-op |
| CH-14 | P0 | `EvidenceGuard.accepts` | Evidence after mention; card introduced after mention | Both rejected |
| CH-15 | P0 | `EvidenceGuard.wordLocation` | "Ann" in "Anne smiled" / "Ann smiled" | nil / 0 |
| CH-16 | P0 | `AppearancePicker.best` | Appearances at para 5 and 50, reader at 20 | Para 5 only (no spoilers) |
| CH-17 | P1 | `AppearancePicker.passages` | Sentence describing two named characters | Excluded |
| CH-18 | P0 | `SliceReadingApplier.apply` | Model reassigns an already-linked name | Ignored |
| CH-19 | P1 | `SliceReadingApplier.apply` | Missed name overlapping existing mention | Not added |
| CH-20 | P0 | `SymbolAssigner.assign` | 1 mention vs 3 mentions | Only the second gets a symbol |
| CH-21 | P0 | `SymbolAssigner.assign` | Ch 1 then ch 2 with a new character | Old symbols unchanged; new gets next; wraps after 24 |
| CH-22 | P1 | `AnalysisMapper.map` | Unnamed entity symbol from ch 3 | Ch 1–2 mentions hidden; IDs `character-<key>`; paragraph-relative ranges |
| CH-23 | P0 | `ChapterAnalysisStore` | Load with same / other engine / other parser version | Loaded / nil / nil; `clear` removes folder |
| CH-24 | P0 | `AnalysisRepo` + `LLMSvcUnavailable` | `startAnalysis` on `minimal.epub` | Runs to end; update per chapter; chapters stored |
| CH-25 | P1 | `AnalysisRepo` | Stop mid-book, start again | Stored chapters reused; same book twice doesn't restart |
| CH-26 | P1 | `AnalysisRepo.updates` | Book not running | Stream finishes at once |
| CH-27 | P1 | Golden (Full plan) | Rules-only *Little Women* ch 1 | Meg, Jo, Beth, Amy with distinct symbols (review diffs after iOS updates) |
