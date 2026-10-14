//
//  QRImageScanner.swift
//  SuperDex
//
//  Lets users scan a SuperDex QR that was shared to them as an image:
//  a PHPicker wrapper to choose a photo + Vision-based QR detection.
//

import SwiftUI
import PhotosUI
import Vision

/// Photo-library picker (single image). PHPicker runs out of process, so it
/// needs no photo-library permission / Info.plist key.
struct PhotoPicker: UIViewControllerRepresentable {
    var onPick: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage?) -> Void
        init(onPick: @escaping (UIImage?) -> Void) { self.onPick = onPick }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                onPick(nil)   // cancelled or nothing usable
                return
            }
            provider.loadObject(ofClass: UIImage.self) { [onPick] object, _ in
                DispatchQueue.main.async { onPick(object as? UIImage) }
            }
        }
    }
}

enum QRImageDecoder {
    /// Returns the first QR payload string found in the image, if any.
    static func decode(_ image: UIImage) -> String? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        return request.results?
            .compactMap { $0.payloadStringValue }
            .first
    }
}
