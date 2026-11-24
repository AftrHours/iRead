# Handoff: Pride and Prejudice is split at printed page numbers, not at chapters

Status: **not started.** Written 2026-11-12 for whoever picks it up (engineer or agent). Nothing in this note has been changed in the code yet.

## The problem

The bundled `pride-and-prejudice.epub` (Gutenberg #1342, the "no images" build of the 1894 Hugh Thomson edition) parses into **472 "chapters"**. The book has 61 chapters.

- 448 of the 472 chapters are titled like a printed page number: `{vii}`, `{41}`, `{62}`. These titles show up in the reader header, in the Contents sheet, and in the reference popover (`{41} • Page 19`, because `ChapterNumber` finds no number in `{41}`).
- **239 of the 471 chapter boundaries cut a sentence in two.** A paragraph is split in the middle, and the reader shows it as two paragraphs with paragraph spacing between them.
- **74 paragraphs are a single closing quote `”`** (and 5 are a single `—`): the quote mark sits right after a page marker in the HTML, so it ends up alone.
- The underline engine works one chapter at a time, so it sees roughly 270-word pieces with their sentences cut. That can lower underline quality for this book.

The previous edition of the file had the same problem (451 of 466), so this is not caused by the new file.

## Cause

The EPUB's `toc.ncx` has 516 entries. About 452 of them point at page markers (label `{n}`), and only about 64 are real chapter headings. Raw HTML of a marker:

```html
<span class="x-ebookmaker-pageno" title="{10}" id="pgepubid00032"><a id="page_10" title="{10}"></a></span>”</p>
```

In `Packages/EPUBKit/Sources/EPUBKit/EPUBReader.swift`:

1. `tocEntries(at:in:)` turns every NCX entry into a chapter start, markers included.
2. `ChapterReader` is given every entry's fragment as an "anchor". In `didStartElement`, an element whose `id` is an anchor calls `endParagraph()`. A page marker in the middle of a sentence therefore ends the paragraph there.

## What to do

**Make the reader ignore NCX entries whose label is a page marker** (a label that is entirely `{...}`, for example `^\{[^}]*\}$`). Skip them in two places:

1. When building `titles` in `chapters(from:)`: a marker entry gets no title, so its text continues the previous chapter.
2. When building the `anchorIDs` passed to `ChapterReader`: a marker's fragment is not an anchor, so it no longer ends a paragraph.

Careful with this existing rule: *"A file's first entry starts at its top"* (`order == 0 ? 0 : ...`). **Keep `order` computed over the full, unfiltered list of entries for that file**, so the behaviour for every other book stays identical. If you compute `order` after filtering, the first real chapter in a file would be forced to the top of the file, and the text above it would be moved into the wrong chapter. In Pride and Prejudice nearly every file starts in the middle of a chapter.

Expected result for this book: about 60-65 chapters (61 chapters plus front matter), titles like `Chapter I.` and `CHAPTER IV.`, and almost no chapter starting in lowercase.

## Must not change

- The chapter counts of the other four books: Little Women 52, Anne of Green Gables 42, Moby Dick 145, Sherlock Holmes 18. Their **fingerprints must not change** either (`BookFingerprint` hashes every chapter's text and the split points). Check by printing `fingerprint` for each sample before and after.
- `AppContainer`, `project.yml`, the two `.entitlements` files: see "Local state" below.

## Decisions to ask the owner before doing them

1. **Bump `parserVersion`?** (`EPUBParseSvc.swift`, `parserVersion: 1`). The comment above `sampleChapterCounts` in `EPUBParseSvcTests.swift` says to bump it when chapter counts change on purpose. But bumping makes `UnderlineSeedTests.seedsAreCurrent` (AN-27) report *every* bundled seed as "from another parser", so the seeds for Little Women and Anne of Green Gables would have to be regenerated too. Pride's fingerprint changes anyway, because its chapters change. Do not decide this alone.
2. **The hand-made seed for Pride and Prejudice.** `App/Resources/UnderlineSeed/3f631375a88e1ef44eae54e19017c0d5f51f9e9b991c5c61d93c2be522078204/chapter-442.json` belongs to the *old* EPUB. AN-27 already fails because of it ("No sample book has fingerprint 3f6313…"), and it will stay orphaned after this fix. Either delete it and make the underline again from the debug sheet, or move it to the new fingerprint only if chapter 442's text is provably identical (the stored ranges depend on exact text).

## Tests

- Add a small fixture EPUB with a page marker in the middle of a paragraph plus one real chapter entry (see `Tests/Fixtures/make-fixtures.sh` and `Fixture.url(_:)` in `Tests/Support/TestSupport.swift`). Assert that the paragraph is **not** split, that no chapter is titled `{n}`, and that the real chapter keeps its title. Follow the case-ID style in `docs/TEST_CASES.md`.
- Update `sampleChapterCounts["pride-and-prejudice"]` (currently `466`) in `Tests/Book/Svc/EPUBParseSvcTests.swift` (BK-13) to the new number, once you have checked that it is sensible. BK-13 is tagged `.golden`, so it runs only in the **Full** test plan.
- Run both plans: `Unit.xctestplan` and `Full.xctestplan`.

## How to check by eye

Open Pride and Prejudice in the iPad simulator: the Contents sheet should list chapter names instead of `{41}`, the header should show the chapter, and pages should no longer break in the middle of a sentence or show a lone `”` line.

## Out of scope (separate follow-ups)

- Chapter 0 holds the Project Gutenberg licence header, `*** START OF …`, the whole "Chapter: I., II., …" list as one paragraph, the colophon, and a title page split line by line.
- 22 paragraphs that are only `[Copyright 1894 by George Allen.]` (illustration captions that stayed as text), and two chapter labels that merged a caption into the title, such as `I hope Mr. Bingley will like it. CHAPTER II.`.

## Local state of the owner's checkout (branch `Processed-book`)

- `App/Resources/BookAssets/pride-and-prejudice.epub` (the new file, 595 KB) is **staged but not committed**. It was renamed to lowercase because the app looks the file up by the exact name `pride-and-prejudice`, and a mismatch makes the book unopenable. Work in this checkout, or ask the owner to commit it first.
- Four files are changed **only to run the app on a device without the iCloud entitlement** and must not be touched or committed: `project.yml`, `App/AppContainer.swift`, `App/iRead.entitlements`, `ShareExtension/iReadShare.entitlements`. `App/Analysis/Repo/UnderlineRepo.swift` also has a change that is not part of this task.
- Simulator builds work with those changes in place.

## Working rules for this repo

- Do not commit or push unless the owner says so. Never add `Co-Authored-By` or any mention of Claude to commits or pull requests.
- `project.pbxproj` is generated and gitignored: run `xcodegen generate` after adding or moving files.
- Build and test with your own derived-data path, so Xcode's lock on the default one does not interfere:

```bash
xcodebuild test -project iRead.xcodeproj -scheme iRead -testPlan Unit \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' \
  -derivedDataPath /tmp/iread-dd -skipPackagePluginValidation -skipMacroValidation
```

Use `-testPlan Full` for the golden tests.
