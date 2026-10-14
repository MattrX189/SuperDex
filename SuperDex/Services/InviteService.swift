//
//  InviteService.swift
//  SuperDex
//
//  "Invite to SuperDex" for address-book contacts who don't have an account.
//
//  Nothing is ever sent on the user's behalf: this only opens Messages with
//  the text pre-filled, or the share sheet. The user still taps Send.
//

import UIKit

@MainActor
enum InviteService {

    // TODO: replace with the live App Store listing once SuperDex ships.
    static let appStoreURL = "https://apps.apple.com/app/superdex"

    static func message(for name: String, from senderName: String) -> String {
        let greeting = name.isEmpty ? "Hey" : "Hey \(name.split(separator: " ").first.map(String.init) ?? name)"
        let signature = senderName.trimmingCharacters(in: .whitespaces)
        let sender = signature.isEmpty ? "" : " — \(signature)"
        return "\(greeting)! I'm on SuperDex — it's how I share my card and keep track of people I meet. Grab it here: \(appStoreURL)\(sender)"
    }

    /// Opens Messages addressed to `phone` with the invite pre-filled. Falls
    /// back to the share sheet on devices that can't send SMS (most iPads).
    static func invite(name: String, phone: String, senderName: String) {
        let body = message(for: name, from: senderName)
        let digits = phone.filter { $0.isNumber || $0 == "+" }

        var components = URLComponents()
        components.scheme = "sms"
        components.path = digits
        components.queryItems = [URLQueryItem(name: "body", value: body)]

        if let url = components.url, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            share(text: body)
        }
    }

    /// Generic share for "invite people" with no specific number attached.
    static func share(text: String) {
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        guard let top = topMostViewController() else { return }

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
