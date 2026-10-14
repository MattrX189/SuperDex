//
//  BrandIcons.swift
//  HomeScreen
//

import SwiftUI

struct BrandIcon: View {
    let name: String

    var body: some View {
        Image("icon-\(name)")
            .resizable()
            .renderingMode(.template)
            .aspectRatio(contentMode: .fit)
    }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.purple, .pink, .orange],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        HStack(spacing: 16) {
            ForEach(["instagram", "x", "github", "whatsapp", "youtube", "spotify"], id: \.self) { name in
                BrandIcon(name: name)
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .padding(10)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    )
            }
        }
    }
}
