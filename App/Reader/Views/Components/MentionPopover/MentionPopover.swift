//
//  MentionPopover.swift
//  iRead
//
//  Created by Putri Aziza Mufva on 21/11/26.
//

import SwiftUI

/// Shown by `PageTextView` above a jumped-to passage.
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
        .padding(.horizontal, MentionPopoverKnobs.horizontalPadding)
        .padding(.vertical, 8)
        .background(AppColors.popoverBg, in: .rect(cornerRadius: 12))
        .overlay(alignment: .bottomLeading) {
            MentionArrow()
                .fill(AppColors.popoverBg)
                .frame(width: MentionPopoverKnobs.arrowSize.width, height: MentionPopoverKnobs.arrowSize.height)
                .offset(x: MentionPopoverKnobs.arrowInset, y: MentionPopoverKnobs.arrowSize.height)
        }
        .padding(.bottom, MentionPopoverKnobs.arrowSize.height)
        .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        .accessibilityElement(children: .combine)
    }
}

enum MentionPopoverKnobs {
    static let horizontalPadding: CGFloat = 12
    static let arrowSize = CGSize(width: 18, height: 9)
    static let arrowInset: CGFloat = 20

    /// Scales the tag about its arrow's tip, so it grows out of the passage like a popover.
    static func arrowScale(_ scale: CGFloat, size: CGSize) -> CGAffineTransform {
        let tip = CGPoint(x: arrowInset + arrowSize.width / 2 - size.width / 2, y: size.height / 2)
        return CGAffineTransform(translationX: tip.x, y: tip.y).scaledBy(x: scale, y: scale).translatedBy(x: -tip.x, y: -tip.y)
    }
}

private struct MentionArrow: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

#Preview() {
    VStack(alignment: .leading, spacing: 2) {
        MentionPopover()
        Text("'Curly black hair, brown skin, big black eyes, handsome nose…'")
            .background(Color(AppColors.readerHighlight))
    }
    .padding()
}
