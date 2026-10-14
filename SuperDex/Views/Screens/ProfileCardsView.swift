//
//  ProfileCardsView.swift
//  HomeScreen
//

import SwiftUI

struct ProfileCardsView: View {
    @State private var viewModel: ProfileCardsViewModel
    @Binding var selectedProfile: ProfileCard?
    var externalNamespace: Namespace.ID?
    @Namespace private var internalNamespace

    private var activeNamespace: Namespace.ID {
        externalNamespace ?? internalNamespace
    }

    init(profiles: [ProfileCard], selectedProfile: Binding<ProfileCard?> = .constant(nil), transitionNamespace: Namespace.ID? = nil, startingIndex: Int = 0) {
        _viewModel = State(initialValue: ProfileCardsViewModel(profiles: profiles, startingIndex: startingIndex))
        _selectedProfile = selectedProfile
        self.externalNamespace = transitionNamespace
    }

    var body: some View {
        GeometryReader { geo in
            let containerWidth = geo.size.width
            let containerHeight = geo.size.height

            let centerWidth = min(290, containerWidth * 0.72)
            let centerHeight = min(420, containerHeight * 0.95)

            let sidePeek: CGFloat = max(24, containerWidth * 0.08)
            let sideScale: CGFloat = 0.9
            let sideYOffset: CGFloat = 18

            ZStack {
              ZStack {
                ForEach(Array(viewModel.profiles.enumerated()), id: \.element.id) { idx, profile in
                    let relative = viewModel.relativePosition(of: idx)
                    let isCenter = relative == 0

                    let baseX: CGFloat = {
                        switch relative {
                        case 0: return 0
                        case -1: return -((centerWidth / 2) + sidePeek)
                        case 1: return (centerWidth / 2) + sidePeek
                        default:
                            return relative < 0 ? -containerWidth : containerWidth
                        }
                    }()

                    let dragX = isCenter ? viewModel.dragOffset.width : 0
                    let scale: CGFloat = isCenter ? 1.0 : sideScale
                    let yOffset: CGFloat = isCenter ? 0 : sideYOffset
                    let opacity: Double = abs(relative) <= 1 ? 1.0 : 0.0

                    ProfileCardView(profile: profile)
                        .frame(width: centerWidth, height: centerHeight)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.black.opacity(isCenter ? 0 : 0.55))
                                .allowsHitTesting(false)
                        )
                        .matchedTransitionSource(id: profile.id, in: activeNamespace)
                        .scaleEffect(scale)
                        .offset(x: baseX + dragX, y: yOffset)
                        .opacity(opacity)
                        .allowsHitTesting(isCenter)
                        .onTapGesture {
                            if isCenter {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                selectedProfile = profile
                            }
                        }
                        .simultaneousGesture(
                            isCenter ? DragGesture(minimumDistance: 20)
                                .onChanged { value in
                                    let horizontal = abs(value.translation.width)
                                    let vertical = abs(value.translation.height)
                                    if horizontal > vertical {
                                        viewModel.dragOffset = value.translation
                                    }
                                }
                                .onEnded { value in
                                    let horizontal = abs(value.translation.width)
                                    let vertical = abs(value.translation.height)
                                    if horizontal > vertical {
                                        viewModel.handleDragEnd(translation: value.translation.width, cardWidth: centerWidth)
                                    } else {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                            viewModel.dragOffset = .zero
                                        }
                                    }
                                }
                            : nil
                        )
                        .zIndex(viewModel.zIndex(for: relative))
                        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: viewModel.currentIndex)
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewModel.dragOffset)
                }
              }
              .frame(maxWidth: .infinity, maxHeight: .infinity)

              HStack {
                navButton(systemName: "chevron.left", enabled: viewModel.currentIndex > 0) {
                    viewModel.swipeRight(cardWidth: centerWidth)
                }
                .padding(.leading, 8)

                Spacer()

                navButton(systemName: "chevron.right", enabled: viewModel.currentIndex < viewModel.profiles.count - 1) {
                    viewModel.swipeLeft(cardWidth: centerWidth)
                }
                .padding(.trailing, 8)
              }
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .allowsHitTesting(true)
              .zIndex(10)
            }
        }
    }

    private func navButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.gilroy(.semiBold, size: 16))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
                .glassEffect(.regular.interactive(), in: Circle())
        }
        .buttonStyle(.plain)
        .environment(\.colorScheme, .light)
        .opacity(enabled ? 1 : 0.4)
        .disabled(!enabled)
    }
}

#Preview {
    ProfileCardsView(profiles: sampleProfiles)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
}
