# Chapter Reader Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the two-phase whole-book character engine with an engine that reads the story chapter by chapter, carries a character memory forward, lets Foundation Models read each chapter in slices, and stores each chapter's result on the device.

**Architecture:** A one-time NaturalLanguage pre-pass tags the whole story and builds a name vocabulary. Then each story chapter runs, in order: rules (find mentions, extend the cast, link) → Foundation Models reads the chapter in budget-sized slices with character cards → every answer passes the evidence guard → memory and stable symbols are updated → the chapter result is saved. `AnalysisRepo` drives the chapter loop, resumes from stored chapters, and publishes a new `BookAnalysis` after each chapter; the reader reloads marks on each update.

**Tech Stack:** Swift 6, SwiftUI, iOS/iPadOS 26, NaturalLanguage (`NLTagger`), FoundationModels (`LanguageModelSession`, `@Generable`), ZIPFoundation (EPUB), xcodegen.

**Spec:** `docs/superpowers/specs/2026-10-26-chapter-reader-engine-design.md`

## Global Constraints

- Repo: `/Users/abr/project/iRead/EReader/iRead`, branch `Feature-tune`. Commit `a49f47f` holds a local-only debug view: never push it.
- No test target. Each task is proven by a **check script** (a Swift file compiled with `swiftc` on the Mac against the app sources, printing `PASS`/`FAIL`) plus an iOS Simulator build. Check scripts live outside the repo in `/Users/abr/project/iRead/engine-checks/` and are never committed.
- Delivery: the owner pastes the code. The executor writes and verifies each task in a scratch copy of the repo first, then hands over the changes as ordered snippets (file, exact place, code). The owner commits; the executor never commits or pushes.
- No code comments. Layers: `Models/` data only; `Rules/` pure logic as `enum` with static funcs; `Svc/` services; `Repo/` storage and caches; `Ctrl/`, `VM/`. Engine files under `App/Analysis/AI/{Models,Rules,Svc}`. Knobs as `enum <Step>Knobs` at the top of the step's file.
- Run `xcodegen generate` after adding, removing or moving a file; check its output has no error and that `project.yml` is unchanged.
- Characters only; pronouns are out of scope (PRD 2.1 non-goal). All processing on device.
- Spoiler rule: nothing the engine uses or shows for a sentence may come from text after that sentence. Merges are recorded with `mergedAtSentence` and read through `entityKey(of:asOf:)`.
- A chapter's marks appear only after the model has read that chapter (owner's decision). Without Foundation Models, a chapter is analysed by rules only and its marks appear after that.
- Story chapters come from `StoryStart.firstStoryChapter(in:)` (engine version, already on the branch) until the parser's `BookContent.storyChapter` lands; then use `content.storyChapter`.

## Review Focus

1. A slice the model refuses or that overflows the context: the chapter still completes with the rules result for that slice, and `failedSlices` counts it. (Test in Task 8.)
2. Raising the engine version: stored chapters with the old version are ignored and recomputed. (Test in Task 9.)
3. App closed in the middle of the book: reopening loads the stored chapters and resumes at the first missing one, without recomputing earlier chapters. (Test in Task 10.)
4. Two characters that both already have symbols are merged: from the merge sentence on, both show the earlier character's symbol; earlier pages keep their own. (Test in Task 6.)
5. Character cards sent to the model contain nothing positioned after the slice's first sentence. (Test in Task 7.)

## Check scripts

Every task's check is one file `engine-checks/checkN.swift` plus the shared `engine-checks/Support.swift`:

```swift
import Foundation

nonisolated(unsafe) var failures = 0

func check(_ condition: Bool, _ label: String) {
    print(condition ? "PASS" : "FAIL", label)
    if !condition { failures += 1 }
}

func littleWomen() async throws -> BookContent {
    try await EPUBParseSvc().parse(URL(fileURLWithPath: "/Users/abr/project/iRead/EReader/iRead/App/Resources/little-women.epub"))
}
```

Each `checkN.swift` defines `@main struct CheckN { static func main() async throws { …; exit(failures == 0 ? 0 : 1) } }`.

Build and run (from `engine-checks/`; `zipmod/` holds the macOS ZIPFoundation module, see Task 0):

```bash
swiftc -swift-version 6 -parse-as-library -O -I zipmod -L zipmod -lZIPFoundation -o checkN Support.swift checkN.swift $(find ../EReader/iRead/App/Book/Models ../EReader/iRead/App/Analysis/Models ../EReader/iRead/App/Analysis/AI -name "*.swift") ../EReader/iRead/App/Book/Svc/EPUBParseSvc.swift ../EReader/iRead/App/Reader/Models/*.swift
```
```bash
DYLD_LIBRARY_PATH=zipmod ./checkN
```

Tasks 9–10 add `../EReader/iRead/App/Analysis/Repo/*.swift ../EReader/iRead/App/Book/Repo/BookContentRepo.swift` to the file list. During the executor's verification, paths point at the scratch copy instead of the repo.

iOS build check (all tasks):

```bash
xcodebuild -project iRead.xcodeproj -scheme iRead -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```
Expected: `** BUILD SUCCEEDED **`.

---

### Task 0: Check setup

**Files:**
- Create: `/Users/abr/project/iRead/engine-checks/Support.swift`, `/Users/abr/project/iRead/engine-checks/zipmod/` (outside the repo)

- [ ] **Step 1: Create the folder and `Support.swift`** with the code above.
- [ ] **Step 2: Provide the macOS ZIPFoundation module.** Copy `libZIPFoundation.dylib`, `ZIPFoundation.swiftmodule`, `ZIPFoundation.swiftdoc`, `ZIPFoundation.abi.json` and `ZIPFoundation.swiftsourceinfo` from `/private/tmp/claude-501/-Users-abr-project-iRead/47f8cb5e-e2c1-4778-b78a-db6472d9e034/scratchpad/zipmod/` into `zipmod/`. If that folder is gone, build ZIPFoundation for macOS from its SwiftPM checkout as a dynamic library with its Swift module (`swift build -c release` in the checkout, then copy the produced module and dylib).
- [ ] **Step 3: Baseline check** `check0.swift`: parse Little Women and assert `content.sentences.count == 10163` and `content.chapters.count == 52`. Run it; Expected: two `PASS`.

---

### Task 1: Rule fixes A, B, C

The code exists as verified chat snippets (scratch copy `/private/tmp/claude-501/-Users-abr-project-iRead/13fd9ce3-5165-444b-95d6-64fca6f3ee32/scratchpad/cur/App/Analysis/AI/Rules/`). Spec section "Batasan" states the exact rules.

**Files:**
- Modify: `App/Analysis/AI/Rules/MentionFinder.swift` (knobs, `mentions(in:tags:)`, new `knownNames(in:)`, `names(in:tokens:knownNames:)`, `isNameWord(_:knownNames:)`)
- Modify: `App/Analysis/AI/Rules/MentionLinker.swift` (`appositionConnectors`)

- [ ] **Step 1: Write `check1.swift`** using the current pipeline (`AnalysisScheduleSvc().rulesPass(for:)`):
  - `check(mentions in s136 contain a .name mention with text "Margaret", "B: Margaret at s136")`
  - `check(no mention in s137 has text "brown", "A: brown is not a name")`
  - `check(linked mentions whose entity label is "Meg" >= 600, "B: Meg recovered")`
  - `check(no entity label in ["How", "Tell", "Dear"], "B: no sentence-start junk")`
  - `check(undecided count < 405, "C: more descriptions linked")`
- [ ] **Step 2: Run** — Expected: FAIL on the B and A checks.
- [ ] **Step 3: Apply the snippets.**
- [ ] **Step 4: Run** — Expected: all PASS. iOS build succeeds.

---

### Task 2: Spoiler-safe merge

**Files:**
- Modify: `App/Analysis/AI/Rules/ResolvedAnalysis+Merges.swift` — `merge(_:into:at:decidedBy:)`

- [ ] **Step 1: Write `check2.swift`.** Build a `ResolvedAnalysis` by hand with entities 1 ("a young lady", intro 115), 2 ("a little girl", intro 115), 3 ("Jenny Snow", intro 1504, named). Call `merge(1, into: 3, at: 1504, decidedBy: .rule)`, then `merge(2, into: 1, at: 115, decidedBy: .model)`. With a mention of entity 2 at sentence 115:
  - `check(entityKey(of: mention, asOf: 115) == 1, "merge target resolved as of 115")`
  - `check(entityKey(of: mention, asOf: 1504) == 3, "later merge still applies from 1504")`
- [ ] **Step 2: Run** — Expected: FAIL on the first check (today it resolves to 3).
- [ ] **Step 3: Change `merge`** so both `from` and `into` are resolved with `follow(_:upTo: sentence)` instead of `finalKey(of:)`.
- [ ] **Step 4: Run** — Expected: PASS. iOS build succeeds.

---

### Task 3: Deterministic labels and symbol order

**Files:**
- Modify: `App/Analysis/AI/Rules/CastBuilder.swift` — `mostFrequentText(of:)`
- Modify: `App/Analysis/AI/Rules/AnalysisMapper.swift` — sort of kept entities

- [ ] **Step 1: Write `check3.swift`:** run `rulesPass` + `analysis(from:)` once and print one fingerprint line `entities:<labels joined>|symbols:<id=symbol joined>`. Swift picks a new hash seed per process, so the order bug only shows across processes: the next step runs the binary three times and compares the lines.
- [ ] **Step 2: Run three times** — Expected: lines differ (today "Apollyon"/"APOLLYON" and Father/Mother order vary).
- [ ] **Step 3: Implement.** `mostFrequentText`: on equal counts pick the text of the earliest mention. Mapper sort key: `(introSentence, location of the entity's first mention in that sentence, key)`.
- [ ] **Step 4: Run three times** — Expected: identical lines. iOS build succeeds.

---

### Task 4: Storable engine data and new models

**Files:**
- Modify: `App/Analysis/AI/Models/ResolvedMention.swift`, `ResolvedEntity.swift` — add `Codable` to `ResolvedMention`, `MentionForm`, `ResolvedEntity`, `EntityName`, `MergeEdge`, `DecidedBy`
- Create in `App/Analysis/AI/Models/`: `NameVocabulary.swift`, `CharacterTrait.swift`, `SymbolAssignment.swift`, `CastMemory.swift`, `ChapterAnalysis.swift`

**Interfaces:**
- Produces:
  - `struct NameVocabulary: Sendable, Codable { let names: Set<String>; let nameCounts: [String: Int] }` — `names`: lowercased words treated as names (rule B); `nameCounts`: `NameKey.of` → name-mention count in the whole story.
  - `struct CharacterTrait: Sendable, Codable { let text: String; let sentence: Int }`
  - `struct SymbolAssignment: Sendable, Codable { let symbolName: String; let sinceChapter: Int }`
  - `struct CastMemory: Sendable, Codable { var entities: [ResolvedEntity]; var traits: [Int: [CharacterTrait]]; var symbols: [Int: SymbolAssignment] }` with `static let empty`
  - `struct ChapterAnalysis: Sendable, Codable { let chapter: Int; let engineVersion: Int; let mentions: [ResolvedMention]; let memory: CastMemory; let modelCalls: Int; let failedSlices: Int }`

- [ ] **Step 1: Write `check4.swift`:** take the current pipeline's `ResolvedAnalysis`, wrap its entities in a `CastMemory` and its mentions in a `ChapterAnalysis(chapter: 3, engineVersion: 1, …)`, encode with `JSONEncoder`, decode with `JSONDecoder`:
  - `check(decoded.mentions.count == original.mentions.count, "mentions round-trip")`
  - `check(decoded.memory.entities.map(\.key) == original.memory.entities.map(\.key), "entities round-trip")`
  - `check(decoded.mentions.map(\.entity) == original.mentions.map(\.entity), "links round-trip")`
- [ ] **Step 2: Run** — Expected: compile error (types missing).
- [ ] **Step 3: Implement** the conformances and the five types.
- [ ] **Step 4: Run** — Expected: PASS. `xcodegen generate`; iOS build succeeds.

---

### Task 5: Name vocabulary pre-pass

**Files:**
- Create: `App/Analysis/AI/Rules/NameVocabularyBuilder.swift`
- Modify: `App/Analysis/AI/Rules/MentionFinder.swift` — `mentions(in:tags:)` becomes `mentions(in:tags:names:)`; `knownNames(in:)` moves out
- Modify: `App/Analysis/AI/Svc/AnalysisScheduleSvc.swift` — build the vocabulary, then pass `names` (keeps the old pipeline working until Task 10)

**Interfaces:**
- Consumes: `NameVocabulary` (Task 4), rule B knobs (Task 1)
- Produces:
  - `enum NameVocabularyBuilder { static func build(sentences: [NumberedSentence], tags: SentenceTags) -> NameVocabulary }` — `names` = rule B's word set; `nameCounts` from running `MentionFinder.mentions(in:tags:names:)` over the whole story and counting `.name` mentions per `head`.
  - `MentionFinder.mentions(in: [NumberedSentence], tags: SentenceTags, names: Set<String>) -> [ResolvedMention]`; `tags.tokens` is paired with `sentences` by position (unchanged).

- [ ] **Step 1: Write `check5.swift`:**
  - `check(vocabulary.names.contains("margaret"), "Margaret is a name word")`
  - `check(vocabulary.nameCounts["jo", default: 0] >= 1300, "Jo counted across the book")`
  - Run `MentionFinder` on chapter 3's sentences only (with their tags and `vocabulary.names`): `check(found .name "Margaret" in s136, "Margaret found when only chapter 3 is processed")`
- [ ] **Step 2: Run** — Expected: compile error.
- [ ] **Step 3: Implement.** Move the body of `knownNames(in:)` into the builder unchanged.
- [ ] **Step 4: Run** — Expected: PASS. Task 1's check still passes. `xcodegen generate`; iOS build succeeds.

---

### Task 6: Rules per chapter with memory, stable symbols, mapper

**Files:**
- Modify: `App/Analysis/AI/Rules/CastBuilder.swift`
- Modify: `App/Analysis/AI/Rules/MentionLinker.swift`
- Create: `App/Analysis/AI/Rules/SymbolAssigner.swift`
- Modify: `App/Analysis/AI/Rules/AnalysisMapper.swift`
- Create: `App/Analysis/AI/Models/LinkedChapter.swift`

**Interfaces:**
- Consumes: Tasks 4–5
- Produces:
  - `struct LinkedChapter: Sendable { var mentions: [ResolvedMention]; var memory: CastMemory }`
  - `CastBuilder.extend(_ memory: CastMemory, with mentions: [ResolvedMention], sentences: [NumberedSentence], vocabulary: NameVocabulary) -> CastMemory` — a name whose `nameCounts` ≥ `minNameCount` becomes a character at its first mention; entity keys continue from the memory's largest key; alias patterns as today.
  - `MentionLinker.link(_ mentions: [ResolvedMention], memory: CastMemory, sentences: [NumberedSentence]) -> LinkedChapter` — same rules as today, starting from the memory's entities; earlier chapters' descriptions are not available for `bestMatch` (only the memory's entities and this chapter's mentions). `dropSmallDescribedEntities` is no longer called.
  - `enum SymbolAssigner { static func assign(_ memory: inout CastMemory, mentionsSoFar: [ResolvedMention], vocabulary: NameVocabulary, chapter: Int) }` — an entity without a symbol gets the next unused symbol from `AnalysisMapperKnobs.symbols` when it qualifies: named and its best `nameCounts` ≥ `AnalysisMapperKnobs.minimumMentions`, or described-only with ≥ `minimumMentions` linked mentions so far. Order of new assignments: `(introSentence, key)`. `sinceChapter` = the entity's intro chapter for named entities, `chapter` for described ones. Never reassigns.
  - `AnalysisMapper.map(memory: CastMemory, mentions: [ResolvedMention], content: BookContent) -> BookAnalysis` — entities = those with a symbol assignment; a mention is shown when its entity (as of its sentence) has a symbol and the mention's chapter ≥ `sinceChapter`; passages as today.
- Merge between two symbolized entities: always merge the later-introduced into the earlier-introduced, so the earlier symbol wins from the merge sentence.

- [ ] **Step 1: Write `check6.swift`:** build the vocabulary (Task 5), then loop story chapters in order: find mentions → `extend` → `link` → `assign`, accumulating mentions; then `map`.
  - `check(chapter 3 BookAnalysis has an entity named "Jo" with a symbol, "Jo has a symbol in chapter 1")`
  - `check(s136 "Margaret" mention is linked to an entity, "Margaret linked in chapter 1")`
  - `check(sequential total linked mentions within 5% of the whole-book rules pass, "sequential ≈ whole-book")`
  - Run the loop to chapter 10, record every entity's symbol, run to the end: `check(no recorded symbol changed, "symbols never reassigned")`
  - Hand-build a memory with symbolized entities A (intro 10, "circle.fill") and B (intro 50, "square.fill"); merge B into A at sentence 100; map mentions of B at 60 and 120: `check(mention at 60 shows "square.fill" && mention at 120 shows "circle.fill", "merged symbols: earlier wins from merge sentence")` (Review Focus 4)
- [ ] **Step 2: Run** — Expected: compile error.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — Expected: PASS. The old pipeline (`AnalysisScheduleSvc`) is adapted to the new signatures so the app still builds; iOS build succeeds.

---

### Task 7: Slices, character cards, evidence and applying a reading

**Files:**
- Create in `App/Analysis/AI/Models/`: `CastCard.swift`, `SliceRequest.swift`, `SliceReading.swift`
- Create in `App/Analysis/AI/Rules/`: `ChapterSlicer.swift`, `CastCards.swift`, `SliceReadingApplier.swift`
- Modify: `App/Analysis/AI/Rules/EvidenceGuard.swift`

**Interfaces:**
- Produces:
  - `struct CastCard: Sendable { let number: Int; let entity: Int; let name: String; let aliases: [String]; let traits: [String]; let intro: String }`
  - `struct SliceMention: Sendable { let number: Int; let text: String; let sentence: Int }`
  - `struct SliceRequest: Sendable { let sentences: [ModelSentence]; let mentions: [SliceMention]; let cards: [CastCard] }`
  - `struct SliceReading: Sendable { var assignments: [MentionAssignment]; var missedNames: [NamedSpan]; var sameNames: [NamePair]; var traits: [TraitNote] }` with `MentionAssignment { mention: Int; card: Int?; evidence: Int }` (`card == nil` = not a character), `NamedSpan { text: String; sentence: Int }`, `NamePair { first: String; second: String; evidence: Int }`, `TraitNote { card: Int; text: String; sentence: Int }`
  - `enum ChapterSlicer { static func slices(_ sentences: [NumberedSentence], maxCharacters: Int) -> [[NumberedSentence]] }` — consecutive, never splits a sentence, one sentence longer than the limit is a slice of its own
  - `enum CastCards { static func cards(for slice: [NumberedSentence], mentions: [ResolvedMention], memory: CastMemory, sentenceText: [Int: String], maxCards: Int) -> [CastCard] }` — entities linked in the slice first, then most recently mentioned; aliases ≤ 3; traits = 3 most recent with `sentence < slice.first.index`; intro sentence text cut to 40 words; only data positioned before the slice's first sentence
  - `EvidenceGuard.accepts(_: MentionAssignment, for: SliceRequest) -> Bool`, `accepts(_: NamedSpan, for:) -> Bool`, `accepts(_: NamePair, for: SliceRequest, memory: CastMemory) -> Bool`, `accepts(_: TraitNote, for:) -> Bool` — evidence sentence is in the request and not after the decided mention; quoted text occurs verbatim as whole words in its sentence; a missed name is capitalized; a name pair needs one name in the evidence sentence and the other in the slice or among a card's names
  - `enum SliceReadingApplier { static func apply(_ reading: SliceReading, request: SliceRequest, to chapter: inout LinkedChapter, vocabulary: NameVocabulary) }` — only accepted items; assignment merges the mention's described entity into the card's entity at the evidence sentence (Task 2 merge); missed name adds a `.name` mention and links it; name pair merges later-introduced into earlier-introduced at the evidence sentence; trait appends to `memory.traits`; assigned mentions get `decidedBy = .model`, `isUndecided = false`
- Knobs: `ChapterSlicerKnobs.charactersPerToken = 3`, `CastCardsKnobs.maxCards = 8`, `CastCardsKnobs.introWords = 40`, `CastCardsKnobs.traitsPerCard = 3`, `CastCardsKnobs.aliasesPerCard = 3`

- [ ] **Step 1: Write `check7.swift`** (no model; readings are written by hand):
  - Slicer: `check(slices joined == input and every slice's character count <= max or count == 1, "slices cover chapter")`
  - Cards for the slice starting at s136, from a memory holding a trait at s200: `check(no card text contains the s200 trait, "cards hold nothing after the slice start")` (Review Focus 5)
  - Guard: a `NamedSpan(text: "Margret", sentence: 136)` → `check(!accepts, "misspelled name rejected")`; `NamedSpan(text: "Margaret", sentence: 136)` → accepted; `MentionAssignment` with evidence after the mention → rejected
  - Applier: a reading assigning the s144 "snow maiden" mention to Amy's card with evidence s143 → `check(entityKey(of: s144 mention, asOf: 144) == Amy's key, "assignment applied")`
- [ ] **Step 2: Run** — Expected: compile error.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — Expected: PASS. `xcodegen generate`; iOS build succeeds.

---

### Task 8: Model reads a slice; chapter analysis service

**Files:**
- Create: `App/Analysis/AI/Models/SliceReadAnswer.swift` (`@Generable` mirror of `SliceReading`, numbers instead of entity keys)
- Modify: `App/Analysis/AI/Svc/LLMSvc.swift`, `App/Analysis/AI/Svc/LLMSvcFoundation.swift`
- Create: `App/Analysis/AI/Svc/ChapterAnalysisSvc.swift`, `App/Analysis/AI/Svc/BookPrepassSvc.swift`, `App/Analysis/AI/Models/PreparedBook.swift`

**Interfaces:**
- Consumes: Tasks 4–7
- Produces:
  - `enum LLMFailure: Error { case exceededContext, refused, unavailable, other }`
  - `protocol LLMSvc: Sendable { var isAvailable: Bool { get }; var contextSize: Int { get }; var maxCallsPerChapter: Int { get }; func prewarm(); func readSlice(_ request: SliceRequest) async throws(LLMFailure) -> SliceReading }`; `LLMSvcUnavailable` throws `.unavailable` and its `prewarm()` does nothing
  - `LLMSvcFoundation.readSlice`: new `LanguageModelSession` per call; `contextSize` from `SystemLanguageModel.default.contextSize`; maps `exceededContextWindowSize` → `.exceededContext`, guardrail errors → `.refused`. Instructions (in `LLMKnobs`): read the numbered sentences; for each listed mention say which card it refers to or that it is not a character; list character names the list missed, copied exactly; list name pairs that are the same person (general knowledge of name forms such as nicknames is allowed) with the sentence that shows it; list short descriptions of characters copied exactly; give a sentence number for every answer; use only the cards and the sentences given for who is who.
  - `struct PreparedBook: Sendable { let content: BookContent; let sentences: [NumberedSentence]; let tags: SentenceTags; let vocabulary: NameVocabulary; let chapters: Range<Int> }`
  - `struct BookPrepassSvc: Sendable { func prepare(_ content: BookContent) -> PreparedBook }` — tags all story sentences once (`WordTagSvc`), builds the vocabulary
  - `struct ChapterAnalysisSvc: Sendable { func analyze(chapter: Int, book: PreparedBook, memory: CastMemory, mentionsSoFar: [ResolvedMention], llm: LLMSvc) async -> ChapterAnalysis }` — rules (Task 6); when `llm.isAvailable` is false, stop there with `failedSlices == 0` (rules-only is not a failure); otherwise per slice: build request (`maxCharacters` = (`contextSize` × `budgetShare`) × `charactersPerToken`), `readSlice`, apply (Task 7); on `.exceededContext` split the slice in two and retry once; any other failure: keep the rules result and count `failedSlices`; stop calling after `maxCallsPerChapter`; then `SymbolAssigner.assign`. Knobs: `ChapterAnalysisKnobs.engineVersion = 1`, `budgetShare = 0.6`
- Delete: `TieBreakSvc.swift`, `LinkRequest.swift`, `LinkChoice.swift`, `ModelCandidate.swift`, `NameGroupRequest.swift`, `NameGroupChoice.swift`, `NameGroupItem.swift`, `GroupNamesAnswer.swift`, `ChooseReferenceAnswer.swift` (and their `EvidenceGuard`/`LLMKnobs` parts) once nothing uses them. `AnalysisScheduleSvc` keeps only what Task 10 still needs or is replaced there.

- [ ] **Step 1: Write `check8.swift`:**
  - Stub `LLMSvc` that throws `.refused` for the second slice and returns an empty reading otherwise; analyse chapter 3: `check(result.failedSlices == 1 && result.mentions.count == rules-only mention count, "refused slice falls back to rules")` (Review Focus 1)
  - With `LLMSvcFoundation` (Mac with Apple Intelligence): analyse chapter 3 and print the time and model calls; `check(result.modelCalls > 0, "model read chapter 1")`, `check(s144 mention's entity as of 144 is not Beth or is undecided, "snow maiden no longer forced to Beth")`
- [ ] **Step 2: Run** — Expected: compile error.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — Expected: PASS; record the chapter 3 time and call count in the hand-over message. `xcodegen generate`; iOS build succeeds.

---

### Task 9: Chapter result storage

**Files:**
- Create: `App/Analysis/Repo/ChapterAnalysisStore.swift`

**Interfaces:**
- Produces: `struct ChapterAnalysisStore: Sendable { init(root: URL); func load(bookID: UUID, chapter: Int, engineVersion: Int) -> ChapterAnalysis?; func save(_ analysis: ChapterAnalysis, bookID: UUID) throws; func clear(bookID: UUID) throws }` — file `<root>/<bookID>/analysis/chapter-<n>.json`; `load` returns nil when the file is missing, unreadable, or its `engineVersion` differs. App root: `URL.applicationSupportDirectory.appending(path: "Books")`.

- [ ] **Step 1: Write `check9.swift`** with a temporary root:
  - save chapter 3 (version 1), `check(load(version: 1) != nil, "saved chapter loads")`
  - `check(load(version: 2) == nil, "other engine version is ignored")` (Review Focus 2)
  - write garbage to chapter 4's file, `check(load(chapter: 4) == nil, "unreadable file is ignored")`
- [ ] **Step 2: Run** — Expected: compile error.
- [ ] **Step 3: Implement** with `JSONEncoder`/`JSONDecoder`, creating folders as needed.
- [ ] **Step 4: Run** — Expected: PASS. `xcodegen generate`; iOS build succeeds.

---

### Task 10: Chapter loop in the repo; controller and reader wiring

**Files:**
- Modify: `App/Analysis/Repo/AnalysisRepo.swift` (rewrite)
- Modify: `App/Analysis/Models/AnalysisSnapshot.swift`, `App/Analysis/AI/Models/EngineProgress.swift`
- Modify: `App/Analysis/Ctrl/RefCtrl.swift`, `App/Reader/VM/ReferenceVM.swift`, `App/Reader/VM/ReaderVM.swift` (`appBackgrounded`), `App/AppContainer.swift`
- Delete: `App/Analysis/AI/Svc/AnalysisScheduleSvc.swift`, `App/Analysis/AI/Models/RulesPass.swift`

**Interfaces:**
- Consumes: Tasks 8–9
- Produces:
  - `struct AnalysisSnapshot: Sendable { let book: BookAnalysis; let resolved: ResolvedAnalysis; let chaptersDone: Int; let chaptersTotal: Int; let modelCalls: Int; let failedSlices: Int; let usesModel: Bool }`; `EngineProgress` counts chapters (`done`, `total`)
  - `actor AnalysisRepo { init(bookContentRepo: BookContentRepo, prepassSvc: BookPrepassSvc, chapterSvc: ChapterAnalysisSvc, store: ChapterAnalysisStore, modelAvailSvc: ModelAvailSvc); func startAnalysis(for bookID: UUID); func stopAnalysis(); func analysis(for bookID: UUID) -> BookAnalysis; func snapshot(for bookID: UUID) -> AnalysisSnapshot?; func updates(for bookID: UUID) -> AsyncStream<Int>; func progress(for bookID: UUID) -> EngineProgress? }`
    - `startAnalysis`: no-op if this book is already running; cancels another book's run; runs at `.utility`: prepare the book, call `llm.prewarm()`, then for each story chapter in order load the stored result or analyse and save it, carrying `memory` and accumulating mentions; after each chapter publish `AnalysisMapper.map(...)` and yield the chapter number to `updates`
    - Before each chapter, while `ProcessInfo.processInfo.thermalState` is `.serious` or `.critical` or Low Power Mode is on, wait (`AnalysisRepoKnobs.throttlePause = .seconds(30)`) and check again
    - If saving a chapter throws, keep its result in memory for this run and continue; it is recomputed next time
    - `analysis(for:)` returns the latest published analysis, or an empty `BookAnalysis` before the first chapter is done (never waits)
  - `RefCtrl`: replace `prepare()`/`refine()` with `startAnalysis()` and `analysisUpdates() -> AsyncStream<Int>`; `marks`, `entity`, `passage` unchanged
  - `ReferenceVM.onAppear()`: start analysis, then `for await _ in refCtrl.analysisUpdates() { await loadMarks() }`
  - `ReaderVM.appBackgrounded()` also stops analysis (`refCtrl` via `referenceVM`); it resumes from storage on the next `onAppear`

- [ ] **Step 1: Write `check10.swift`** (repo with a temporary store root, `LLMSvcUnavailable` so it is fast):
  - start, wait for the stream to finish: `check(store has one file per story chapter, "every chapter stored")`
  - delete chapter 10's file, create a new repo on the same root, start: `check(only chapter 10 and later were analysed again, "resumes at the first missing chapter")` (count `analyze` calls with a wrapping service) (Review Focus 3)
  - `check(analysis(for:) returns immediately with zero entities before the first update, "never waits")`
  - with `LLMSvcUnavailable`: `check(every stored chapter has failedSlices == 0, "rules-only is not a failure")`
- [ ] **Step 2: Run** — Expected: compile error.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — Expected: PASS. `xcodegen generate`; iOS build succeeds.

---

### Task 11: Debug view and end-to-end run

**Files:**
- Modify: `App/Analysis/Debug/EngineDebugReport.swift`, `EngineDebugVM.swift`, `EngineDebugView.swift` (local only)

- [ ] **Step 1: Adapt the debug view** to the new `AnalysisSnapshot`: summary rows for chapters done/total, model calls, failed slices, model on/off; "Phase 2 progress" becomes chapter progress; per-sentence view reads `snapshot.resolved`.
- [ ] **Step 2: iOS build** — Expected: `** BUILD SUCCEEDED **`.
- [ ] **Step 3: Owner runs on "My Mac (Designed for iPad)"** with Apple Intelligence on: open Little Women, turn Symbols on, wait for chapter 1. Expected: Jo, Meg, Beth, Amy and Margaret marked on pages 6–8; the debug view shows chapters advancing; closing and reopening the book shows chapter 1's marks at once (loaded from storage).
