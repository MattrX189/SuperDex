//
//  DeviceContactsSection.swift
//  SuperDex
//
//  The "From your phone" half of the Contacts tab. Everyone in the device
//  address book shows up here: people already on SuperDex render as real
//  cards you can connect to, everyone else gets an Invite button. Either
//  way they can be selected and dropped into a group.
//

import SwiftUI

// MARK: - Scope

/// Which half of the Contacts tab is showing.
enum ContactsScope: String, CaseIterable, Identifiable {
    case superdex
    case phone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .superdex: return "SuperDex"
        case .phone:    return "From Phone"
        }
    }

    var icon: String {
        switch self {
        case .superdex: return "qrcode"
        case .phone:    return "iphone"
        }
    }
}

/// Sub-filter within the phone list.
enum DeviceContactFilter: String, CaseIterable, Identifiable {
    case onSuperDex
    case notOnSuperDex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .onSuperDex:    return "On SuperDex"
        case .notOnSuperDex: return "Not on SuperDex"
        }
    }

    var icon: String {
        switch self {
        case .onSuperDex:    return "checkmark.seal.fill"
        case .notOnSuperDex: return "paperplane.fill"
        }
    }
}

// MARK: - Access gates

/// Shown before the user has granted (or after they've refused) address-book
/// access. Explains the trade rather than just naming the permission.
struct DeviceContactsAccessCard: View {
    let state: DeviceContactsService.AccessState
    var onRequest: () -> Void

    private var icon: String {
        state == .notDetermined ? "person.crop.circle.badge.questionmark" : "lock.fill"
    }

    private var title: String {
        switch state {
        case .notDetermined: return "Find people you already know"
        case .denied:        return "Contacts access is off"
        case .restricted:    return "Contacts are restricted"
        default:             return ""
        }
    }

    private var body_: String {
        switch state {
        case .notDetermined:
            return "SuperDex checks which of your phone contacts are already here. Your contacts stay on your device — only numbers are matched, never names."
        case .denied:
            return "Turn on Contacts for SuperDex in Settings to see who you already know here."
        case .restricted:
            return "This device doesn't allow apps to read contacts."
        default:
            return ""
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.white.opacity(0.45))

            Text(title)
                .font(.gilroy(.bold, size: 18))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)

            Text(body_)
                .font(.gilroy(.regular, size: 13))
                .foregroundStyle(.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            if state == .notDetermined {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onRequest()
                } label: {
                    Text("Allow Contacts Access")
                        .font(.gilroy(.semiBold, size: 15))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            } else if state == .denied {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.gilroy(.semiBold, size: 15))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(.white.opacity(0.12)))
                        .overlay(Capsule().strokeBorder(.white.opacity(0.20), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
    }
}

/// iOS 18 partial access — tell the user why the list looks short.
struct LimitedAccessNotice: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            Text("You've shared only some contacts. Change this in Settings › SuperDex › Contacts.")
                .font(.gilroy(.regular, size: 12))
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.05))
        )
    }
}

// MARK: - Invite row

/// A device contact with no SuperDex account: initials or their address-book
/// photo, whatever the address book knows about them, and one Invite button.
struct DeviceContactRow: View {
    let entry: DeviceContactEntry
    var isSelecting: Bool = false
    var isSelected: Bool = false
    var onInvite: () -> Void

    private let cornerRadius: CGFloat = 26

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if isSelecting {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }

            card
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isSelecting)
    }

    private var card: some View {
        HStack(alignment: .center, spacing: 14) {
            avatar

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.device.name)
                    .font(.gilroy(.semiBold, size: 17))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !entry.device.roleLine.isEmpty {
                    Text(entry.device.roleLine.uppercased())
                        .font(.gilroy(.semiBold, size: 10))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                } else if !entry.device.primaryPhone.isEmpty {
                    Text(entry.device.primaryPhone)
                        .font(.gilroy(.regular, size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            if !isSelecting {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onInvite()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Invite")
                            .font(.gilroy(.semiBold, size: 13))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(.white.opacity(0.10), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardShape.fill(.white.opacity(0.04)))
        .overlay(
            cardShape.strokeBorder(
                isSelected ? Color.white.opacity(0.9) : .white.opacity(0.08),
                lineWidth: isSelected ? 2 : 1
            )
        )
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = entry.device.thumbnail, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.14), lineWidth: 1))
        } else {
            ZStack {
                Circle().fill(.white.opacity(0.08))
                Text(entry.device.initials)
                    .font(.gilroy(.bold, size: 17))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(width: 48, height: 48)
            .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
    }
}
