import Foundation
import Observation

/// Thumbs on the shown reference card, the share question, the Share Ratings switch and how iCloud stands.
@MainActor
@Observable
final class RatingVM {
    /// The shown card's rating.
    private(set) var verdict: Verdict?
    private(set) var isAskingToShare = false
    private(set) var sharesRatings = false
    /// Checked again when the app comes back, in case the reader signed in in Settings.
    private(set) var cloudAccount: CloudAccount?

    private var underlineID: String?
    /// Ratings are saved one after another, so quick taps land in order.
    private var ratingTask: Task<Void, Never>?
    /// Not private, for ReaderVM's debug sheet.
    let ratingCtrl: RatingCtrl

    init(ratingCtrl: RatingCtrl) {
        self.ratingCtrl = ratingCtrl
    }

    func bookOpened() async {
        sharesRatings = await ratingCtrl.sharesRatings() == true
        checkCloud()
    }

    func appForegrounded() {
        checkCloud()
    }

    /// In the background, so opening a book doesn't wait for iCloud. Also retries ratings an earlier send missed.
    private func checkCloud() {
        Task { [weak self, ratingCtrl] in
            let account = await ratingCtrl.cloudAccount()
            self?.cloudAccount = account
            await ratingCtrl.sendUnsentRatings()
        }
    }

    func cardShown(underlineID: String) async {
        self.underlineID = underlineID
        verdict = nil
        // A rating still being saved is read back once it's in.
        await ratingTask?.value
        let saved = (try? await ratingCtrl.verdict(onUnderline: underlineID)) ?? nil
        guard self.underlineID == underlineID else { return }
        verdict = saved
    }

    /// Tapping the chosen thumb again takes the rating back. The first rating asks whether to share.
    func verdictTapped(_ tapped: Verdict) {
        guard let underlineID else { return }
        let newVerdict = verdict == tapped ? nil : tapped
        verdict = newVerdict
        ratingTask = Task { [previous = ratingTask, ratingCtrl] in
            if newVerdict != nil, await ratingCtrl.sharesRatings() == nil { isAskingToShare = true }
            await previous?.value
            try? await ratingCtrl.rate(underline: underlineID, newVerdict)
        }
    }

    func sharingChosen(_ shares: Bool) {
        isAskingToShare = false
        sharesRatings = shares
        Task { await ratingCtrl.setSharesRatings(shares) }
    }
}
