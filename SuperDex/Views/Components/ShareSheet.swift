//
//  ShareSheet.swift
//  SuperDex
//
//  Presents a UIActivityViewController from the top-most view controller so
//  the share sheet always slides up as a bottom sheet on iPhone (avoids the
//  SwiftUI ShareLink quirk where it anchors to a nav-bar button at the top).
//

import UIKit
import LinkPresentation

@MainActor
enum ShareSheet {
    static func present(image: UIImage, title: String) {
        let item = ImageActivityItem(image: image, title: title)
        let activityVC = UIActivityViewController(activityItems: [item], applicationActivities: nil)

        guard let top = topMostViewController() else { return }

        // iPad: present centered with no arrow. Ignored on iPhone (bottom sheet).
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = top.view
            popover.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        top.present(activityVC, animated: true)
    }

    private static func topMostViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard var top = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

/// Provides the image plus a friendly title/preview for the share sheet header.
private final class ImageActivityItem: NSObject, UIActivityItemSource {
    let image: UIImage
    let title: String

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ controller: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(_ controller: UIActivityViewController,
                                itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        image
    }

    func activityViewController(_ controller: UIActivityViewController,
                                subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        title
    }

    func activityViewControllerLinkMetadata(_ controller: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        return metadata
    }
}
