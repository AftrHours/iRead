//
//  QuickGuide.swift
//  iRead
//
//  Created by Putri Aziza Mufva on 22/11/26.
//

import Lottie
import SwiftUI

struct QuickGuideView: View {
    var onBack: () -> Void
    var onConfirm: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Lost the plot?")
                        .font(AppTypography.title3(.semibold))
                        .foregroundStyle(Color(AppColors.actionSecondary))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color(AppColors.textSecondary), in: RoundedRectangle(cornerRadius: 8))

                    Text("Tap reading area to reveal the underlines. Select a line to revisit the author’s earlier words.")
                        .font(AppTypography.body(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 40)
                }

                // `Resources/Animation/QuickGuide.lottie`. Still, on its first frame, with Reduce Motion.
                LottieView { try await DotLottieFile.named("QuickGuide") }
                    .playbackMode(reduceMotion ? .paused(at: .progress(0)) : .playing(.fromProgress(0, toProgress: 1, loopMode: .loop)))
                    .resizable()
                    .scaledToFit()
                    .padding(.vertical, 40)
                    .accessibilityHidden(true)

                Button(action: onConfirm) {
                    Text("Got it!")
                        .font(AppTypography.body(.medium))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(AppColors.actionPrimary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(AppColors.bgPrimary).ignoresSafeArea())
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Back")
                }
            }
        }
    }
}

#Preview() {
    QuickGuideView(onBack: {}, onConfirm: {})
}
