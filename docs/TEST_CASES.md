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
| BK-17 | P0 | `EPUBParseSvc.parse` | `labeled.epub`: cover and copyright files labeled front matter, chapter files body matter | `firstReadableChapterIndex` is the first body chapter (2) |
| BK-18 | P0 | `EPUBParseSvc.parse` | `preamble.epub`: a file the table of contents skips, then numbered chapters | Preamble is chapter 0, marked front; `firstReadableChapterIndex` 1 |
| BK-19 | P1 | `EPUBParseSvc.parse` | `minimal.epub` | `firstReadableChapterIndex` 0; `parserVersion` still 1, so stored underlines stay valid |
| BK-16 | P0 | `BookFingerprint` | Same chapters twice; one word changed; same text in other chapter breaks | Same fingerprint; different; different |
| FC-01 | P0 | `FirstChapter.index` | A chapter's file is labeled body matter (even after a "Chapter 1" title) | That chapter |
| FC-02 | P0 | `FirstChapter.index` | Titles like "Chapter 1", "Prologue", "Part One: …", "I. …" after front matter | The first of them |
| FC-03 | P0 | `FirstChapter.index` | Long text before the table of contents, marked front matter | Skipped |
| FC-04 | P1 | `FirstChapter.index` | No number or label; front-matter titles, and chapters under 300 words | First chapter that is neither; "Discovery" is not "cover" |
| FC-05 | P1 | `FirstChapter.index` | Nothing qualifies, or no chapters | 0 |
| FC-06 | P1 | `FirstChapter.index` | A chapter marked back matter | Never chosen |

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
| RD-20 | P0 | `ReaderCtrl.openBook` | No saved progress; book has a copyright page before chapter 1 | Opens at the first page of chapter 1 |
| RD-21 | P0 | `ReaderCtrl.restorePosition` | Saved at paragraph 0 (a reset book) with front matter | false; opens at the story start |
| RD-22 | P1 | `ReaderCtrl.restorePosition` | Position saved inside the front matter | true; kept |
| RD-23 | P1 | `ReaderCtrl.restorePosition` | Invalid position and `chapterIndex` with front matter | false; opens at the story start |
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
| RD-23 | P1 | `ReferenceVM` | Jump to passage, then Return | Return position saved on jump (`returnPrompt` is `.canReturn`); the card's underline is no longer selected; `passageDismissed` clears the highlight and keeps the return; return shows original page, clears it and shows `.returned(message:)` |
| RD-24 | P0 | `ReferenceVM.close` | Chapter underlining running; close the reader | Underline task cancelled and not restarted by a page update or `appForegrounded`; `ReferenceVM` released |
| RD-25 | P0 | `ReaderCtrl.search` | Search cancelled before it runs | No results; no chapters laid out; a later search still finds matches |
| RD-26 | P0 | `SearchVM` | Results shown; query changes to " A " | Results cleared; no search |
| RD-27 | P0 | `SearchVM` | Type "A", "An", "Ann", "Anna" quickly | One search, for "Anna", after the typing pause |
| RD-28 | P0 | `SearchVM` | Slow search for "Anna", then "Darcy" from recent searches | "Darcy" results stay after the "Anna" search returns |
| RD-29 | P0 | `RatingVM` | Thumbs up on a card; answer "Don't Share"; thumbs down; thumbs down again | Filled and asked once; switches without asking; rating taken back |
| RD-30 | P1 | `RatingVM.cardShown` | Thumbs up, then show the same card again at once | Thumbs up shown, read back after the save |
| RD-31 | P1 | `ReaderSettingsVM` spacing | Line 156.9, character 42, word 12.6; then line 10 | 155, 10, 15; label "1.55" in the reader's locale; line clamped to 80 |
| RD-32 | P0 | `ReaderSettingsVM.resetTapped` | Change size, theme, spacing, page turn and mode; Reset to Default | Size, theme and spacing back to defaults; page turn and mode kept |
| RD-33 | P1 | `ReadingMode.isDark` | Each mode, screen brightness 0.1 and 0.8 | Light false, Dark true, Match Device nil, Match Surroundings dark below 0.3 |
| RD-34 | P0 | `ReadingSettings` decoding | Settings file from an older build, without the new keys | Saved values kept; spacing 0, mode Match Device |
| RD-35 | P0 | `PageTextStyle.attributedText` | Character 5%, word 50% on "ab cd" | Letters kerned 5% of the text size; the space kerned more; no spacing gives kern 0 |
| RD-36 | P1 | `PageContent.neighbor` | Pages 4–6 loaded, page 5 shown | Page 6 after, page 4 before; nil after 6 and before 4 |
| RD-37 | P0 | `PageTurnRules.completes` | Release a Slide at 31% and 29%; flick forward at 401 and 399; flick back at -401 and -399 after 90% | Carries on at 31% and at 401; goes back at 29%, 399 and -401; carries on at -399 |
| RD-38 | P1 | `PageContent.highlights` | A page with a jumped-to passage and two underlines; one underline tapped, none, or one on another page | The passage, plus the tapped underline; only the passage when none or another page's; none on a page without marks |
| RD-39 | P2 | `PageContent.chrome` | Chrome built for page 5 only | Page 5's label; an empty chrome for page 6 |
| RD-40 | P0 | `PageLayout` | iPhone 17 Pro Max, then the same screen again and a rotated one | Header 44 high at the top inset, footer 44 high at the bottom inset, text between them with 32 and 16 gaps and a 9% margin; the viewport changes only when the text's room does |
| RD-41 | P1 | `PageTurnRules.fadeTurnsForward` | Swipes of -36, 36, -35 points; short flicks at ±401 and ±399 | Left is forward; 36 and 401 turn; 35 and 399 don't |
| RD-42 | P1 | `PageTurnRules.dragProgress` / `springVelocity` | Drags of -100, 100 and -1000 over 400; no distance; -800 over 200 and over 1 | 0.25, 0 and 1, clamped; 0 with no distance; spring velocity 4, and 0 when almost there |
| RD-43 | P0 | `PageTurnRules.tapZone` | Taps across an iPhone page (text 40–400 of 440) and an iPad page (text 78–742 of 820) | Edges turn the page, at least 44 wide; the middle toggles the bars |
| RD-44 | P1 | `ReadingTheme.isDarkPage` | Each combination of theme and dark mode | Dark in dark mode; Quiet is dark in any |
| RD-45 | P0 | `ReaderVM.screenChanged` | Measure the screen before the book opens | The layout is the screen's; no page content yet |
| RD-46 | P0 | `ReaderVM` settings panel | Open Theme & Settings on a narrow, then a full-width screen; dismiss | Sheet on a narrow screen, panel on a full-width one (no sheet); setting the sheet to nil closes it |
| RD-47 | P1 | `ReaderVM.isDarkPage` | Match Device; the device goes dark | Light, then dark |
| RD-48 | P1 | `ReaderVM.isCardForPad` | A narrow, then a full-width screen | iPhone card, then iPad card |

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
| AN-07 | P0 | `RefCtrl.marks` | `highlighting:` an underline's reference passage, on its page | `.highlight` for it only |
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
| AN-26 | P0 | `UnderlineRepo` | Chapter in the app's bundled seeds with the same / older engine version | Used without the engine or iCloud, nothing saved on disk / underlined again, saved and sent to iCloud |
| AN-27 | P0 | `App/Resources/UnderlineSeed` | Every bundled seed file | Folder matches a sample book's fingerprint; chapter exists; current parser and engine version |
| AN-28 | P0 | `RefCtrl.marks` | `highlighting:` the passage (in ch 1) of an underline in ch 2, on a ch 1 page | `.highlight` on the passage, no underline mark |
| CH-01 | P0 | `CharacterRules.characters` | "Jo", "Josephine March", "Laurie", "Laurence", "Beth", "Beth March" | "Laurie/Laurence", "Jo/Josephine March", "Beth March", latest mentioned first |
| CH-02 | P1 | `CharacterRules.characters` | Names under 3 mentions, "Christmas", "CHAPTER", "I’m", "Father", "Mr. Laurence" | Noise left out; "Mr. Laurence" kept apart from Laurie |
| CH-03 | P0 | `CharacterRules.characters` | Laurie: a speech tag, a description, a line about Marmee; Marmee only mentioned | Laurie's description; Marmee has no passage |
| DS-01 | P0 | `DescriptionRules` | Jo's speech tag, then "Fifteen-year-old Jo was very tall…" and "She had a decided mouth…" | The introduction, carried on into the "She" sentence; Beth's "girl of thirteen" for Beth |
| DS-02 | P1 | `DescriptionRules` | Amy's introduction then "A regular snow maiden, with blue eyes…" | Both sentences |
| DS-03 | P1 | `DescriptionRules` | Pride and Prejudice: Bingley, Lydia | Each one's description |
| DS-04 | P0 | `DescriptionRules` | A plain mention; a name only in dialogue; "Elizabeth’s intimate friend" | No passage |
| CH-05 | P0 | `CharacterRules.characters` | "Laurie", "Mr. Laurence", bare "Laurence"; "Mrs. March", "Aunt March", bare "March"; "Jo", "Miss Jo" | Mr. Laurence apart from Laurie and owns bare "Laurence"; bare "March" left out; "Miss Jo" is Jo |
| CH-06 | P1 | `CharacterRules.characters` | "My first name is Theodore… so I made them say Laurie instead" | Theodore and Laurie are one character |
| CH-07 | P1 | `CharacterCtrl` (golden) | Little Women, chapters 1–4 | Each sister's introduction; Laurie gets "Curly black hair…"; Mr. Laurence gets none |
| CH-08 | P1 | `CharacterCtrl` (golden) | Pride and Prejudice, to chapter 16 | Bingley, Darcy, Lydia and Mr. Bennet get their descriptions |
| CH-09 | P0 | `CharacterRules.characters` | "Good", "Him" (mostly lowercase), "Washington" ("in/from Washington", "the Washington dispatches"), Sallie ("at Sallie’s", "said Sallie") | Only Sallie |
| CH-10 | P1 | `CharacterRules.characters` | "Brookes", "Germans", "Christmas Eve", "Gott" only inside quotes | Only Brooke |
| DS-05 | P0 | `DescriptionRules.unnamedDescriptions` | A description naming no one, after "Laurie’s…" and "the ‘Laurence boy’" | Laurie's; not Jo's (gender), not Mr. Laurence's ("the Laurence boy" is a family) |
| DS-06 | P1 | `DescriptionRules.gender` | "Laurie laughed, and he bowed"; Jo with one "she" | Male; not clear |
| DS-07 | P0 | `DescriptionRules` | "Mr. Hurst… but his friend Mr. Darcy… tall person"; a Darcy sentence mostly about "her" | Darcy's part only; the "her" sentence isn't his |
| DS-08 | P1 | `DescriptionRules.gender` | "Miss Lydia" with stray "he"s; "Mr. Darcy" | Female; male |
| CH-04 | P1 | `CharacterRules.matches` | "laur", "LAURENCE", "Lauire", "", "Haymitch", "Lx" | Found, found, found (one typo), all, not found, not found |
