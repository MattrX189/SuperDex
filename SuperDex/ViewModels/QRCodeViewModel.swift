//
//  QRCodeViewModel.swift
//  HomeScreen
//

import SwiftUI
import CoreImage.CIFilterBuiltins

@Observable
final class QRCodeViewModel {
    func generateQRCode(forText text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        guard let data = text.data(using: .utf8) else { return nil }
        filter.message = data
        filter.correctionLevel = "H"
        guard let ciImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = ciImage.transformed(by: transform)
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    func generateQRCode(username: String) -> UIImage? {
        guard let text = SuperDexQRPayload(username: username).encodedString() else { return nil }
        return generateQRCode(forText: text)
    }

    /// Generates a QR code for the given text and overlays the given logo in the center.
    func generateQRCode(forText text: String, logo: UIImage?) -> UIImage? {
        guard let qr = generateQRCode(forText: text) else { return nil }
        guard let logo else { return qr }

        let size = qr.size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            qr.draw(in: CGRect(origin: .zero, size: size))

            let logoSide = min(size.width, size.height) * 0.22
            let logoRect = CGRect(
                x: (size.width - logoSide) / 2,
                y: (size.height - logoSide) / 2,
                width: logoSide,
                height: logoSide
            )

            let padding: CGFloat = logoSide * 0.12
            let backdrop = logoRect.insetBy(dx: -padding, dy: -padding)
            let path = UIBezierPath(roundedRect: backdrop, cornerRadius: backdrop.width * 0.18)
            UIColor.white.setFill()
            path.fill()

            let clipPath = UIBezierPath(roundedRect: logoRect, cornerRadius: logoRect.width * 0.18)
            clipPath.addClip()
            logo.draw(in: logoRect)
        }
    }

}
