//
//  MentionPopover.swift
//  iRead
//
//  Created by Putri Aziza Mufva on 21/11/26.
//

import SwiftUI

struct MentionPopover: View {

    var body: some View {
        HStack(spacing: 8) {
            Image("quotationIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
                .accessibilityHidden(true)

            Text("Mentioned here")
                .font(AppTypography.subheadline(.semibold))
                .foregroundStyle(AppColors.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview() {
    @Previewable @State var isShown = true
    Text("Mother")
        .underline(pattern: .dot, color: AppColors.actionPrimary)
        .popover(isPresented: $isShown) {
            MentionPopover()
                .padding()
                .accessibilityLabel("Mentioned here")
                .presentationCompactAdaptation(.popover)
                .presentationBackground(AppColors.popoverBg)
        }
}
