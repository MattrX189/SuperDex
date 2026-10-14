//
//  QRShareCard.swift
//  SuperDex
//
//  Branded card rendered to a UIImage for sharing a user's QR code.
//  Never shown directly in the UI — used only as an ImageRenderer source.
//

import SwiftUI

struct QRShareCard: View {
    let name: String
    let jobRole: String
    let companyName: String
    let theme: CardTheme
    let qrImage: UIImage

    private var roleLine: String {
        switch (jobRole.isEmpty, companyName.isEmpty) {
        case (false, false): return "\(jobRole)  ·  \(companyName)"
        case (false, true):  return jobRole
        case (true, false):  return companyName
        case (true, true):   return ""
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text(name.isEmpty ? "SuperDex" : name)
                    .font(.gilroy(.bold, size: 30))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                if !roleLine.isEmpty {
                    Text(roleLine.uppercased())
                        .font(.gilroy(.semiBold, size: 12))
                        .tracking(1.6)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 48)
            .padding(.horizontal, 28)

            Image(uiImage: qrImage)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 240, height: 240)
                .padding(22)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 20, y: 10)

            VStack(spacing: 6) {
                HStack(spacing: 10) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 5, y: 2)

                    Text("SuperDex")
                        .font(.gilroy(.bold, size: 22))
                        .foregroundStyle(.white)
                }

                Text("Scan with SuperDex to connect")
                    .font(.gilroy(.medium, size: 13))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.bottom, 48)
        }
        .frame(width: 380)
        .background(
            ZStack {
                LinearGradient(
                    colors: theme.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Subtle bottom vignette so the footer logo separates from
                // the gradient without needing a solid tile behind it.
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.55),
                        .init(color: .black.opacity(0.30), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
        .padding(24)
        .background(Color.black)
    }
}
