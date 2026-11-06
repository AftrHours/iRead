# iRead diagrams

Author: Shanon Giuly Istanto · Updated 2026-11-06

Every diagram is Mermaid. GitHub draws them on this page. To edit one in Miro, copy its file from `docs/diagrams/` and paste it into Diagram → Build with code.

There is no login screen: the reader's iCloud account (shown in the reader menu) is the only account the app uses.

## 1. Use cases

Who uses the app and what they can do. Readers use both screens; developers only read shared ratings.

File: `docs/diagrams/01-use-cases.mmd`

```mermaid
flowchart LR
  reader([Reader])
  devs([Developers])

  subgraph Library
    U1(Browse and sort books)
    U2(Import an EPUB)
    U3(Mark finished, reset, remove)
    U4(Open a book)
  end

  subgraph Reading
    U5(Turn pages)
    U6(Contents and search)
    U7(Text size, spacing, theme, brightness)
    U8(Tap an underline to see what explains it)
    U9(Jump to that passage and return)
    U10(Rate the passage up or down)
    U11(Choose whether to share ratings)
    U12(See iCloud status)
  end

  U13(Read shared ratings in CloudKit Console)

  reader --- U1
  reader --- U2
  reader --- U3
  reader --- U4
  reader --- U5
  reader --- U6
  reader --- U7
  reader --- U8
  reader --- U12
  U8 -.-> U9
  U8 -.-> U10
  U10 -.-> U11
  devs --- U13
```

## 2. Architecture

One big diagram of every type has too many crossing lines, so it's split: an overview of the features, then one diagram per feature. In each, a layer only calls the layer below it. Dashed lines are calls into another feature's types. `AppContainer` builds everything; pure Rules (sorting, search, progress maths, `BookFingerprint`) are left out.

### 2a. Features

Which part of the app may use which. No cycles.

File: `docs/diagrams/02a-architecture-overview.mmd`

```mermaid
flowchart TB
  App["App · iReadApp, AppContainer, AppNav"]
  Library["Library · the library screen"]
  Reader["Reader · the reading screen"]
  Analysis["Analysis · underlines and ratings"]
  Book["Book · book data both screens share"]

  App --> Library
  App --> Reader
  Reader --> Analysis
  Library --> Book
  Reader --> Book
  Analysis --> Book
```

### 2b. Library

File: `docs/diagrams/02b-architecture-library.mmd`

```mermaid
flowchart TB
  subgraph View["View · draws the screen"]
    LibView
  end
  subgraph ViewModel["ViewModel · screen state"]
    LibVM
  end
  subgraph Controller["Controller · one use case"]
    LibCtrl
  end
  subgraph Repo["Repo · saves and loads"]
    LibRepo
    BookContentRepo
    ProgRepo
  end
  subgraph Service["Service · wraps an Apple API"]
    EPUBParseSvc
  end

  LibView --> LibVM
  LibVM --> LibCtrl
  LibCtrl --> LibRepo
  LibCtrl --> BookContentRepo
  LibCtrl --> ProgRepo
  LibRepo --> EPUBParseSvc
  BookContentRepo --> EPUBParseSvc
```

### 2c. Reader

Repos and Services sit on one row, because a Controller calls both directly.

File: `docs/diagrams/02c-architecture-reader.mmd`

```mermaid
flowchart TB
  subgraph View["View · draws the screen"]
    ReaderView
  end
  subgraph ViewModel["ViewModel · screen state"]
    ReaderVM
    SearchVM
    ReaderSettingsVM
  end
  subgraph Controller["Controller · one use case"]
    ProgressCtrl
    ReaderCtrl
    ReaderStateCtrl
  end
  subgraph Below["Repo · saves and loads   +   Service · wraps an Apple API"]
    ProgRepo
    EventSvc
    BookContentRepo
    PagerSvc
    BookStateRepo
    ReadingSettingsRepo
    BrightnessSvc
  end

  ReaderView --> ReaderVM
  ReaderVM --> SearchVM
  ReaderVM --> ReaderSettingsVM
  ReaderVM --> ProgressCtrl
  ReaderVM --> ReaderCtrl
  SearchVM --> ReaderCtrl
  SearchVM --> ReaderStateCtrl
  ReaderSettingsVM --> ReaderStateCtrl

  ProgressCtrl --> ProgRepo
  ProgressCtrl --> EventSvc
  ReaderCtrl --> BookContentRepo
  ReaderCtrl --> PagerSvc
  ReaderStateCtrl --> BookStateRepo
  ReaderStateCtrl --> ReadingSettingsRepo
  ReaderStateCtrl --> BrightnessSvc
```

### 2d. Underlines and ratings

File: `docs/diagrams/02d-architecture-underlines.mmd`

```mermaid
flowchart TB
  subgraph ViewModel["ViewModel · screen state"]
    ReaderVM
    ReferenceVM
  end
  subgraph Controller["Controller · one use case"]
    ReaderCtrl
    RefCtrl
    ReaderStateCtrl
  end
  subgraph Repo["Repo · saves and loads"]
    BookContentRepo
    UnderlineRepo
    RatingRepo
  end
  subgraph Service["Service · wraps an Apple API"]
    ModelCheckSvc
    CloudSvc
  end
  Engine[[UnderlineEngine package]]
  iCloud[(iCloud)]

  ReaderVM --> ReferenceVM
  ReferenceVM --> RefCtrl
  ReferenceVM -. pages .-> ReaderCtrl
  ReferenceVM -. return spot .-> ReaderStateCtrl

  RefCtrl --> BookContentRepo
  RefCtrl --> UnderlineRepo
  RefCtrl --> RatingRepo

  UnderlineRepo --> ModelCheckSvc
  UnderlineRepo --> Engine
  UnderlineRepo --> CloudSvc
  RatingRepo --> CloudSvc
  CloudSvc --> iCloud
```

## 3. Data model (DMD)

The app's data and how it relates. A book has one record (library) and one parsed content (reader). `BookContent.fingerprint` names a book by its text, so underlines and ratings match on every device. `ReadingSettings` is one record for the whole app.

File: `docs/diagrams/03-data-model.mmd`

```mermaid
classDiagram
  direction LR

  class BookRecord {
    UUID id
    String title
    String author
    Double progress
    Date dateAdded
    Date lastReadAt
  }
  class ReadingProgress {
    UUID bookID
    Int chapterIndex
    Double progress
    Date lastReadAt
    Date finishedAt
  }
  class ReadingPosition {
    Int paragraph
    Int charOffset
  }
  class BookState {
    List~String~ recentSearches
  }
  class ReadingSettings {
    Int textSizeIndex
    Int lineSpacingPercent
    ReadingTheme theme
  }

  class BookContent {
    String fingerprint
    Int parserVersion
  }
  class Chapter {
    String title
    String text
  }
  class Paragraph {
    Int chapterIndex
    NSRange range
  }
  class Sentence {
    Int paragraph
    NSRange range
  }
  class Page {
    Int number
    Int chapterIndex
    NSRange range
  }

  class Underline {
    String id
    NSRange range
    String text
  }
  class ContextPassage {
    Int paragraph
    NSRange range
    String text
  }
  class UnderlineRating {
    String book
    String underlineID
    Verdict verdict
    String phrase
    Int sentence
    Int reference
    Int engineVersion
  }
  class Verdict {
    <<enumeration>>
    up
    down
  }
  class Mark {
    NSRange range
    Kind kind
  }
  class SearchResult {
    String snippet
    Int pageNumber
  }

  BookRecord "1" -- "0..1" ReadingProgress : saved progress
  BookRecord "1" -- "0..1" BookState : return spot, searches
  BookRecord "1" -- "1" BookContent : parsed from its EPUB
  ReadingProgress "1" *-- "1" ReadingPosition : position
  BookState "1" *-- "0..1" ReadingPosition : returnPosition

  BookContent "1" *-- "1..*" Chapter
  Chapter "1" *-- "1..*" Paragraph
  Paragraph "1" *-- "0..*" Sentence
  Chapter "1" -- "1..*" Page : split to fit the screen

  Chapter "1" -- "0..*" Underline : found by the engine
  Underline "1" -- "1" ContextPassage : explained by
  Underline "1" -- "0..1" UnderlineRating : rated by the reader
  UnderlineRating "0..*" --> "0..1" Verdict : verdict
  Page "1" *-- "0..*" Mark : underlines and highlight
  SearchResult "0..*" --> "1" ReadingPosition : where
```

## 4. UnderlineEngine input and output

What iRead sends the engine (one chapter) and what it gets back (one result per paragraph). Indexes are global; ranges are UTF-16 inside a paragraph.

File: `docs/diagrams/04-underline-engine-data.mmd`

```mermaid
classDiagram
  direction LR

  class ChapterInput {
    +Int chapterIndex
    +List~ParagraphInput~ paragraphs
    +List~SentenceInput~ sentences
  }
  class ParagraphInput {
    +Int index
    +String text
  }
  class SentenceInput {
    +Int index
    +Int paragraph
    +NSRange range
  }

  class UnderlineCtrl {
    +prepare(ChapterInput) IndexedChapter
    +paragraphResults(IndexedChapter, Int startingAt) AsyncStream~ParagraphResult~
  }

  class ParagraphResult {
    +List~Underline~ underlines
    +List~UnderlineRecord~ records
  }
  class Underline {
    +String id
    +Int sentence
    +Int paragraph
    +NSRange range
    +String text
    +UnderlineKind kind
    +EventRole role
    +AnswerPassage reference
    +AnswerPath decidedBy
  }
  class AnswerPassage {
    +Int sentence
    +Int paragraph
    +NSRange range
    +String text
  }
  class UnderlineRecord {
    +Int sentence
    +String phrase
    +UnderlineKind kind
    +AnswerPath path
    +Int pickedSentence
    +Bool kept
    +DropReason dropped
  }

  class UnderlineKind {
    <<enumeration>>
    action
    reaction
    feeling
    outcome
    place
    thing
    person
  }
  class EventRole {
    <<enumeration>>
    setting
    initiatingEvent
    internalResponse
    goal
    attempt
    reaction
    outcome
  }
  class AnswerPath {
    <<enumeration>>
    model
    rules
  }
  class DropReason {
    <<enumeration>>
    noCandidate
    pickedNone
    confirmRejected
    guardRejected
    densityLimit
    modelFailed
    explainedInParagraph
  }

  %% Input: what a chapter is made of
  ChapterInput "1" *-- "1..*" ParagraphInput : paragraphs
  ChapterInput "1" *-- "1..*" SentenceInput : sentences
  ParagraphInput "1" <-- "0..*" SentenceInput : belongs to (paragraph = index)

  %% Engine: one chapter in, one result per paragraph out
  UnderlineCtrl "1" ..> "1" ChapterInput : prepares
  UnderlineCtrl "1" ..> "0..*" ParagraphResult : yields
  ParagraphInput "1" -- "0..1" ParagraphResult : result for

  %% Output: what a result holds
  ParagraphResult "1" *-- "0..*" Underline : underlines
  ParagraphResult "1" *-- "0..*" UnderlineRecord : records
  UnderlineRecord "1" -- "0..1" Underline : becomes (when kept)
  Underline "1" *-- "1" AnswerPassage : reference

  %% Output points back at the input by global index
  Underline "0..*" --> "1" SentenceInput : sentence
  AnswerPassage "0..*" --> "1" SentenceInput : sentence (always earlier)

  %% Enum values
  Underline "0..*" --> "1" UnderlineKind : kind
  Underline "0..*" --> "0..1" EventRole : role
  Underline "0..*" --> "1" AnswerPath : decidedBy
  UnderlineRecord "0..*" --> "0..1" AnswerPath : path
  UnderlineRecord "0..*" --> "0..1" DropReason : dropped
```

## 5. Where data lives

Everything is saved on the phone first. Underlines also go to the reader's own iCloud; ratings go to the developers only if the reader shares.

File: `docs/diagrams/05-where-data-lives.mmd`

```mermaid
flowchart LR
  subgraph Phone["On the phone"]
    F1[library.json, hidden-samples.json]
    F2[book.epub for each imported book]
    F3[progress.json for each book]
    F4[state.json for each book]
    F5[reading-settings.json]
    F6[ratings.json]
    F7[Underlines / fingerprint / chapter-N.json]
    F8[5 sample EPUBs inside the app]
  end

  subgraph Private["Reader's iCloud · private database"]
    C1[ChapterUnderlines · one record per chapter]
  end

  subgraph Public["Developers' CloudKit · public database"]
    C2[UnderlineRating · one record per rating]
  end

  devs([Developers])

  F7 -- uploaded when a chapter is done --> C1
  C1 -- downloaded when the phone has none --> F7
  F6 -- only if the reader shares --> C2
  devs -- read in CloudKit Console --> C2
```

## 6. Data flow, level 0 (DFD)

The whole app as one process, and what goes in and out.

File: `docs/diagrams/06-dfd-level-0.mmd`

```mermaid
flowchart LR
  Reader[Reader]
  Files[Files app]
  Model[Apple on-device model]
  Private[Reader's iCloud]
  Public[Developers' CloudKit]
  App((iRead))

  Reader -- taps, settings, search, ratings --> App
  App -- pages, underlines, cards --> Reader
  Files -- EPUB file --> App
  App -- phrases and passages --> Model
  Model -- picks and confirms --> App
  App -- finished chapters' underlines --> Private
  Private -- saved underlines --> App
  App -- shared ratings --> Public
```

## 7. Data flow, level 1 (DFD)

Six processes and the files they read and write.

File: `docs/diagrams/07-dfd-level-1.mmd`

```mermaid
flowchart LR
  Reader[Reader]
  Files[Files app]
  Model[Apple on-device model]
  Private[Reader's iCloud]
  Public[Developers' CloudKit]

  P1((1 Manage library))
  P2((2 Show pages))
  P3((3 Save progress))
  P4((4 Underline and explain))
  P5((5 Settings and search))
  P6((6 Rate and share))

  D1[(library.json, hidden-samples.json)]
  D2[(book.epub, sample EPUBs)]
  D3[(progress.json)]
  D4[(state.json)]
  D5[(reading-settings.json)]
  D6[(Underlines chapter-N.json)]
  D7[(ratings.json)]

  Files -- EPUB --> P1
  P1 -- book list --> D1
  P1 -- EPUB copy --> D2
  D1 -- books --> P1
  D3 -- progress --> P1
  P1 -- finished, reset --> D3
  P1 -- library, covers --> Reader

  Reader -- open a book --> P2
  D2 -- chapters --> P2
  D5 -- text size, theme --> P2
  D3 -- last position --> P2
  P2 -- pages --> Reader

  Reader -- page turn --> P3
  P3 -- position, percent read --> D3

  P2 -- chapter text --> P4
  D6 -- saved underlines --> P4
  Private -- saved underlines --> P4
  P4 -- phrases --> Model
  Model -- answers --> P4
  P4 -- new underlines --> D6
  P4 -- new underlines --> Private
  P4 -- underlines, cards --> Reader
  P4 -- return spot --> D4

  Reader -- settings, query --> P5
  P5 -- settings --> D5
  P5 -- recent searches --> D4
  P5 -- results --> Reader

  Reader -- thumb, share choice --> P6
  D6 -- the rated underline --> P6
  P6 -- ratings --> D7
  P6 -- shared ratings --> Public
```

## 8. Sequence: open the app

The library is the sample books plus imported books, each with its saved progress.

File: `docs/diagrams/08-sequence-open-app.mmd`

```mermaid
sequenceDiagram
  actor Reader
  participant LibView
  participant LibVM
  participant LibCtrl
  participant LibRepo
  participant ProgRepo
  participant BookContentRepo

  Reader->>LibView: open the app
  LibView->>LibVM: onAppear
  LibVM->>LibCtrl: loadLibrary
  LibCtrl->>LibRepo: fetchBooks
  LibRepo-->>LibCtrl: samples + imported books
  LibCtrl->>ProgRepo: progress for each book
  ProgRepo-->>LibCtrl: progress
  LibCtrl-->>LibVM: books with progress
  LibVM->>LibCtrl: cover for each book
  LibCtrl->>BookContentRepo: cover
  BookContentRepo-->>LibVM: cover image
  LibVM-->>LibView: sorted books with covers
```

## 9. Sequence: read a book

Opening restores the last position. Every page turn saves progress; Back saves once more and stops the underlining.

File: `docs/diagrams/09-sequence-read-a-book.mmd`

```mermaid
sequenceDiagram
  actor Reader
  participant ReaderView
  participant ReaderVM
  participant ReaderCtrl
  participant ProgressCtrl
  participant ReferenceVM
  participant BookContentRepo
  participant ProgRepo

  Reader->>ReaderView: tap a book
  ReaderView->>ReaderVM: onAppear
  ReaderVM->>ReaderCtrl: openBook
  ReaderCtrl->>BookContentRepo: content
  BookContentRepo-->>ReaderCtrl: chapters, paragraphs, sentences
  ReaderVM->>ProgressCtrl: savedProgress
  ProgressCtrl->>ProgRepo: progress
  ProgRepo-->>ReaderVM: last position
  ReaderVM->>ReaderCtrl: restorePosition, currentPage
  ReaderVM->>ReferenceVM: bookOpened
  ReferenceVM->>ReferenceVM: check iCloud, resend unsent ratings
  ReaderCtrl-->>ReaderView: page

  Reader->>ReaderView: swipe
  ReaderView->>ReaderVM: pageChanged
  ReaderVM->>ReaderCtrl: pageChanged
  ReaderCtrl-->>ReaderVM: new progress
  ReaderVM->>ProgressCtrl: pageRead
  ProgressCtrl->>ProgRepo: save

  Reader->>ReaderView: Back
  ReaderVM->>ProgressCtrl: saveNow
  ReaderVM->>ReferenceVM: close
  ReaderVM-->>Reader: show library
```

## 10. Sequence: underlines

A chapter is underlined once: from the phone first, then iCloud, and only then the engine.

File: `docs/diagrams/10-sequence-underlines.mmd`

```mermaid
sequenceDiagram
  actor Reader
  participant ReferenceVM
  participant RefCtrl
  participant UnderlineRepo
  participant CloudSvc as CloudSvc (reader's iCloud)
  participant Engine as UnderlineEngine

  ReferenceVM->>RefCtrl: underlineUpdates for this page
  RefCtrl->>UnderlineRepo: underline this chapter (by book fingerprint)
  alt saved on this phone
    UnderlineRepo-->>RefCtrl: saved underlines
  else saved in iCloud
    UnderlineRepo->>CloudSvc: record fingerprint-chapter
    CloudSvc-->>UnderlineRepo: saved underlines
    UnderlineRepo->>UnderlineRepo: save on this phone
  else not saved anywhere
    UnderlineRepo->>Engine: prepare, paragraphResults
    Engine-->>UnderlineRepo: underlines, one paragraph at a time
    UnderlineRepo->>UnderlineRepo: save on this phone
    UnderlineRepo->>CloudSvc: save to iCloud
  end
  RefCtrl-->>ReferenceVM: new underlines found
  ReferenceVM->>RefCtrl: marks on this page
  ReferenceVM-->>Reader: underlines on the page
```

## 11. Sequence: rate a passage

The first rating asks whether to share. Ratings always stay on the phone; shared ones also go to the developers.

File: `docs/diagrams/11-sequence-rate-a-passage.mmd`

```mermaid
sequenceDiagram
  actor Reader
  participant ReferenceVM
  participant RefCtrl
  participant RatingRepo
  participant CloudSvc
  participant Public as Developers' CloudKit

  Reader->>ReferenceVM: tap an underline
  ReferenceVM->>RefCtrl: underline and its rating so far
  ReferenceVM-->>Reader: card with the passage and thumbs
  Reader->>ReferenceVM: thumb up or down
  opt first rating ever
    ReferenceVM-->>Reader: ask to share ratings
    Reader->>ReferenceVM: Share or Don't Share
    ReferenceVM->>RefCtrl: setSharesRatings
  end
  ReferenceVM->>RefCtrl: rate
  RefCtrl->>RatingRepo: save rating
  RatingRepo->>RatingRepo: write ratings.json
  alt sharing is on
    RatingRepo->>CloudSvc: save UnderlineRating
    CloudSvc->>Public: record
  else sharing is off
    RatingRepo->>RatingRepo: keep on this phone only
  end
  Note over Reader,Public: Tapping the same thumb again takes the rating back and deletes its record.
```

## 12. Sequence: jump and return

Jumping saves where the reader was, so Return to Reading can bring them back.

File: `docs/diagrams/12-sequence-jump-and-return.mmd`

```mermaid
sequenceDiagram
  actor Reader
  participant ReferenceVM
  participant ReaderCtrl
  participant ReaderStateCtrl
  participant ReaderVM

  Reader->>ReferenceVM: Jump to Passage
  ReferenceVM->>ReaderCtrl: start of this page
  ReferenceVM->>ReaderStateCtrl: saveReturnPosition
  ReferenceVM->>ReaderCtrl: page with the passage
  ReferenceVM->>ReaderVM: show that page, highlighted

  Reader->>ReferenceVM: Return to Reading
  ReferenceVM->>ReaderStateCtrl: returnPosition
  ReferenceVM->>ReaderCtrl: page at that position
  ReferenceVM->>ReaderStateCtrl: clearReturnPosition
  ReferenceVM->>ReaderVM: show that page
  ReferenceVM-->>Reader: toast Returned to page N
```

## 13. Screens (state)

Two screens. Everything else is a sheet, card or prompt over the reader.

File: `docs/diagrams/13-state-screens.mmd`

```mermaid
stateDiagram-v2
  [*] --> Library
  Library --> Reader : tap a book
  Reader --> Library : Back (saves progress)

  state Reader {
    [*] --> Reading
    Reading --> Menu : tap menu
    Menu --> Contents
    Menu --> Search
    Menu --> Theme
    Contents --> Reading : pick a chapter
    Search --> Reading : pick a result
    Theme --> Reading : close
    Reading --> Card : tap an underline
    Card --> Card : thumb up or down
    Card --> AskToShare : first rating
    AskToShare --> Card : Share or Don't Share
    Card --> Reading : close
    Card --> Passage : Jump to Passage
    Passage --> Reading : Return to Reading
  }
```
