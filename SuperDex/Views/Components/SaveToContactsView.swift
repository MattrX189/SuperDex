//
//  SaveToContactsView.swift
//  HomeScreen
//

import SwiftUI
import Contacts
import ContactsUI

struct SaveToContactsView: UIViewControllerRepresentable {
    let profile: ProfileCard
    var onFinish: () -> Void = {}

    func makeUIViewController(context: Context) -> UINavigationController {
        let contact = Self.makeContact(from: profile)

        let controller = CNContactViewController(forNewContact: contact)
        controller.delegate = context.coordinator
        controller.allowsActions = true

        let nav = UINavigationController(rootViewController: controller)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, CNContactViewControllerDelegate {
        let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
            viewController.dismiss(animated: true) { [onFinish] in
                onFinish()
            }
        }
    }

    private static func makeContact(from profile: ProfileCard) -> CNMutableContact {
        let contact = CNMutableContact()

        contact.givenName = profile.firstName
        contact.familyName = profile.lastName

        if !profile.jobRole.isEmpty {
            contact.jobTitle = profile.jobRole
        }

        if !profile.bio.isEmpty {
            contact.note = profile.bio
        }

        if !profile.phone.isEmpty {
            contact.phoneNumbers = [
                CNLabeledValue(
                    label: CNLabelPhoneNumberMobile,
                    value: CNPhoneNumber(stringValue: profile.phone)
                )
            ]
        }

        if !profile.email.isEmpty {
            contact.emailAddresses = [
                CNLabeledValue(label: CNLabelWork, value: profile.email as NSString)
            ]
        }

        var socialProfiles: [CNLabeledValue<CNSocialProfile>] = []
        let igHandle = profile.instagram.replacingOccurrences(of: "@", with: "")
        if !igHandle.isEmpty {
            socialProfiles.append(CNLabeledValue(label: nil, value: CNSocialProfile(
                urlString: "https://instagram.com/\(igHandle)",
                username: igHandle,
                userIdentifier: nil,
                service: "Instagram"
            )))
        }
        let xHandle = profile.x.replacingOccurrences(of: "@", with: "")
        if !xHandle.isEmpty {
            socialProfiles.append(CNLabeledValue(label: nil, value: CNSocialProfile(
                urlString: "https://x.com/\(xHandle)",
                username: xHandle,
                userIdentifier: nil,
                service: CNSocialProfileServiceTwitter
            )))
        }
        if !socialProfiles.isEmpty {
            contact.socialProfiles = socialProfiles
        }

        var urls: [CNLabeledValue<NSString>] = []
        if !profile.linkedin.isEmpty {
            urls.append(CNLabeledValue(label: "LinkedIn", value: "https://\(profile.linkedin)" as NSString))
        }
        if !profile.github.isEmpty {
            urls.append(CNLabeledValue(label: "GitHub", value: "https://\(profile.github)" as NSString))
        }
        if !urls.isEmpty {
            contact.urlAddresses = urls
        }

        return contact
    }
}
