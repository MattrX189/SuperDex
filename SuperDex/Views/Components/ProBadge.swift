//
//  ProBadge.swift
//  SuperDex
//
//  The "Pro" badge shown next to a premium member's name. Uses the
//  ProBadge image asset; height-fixed so it aligns with the name.
//

import SwiftUI

struct ProBadge: View {
    var height: CGFloat = 16

    var body: some View {
        Image("ProBadge")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .accessibilityLabel("Pro member")
    }
}

#Preview {
    ProBadge()
        .padding()
        .background(Color.black)
}
