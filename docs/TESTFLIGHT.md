# Getting a build to TestFlight

Refrn (working name iRead) goes to outside testers first, through a **public TestFlight link**. The testers read a book that
already has underlines and give each reference a thumbs up or down. Precision is the number of thumbs up against thumbs down.
This page is the list of what has to be true before the first upload, and who does each step.

## Already in the project

| What | Where |
| --- | --- |
| App icon, light and dark | `App/Resources/Assets.xcassets/AppIcon.appiconset`, named in `project.yml` (`ASSETCATALOG_COMPILER_APPICON_NAME`) |
| Display name Refrn | `project.yml`, app and Share extension. The bundle ID stays `com.aftrhours.reader` |
| Privacy manifest | `App/PrivacyInfo.xcprivacy` |
| Export compliance answered | `ITSAppUsesNonExemptEncryption: false` in the app's Info.plist (`project.yml`) |
| One version for the app and the extension | `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`, read by both Info.plists |

**Privacy manifest.** It declares `UserDefaults` (reason `CA92.1`, the app's own settings) and one collected data type: *Other User
Content*, not linked to the reader, not used for tracking. That is the thumbs up or down with the underlined sentence and its
passage, sent only after the reader says yes. The purpose is set to *Analytics*; if the App Store Connect privacy answers say
something else, change both so they match.

**Encryption.** The app only uses the system's HTTPS and CloudKit, and `BookFingerprint` only hashes (SHA-256). Nothing of its own
is encrypted, so the app is exempt. Confirm this with whoever owns the App Store Connect account.

**Build number.** `CURRENT_PROJECT_VERSION` is `1`. Xcode Cloud numbers its own builds; check on the first upload that the number
it uses is higher each time, and if it is not, bump `CURRENT_PROJECT_VERSION` in `project.yml` by hand.

## Steps only a person can do

Do these in order. The first two decide whether the ratings arrive at all.

1. **Deploy the CloudKit schema to Production.** TestFlight builds write to Production, builds from Xcode write to Development.
   In the CloudKit Console, `iCloud.com.aftrhours.reader` → Deploy Schema Changes. Then, for `UnderlineRating`, take **Read**
   away from **World**. Details: [ICLOUD.md](ICLOUD.md).
2. **Check one rating end to end.** Install the first TestFlight build, rate one reference, and look for it in the CloudKit
   Console under the **Production** environment, Public Database, `UnderlineRating`.
3. **Create the app in App Store Connect** with the bundle ID `com.aftrhours.reader`. Check that the name *Refrn* is free first.
4. **Privacy policy URL.** The app sends book passages to our public CloudKit database when a reader agrees, so reviewers look for
   a policy. Host a page and put its URL in App Store Connect.
5. **Test Information** (needed for the first external build, which goes through Beta App Review): a beta description, what to
   test, and an email for feedback. A draft is below.
6. **Xcode Cloud.** A workflow that archives the `iRead` scheme and distributes to TestFlight. `ci_scripts/ci_post_clone.sh`
   already generates the project with XcodeGen.
7. **Public link.** After the first build passes Beta App Review, TestFlight → the group → Enable Public Link. Set a tester limit
   (for example 30) so it stays manageable.

## Drafts for App Store Connect

**Beta description**

> Refrn is an e-reader that underlines phrases and shows you where an earlier passage explains them. This beta checks whether
> those underlines are right.

**What to test**

> Open any book in the library and read for a while. Tap an underlined phrase to see its earlier passage, then tap thumbs up if the
> passage helps explain the phrase and thumbs down if it does not. The first time you rate, the app asks if your ratings may be
> shared with the developers.

**Notes for the reviewer**

> No sign-in is needed. Five books are included. Underlines are made on the device with Apple Intelligence where it is available,
> and with a simpler method where it is not. Ratings are optional and anonymous.

## Things to know when testing

- **Apple Intelligence.** The underlines are better on a device that has it turned on. Elsewhere the app falls back to rules only,
  and each rating records which of the two made the underline (`decidedBy`), so the two can be counted apart.
- **Reading the ratings.** CloudKit Console, or `cktool` as in [ICLOUD.md](ICLOUD.md), with `--environment production`.
