//
//  SplashVidView.swift
//  SuperDex
//

import SwiftUI
import AVKit

struct SplashVidView: View {
    @Binding var isFinished: Bool

    @State private var opacity: Double = 1.0
    @State private var brandingOpacity: Double = 0.0

    private let videoName = "Splash"

    private var videoURL: URL? {
        for ext in ["mp4", "MP4", "mov", "MOV"] {
            if let url = Bundle.main.url(forResource: videoName, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let url = videoURL {
                SplashVideoPlayer(url: url) {
                    finish()
                }
                .ignoresSafeArea()
            } else {
                Text("Splash video missing from bundle")
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Spacer()
                Text("from")
                    .font(.gilroy(.medium, size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                Image("MattrTextLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 18)
                    .opacity(0.85)
            }
            .padding(.bottom, 32)
            .opacity(brandingOpacity)
        }
        .opacity(opacity)
        .task {
            try? await Task.sleep(for: .seconds(1.5))
            withAnimation(.easeInOut(duration: 0.6)) {
                brandingOpacity = 1
            }
        }
        .task {
            if videoURL == nil {
                try? await Task.sleep(for: .seconds(1.5))
                finish()
            }
        }
    }

    private func finish() {
        guard !isFinished else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            opacity = 0
        }
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            isFinished = true
        }
    }
}

private struct SplashVideoPlayer: UIViewRepresentable {
    let url: URL
    let onFinish: () -> Void

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        let player = AVPlayer(url: url)
        player.isMuted = true
        view.player = player

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            onFinish()
        }

        player.play()
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {}
}

private final class PlayerContainerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    var player: AVPlayer? {
        get { playerLayer.player }
        set {
            playerLayer.player = newValue
            playerLayer.videoGravity = .resizeAspectFill
        }
    }
}

#Preview {
    SplashVidView(isFinished: .constant(false))
}
