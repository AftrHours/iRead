# Design: UnderlineEngine in iRead

**Branch:** `Underline-Engine`, from `dev`. A trial: `dev` and `main` stay as they are.

## Intent

Make UnderlineEngine the app's only reference engine, so a tap shows the author's earlier sentence that explains the phrase. Symbols and the old character engine are gone on this branch.

## What changed

- UnderlineEngine supplies every underline, reference card and jump highlight.
- Removed: Symbols (the toggle, Chapter Symbols, the symbol card and editor, edited symbols in `BookState`) and the old engine (`Analysis/AI`, `AnalysisRepo`, `ChapterAnalysisStore`, the old engine debug view).
- Debug builds have a screen behind the ladybug button: how the run is going, every underlined sentence by chapter, and the phrases dropped by reason.

## Behaviour

- `UnderlineRepo` runs in the background while the book is open, one chapter at a time, and pauses when the device is hot or in Low Power Mode.
- The reader's chapter goes first, from the reader's paragraph. After each chapter the repo takes the reader's current chapter if it isn't done, otherwise the next one. A chapter already running is not interrupted, because its work would be lost.
- Underlines appear as they are found. A chapter is saved to `Books/<id>/underlines/chapter-N.json` only when finished, so an interrupted chapter starts again.
- A saved chapter is reused unless the engine version, the parser version, or whether the model is available has changed.
- The card shows the phrase, the passage, its location, and Jump to Passage. There is no character name: the engine doesn't know who anyone is.
- Search stays within one chapter. All kinds are kept, `person` included, because nothing else covers people now.

## Package branch

The app uses UnderlineEngine's `Underline-Engine` branch, which adds `paragraphResults(in:startingAt:)` for the drop reasons. Point `project.yml` back at `main` once that branch is merged.

## Not in this phase

Tuning, cross-chapter references, and PRD changes. If this branch is merged, PRD 2.1 needs updating (it excludes ordinary actions from Events) and PRD 3.1 Symbols no longer applies.

## Known limits

- A chapter that comes out empty is saved only if a test call to the model succeeds, because availability can report yes while every call fails. A chapter with some underlines is saved as it is, so a phrase dropped by a passing model failure stays dropped until the engine version changes.
- The Simulator can't judge this feature: its model calls fail and it finds no events. Use an iPad.
- Saved results of the old engine stay in `Books/<id>/analysis/` on devices that ran it. Nothing reads them.
- Accuracy is unchanged by this work: on the unreviewed golden set, 7 of 10 references shown were wrong.
