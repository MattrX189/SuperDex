//
//  GenieImage.swift
//  SuperDex
//
//  Used by MyCardLandingOverlay to pour the user's new card into
//  Home's My Card tile at the end of onboarding.
//

import SwiftUI
import UIKit

/// macOS-style "genie" minimize, drawn as thin horizontal strips of a
/// still image. Each strip is squeezed toward `target` the closer it is
/// to it, so the sides curve into a neck. Over `progress` 0…1:
///   0.0–0.5  bend:  the top stretches up to the target, sides pinch in.
///   0.5–1.0  slide: the bottom rises into the neck and the card pours
///                   through it.
struct GenieImage: View {
    let image: UIImage
    /// Where the image sits at progress 0.
    let rect: CGRect
    /// The neck it pours into (above `rect`).
    let target: CGPoint
    let progress: CGFloat

    private let strips = 160
    private let neckHalfWidth: CGFloat = 8

    var body: some View {
        Canvas { context, _ in
            let resolved = context.resolve(Image(uiImage: image))
            let bend = smooth(min(progress * 2, 1))
            let slide = smooth(max(progress * 2 - 1, 0))

            let top = lerp(rect.minY, target.y, bend)
            let bottom = lerp(rect.maxY, target.y, slide)
            guard bottom - top > 0.5 else { return }
            let span = max(rect.maxY - target.y, 1)

            for index in 0..<strips {
                let s0 = CGFloat(index) / CGFloat(strips)
                let s1 = CGFloat(index + 1) / CGFloat(strips)
                let y0 = top + s0 * (bottom - top)
                let y1 = top + s1 * (bottom - top)

                // Narrower the nearer the row is to the neck.
                let u = min(max(((y0 + y1) / 2 - target.y) / span, 0), 1)
                let squeeze = bend * (1 - smooth(u))
                let left = lerp(rect.minX, target.x - neckHalfWidth, squeeze)
                let right = lerp(rect.maxX, target.x + neckHalfWidth, squeeze)
                guard right - left > 0.5 else { continue }

                // Draw the whole image scaled so this strip's slice lands in
                // the strip rect, clipped to it (+0.5pt overlap hides seams).
                let scaleX = (right - left) / rect.width
                let scaleY = (y1 - y0) / (rect.height / CGFloat(strips))
                let stripRect = CGRect(x: left, y: y0, width: right - left, height: y1 - y0 + 0.5)
                context.drawLayer { layer in
                    layer.clip(to: Path(stripRect))
                    layer.draw(resolved, in: CGRect(
                        x: left,
                        y: y0 - s0 * rect.height * scaleY,
                        width: rect.width * scaleX,
                        height: rect.height * scaleY
                    ))
                }
            }
        }
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
    private func smooth(_ t: CGFloat) -> CGFloat { t * t * (3 - 2 * t) }
}
