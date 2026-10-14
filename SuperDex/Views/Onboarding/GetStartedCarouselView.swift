//
//  GetStartedCarouselView.swift
//  SuperDex
//
//  Swipeable onboarding carousel with profile, group, and contact examples
//

import SwiftUI

struct GetStartedCarouselView: View {
    @State private var selectedPage = 0
    @State private var showLoginSheet = false

    // Animation state (transform-only — never affects layout size)
    @State private var didAppear = false
    @State private var pulsePhase = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                // Page indicator lines (top)
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index == selectedPage ? Color(red: 0.45, green: 0.40, blue: 0.95) : Color.white.opacity(0.25))
                            .frame(width: index == selectedPage ? 28 : 18, height: 4)
                            .animation(.easeInOut(duration: 0.3), value: selectedPage)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 12)

                // Carousel
                TabView(selection: $selectedPage) {
                    // Page 1: Profile Card
                    onboardingPage1
                        .clipped()
                        .tag(0)

                    // Page 2: Group Card
                    onboardingPage2
                        .clipped()
                        .tag(1)

                    // Page 3: Contact Card
                    onboardingPage3
                        .clipped()
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: .infinity)

                // Get Started Button
                Button {
                    showLoginSheet = true
                } label: {
                    Text("Get Started")
                        .font(.gilroy(.bold, size: 18))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .white.opacity(pulsePhase ? 0.4 : 0.2), radius: pulsePhase ? 22 : 12, y: 8)
                }
                .scaleEffect(pulsePhase ? 1.0 : 0.97)
                .animation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: pulsePhase)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            pulsePhase = true
            try? await Task.sleep(for: .milliseconds(80))
            didAppear = true
        }
        .sheet(isPresented: $showLoginSheet) {
            LoginBottomSheet()
        }
    }

    // MARK: - Page 1: Profile Card

    private var sampleProfileCards: [ProfileCard] {
        [
            ProfileCard(
                firstName: "Priya",
                lastName: "Sharma",
                username: "priyasharma",
                companyName: "TechCorp",
                jobRole: "Product Designer",
                bio: "Building beautiful products",
                phone: "+1 (555) 234-5678",
                email: "sarah@techcorp.com",
                links: [
                    "linkedin": "linkedin.com/in/sarahchen",
                    "dribbble": "dribbble.com/sarahchen",
                    "x": "@sarahchen"
                ],
                theme: .glacier ,
                avatar: " "
            ),
            ProfileCard(
                firstName: "Gaurang",
                lastName: "Pant",
                username: "founderM1801",
                companyName: "Mattr",
                jobRole: "Founder",
                bio: "Building SuperDex",
                phone: "",
                email: "",
                links: [
                    "instagram": "",
                    "linkedin": "",
                    "x": "",
                    "github": ""
                ],
                theme: .superDex,
                avatar: "memoji1"
            ),
            ProfileCard(
                firstName: "Rohan",
                lastName: "Gupta",
                username: "rohangupta",
                companyName: "Innovation Labs",
                jobRole: "Engineer",
                bio: "Solving hard problems",
                phone: "+1 (555) 345-6789",
                email: "marcus@innovation.com",
                links: [
                    "github": "github.com/marcusp",
                    "linkedin": "linkedin.com/in/marcusp",
                    "x": "@marcusp"
                ],
                theme: .forest,
                avatar: "memoji3"
            ),
            ProfileCard(
                firstName: "Ananya",
                lastName: "Iyer",
                username: "ananyaiyer",
                companyName: "Creative Agency",
                jobRole: "Marketing Lead",
                bio: "Telling brand stories",
                phone: "+1 (555) 456-7890",
                email: "emma@creative.com",
                links: [
                    "instagram": "@emmar",
                    "linkedin": "linkedin.com/in/emmar",
                    "x": "@emmar"
                ],
                theme: .ember,
                avatar: "memoji4"
            )
        ]
    }

    private var onboardingPage1: some View {
        VStack(spacing: 10) {
            
            // SuperDex Splash logo at top
            Image("Splash")
                .resizable()
                .scaledToFit()
                .frame(height: 44)
                .padding(.top, 8)
            
            
            VStack(spacing: 10) {
              

                Text("Your Professional Identity")
                    .font(.gilroy(.bold, size: 26))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Create stunning profile card to share instantly!")
                    .font(.gilroy(.regular, size: 14))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .appearTransition(active: didAppear && selectedPage == 0, delay: 0.05)

            // Single profile card
            ProfileCardView(profile: sampleProfileCards[1], showsEmptyLinks: true)
                .aspectRatio(300.0 / 460.0, contentMode: .fit)
                .frame(maxHeight: 450)
                .padding(.horizontal, 56)
                .padding(.top, 8)
                .appearTransition(active: didAppear && selectedPage == 0, delay: 0.18)
                .environment(\.openURL, OpenURLAction { _ in
                    if let url = URL(string: "https://superdex.in") {
                        UIApplication.shared.open(url)
                    }
                    return .handled
                })

            Spacer()
        }
    }

    // MARK: - Page 2: Group Card

    private func wallpaperData(named imageName: String) -> Data? {
        UIImage(named: imageName)?.jpegData(compressionQuality: 0.9)
    }

    private var sampleGroups: [CardGroup] {
        [
            CardGroup(
                name: "WWDC 2026",
                colorName: "indigo",
                icon: "megaphone.fill",
                wallpaperData: wallpaperData(named: "WWDC2026"),
                members: [
                    GroupMember(name: "Sarah Chen", avatar: "memoji2"),
                    GroupMember(name: "Alex Johnson", avatar: "memoji1"),
                    GroupMember(name: "Marcus Patel", avatar: "memoji3"),
                    GroupMember(name: "Emma Rodriguez", avatar: "memoji4"),
                    GroupMember(name: "Liam Brown", avatar: "memoji5")
                ]
            ),
            CardGroup(
                name: "Developer",
                colorName: "indigo",
                icon: "briefcase.fill",
                wallpaperData: wallpaperData(named: "Developer"),
                members: [
                    GroupMember(name: "Nathan Brooks", avatar: "memoji6"),
                    GroupMember(name: "Ari Klein", avatar: "memoji7"),
                    GroupMember(name: "Ethan Blake", avatar: "memoji1"),
                    GroupMember(name: "Maya Patel", avatar: "memoji4"),
                    GroupMember(name: "Lily Zhang", avatar: "memoji2"),
                    GroupMember(name: "Ben Smith", avatar: "memoji3"),
                    GroupMember(name: "Sara Lee", avatar: "memoji5")
                ]
            ),
            CardGroup(
                name: "Designer",
                colorName: "indigo",
                icon: "calendar",
                wallpaperData: wallpaperData(named: "designer"),
                members: [
                    GroupMember(name: "Jake Wilson", avatar: "memoji3"),
                    GroupMember(name: "Maya Patel", avatar: "memoji4"),
                    GroupMember(name: "Lily Zhang", avatar: "memoji6")
                ]
            )
        ]
    }

    private var onboardingPage2: some View {
        VStack(spacing: 10) {
            // SuperDex Splash logo at top
            Image("Splash")
                .resizable()
                .scaledToFit()
                .frame(height: 44)
                .padding(.top, 8)

            VStack(spacing: 10) {
                Text("Organize Your Network")
                    .font(.gilroy(.bold, size: 26))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Create decks to manage and organize your contacts efficiently")
                    .font(.gilroy(.regular, size: 14))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .appearTransition(active: didAppear && selectedPage == 1, delay: 0.05)

            // Group Cards
            VStack(spacing: 16) {
                ForEach(Array(sampleGroups.enumerated()), id: \.element.id) { index, group in
                    GroupCardView(group: group)
                        .appearTransition(active: didAppear && selectedPage == 1, delay: 0.12 + Double(index) * 0.10)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer()
        }
    }

    // MARK: - Page 3: Contact Card

    private var onboardingPage3: some View {
        VStack(spacing: 10) {
            // SuperDex Splash logo at top
            Image("Splash")
                .resizable()
                .scaledToFit()
                .frame(height: 44)
                .padding(.top, 8)

            VStack(spacing: 10) {
                Text("Track Your Connections")
                    .font(.gilroy(.bold, size: 26))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Save contacts and track when you met them")
                    .font(.gilroy(.regular, size: 14))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .appearTransition(active: didAppear && selectedPage == 2, delay: 0.05)

            //Spacer()

            // Contact Cards Example
            VStack(spacing: 16) {
                contactRowExample(
                    name: "Rohan Gupta",
                    role: "Product Manager",
                    company: "Apple",
                    meetings: "3 meetings",
                    avatar: "memoji2"
                )

                contactRowExample(
                    name: "Arjun Mehta",
                    role: "Senior Engineer",
                    company: "Nvidia",
                    meetings: "5 meetings",
                    avatar: "memoji3"
                )

                contactRowExample(
                    name: "Vikram Reddy",
                    role: "Designer",
                    company: "Creative Agency",
                    meetings: "2 meetings",
                    avatar: "memoji4"
                )
                contactRowExample(
                    name: "Aditya Rao",
                    role: "Venture Capitalist",
                    company: "CapitalCorp",
                    meetings: "3 meetings",
                    avatar: "memoji2"
                )

                
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .appearTransition(active: didAppear && selectedPage == 2, delay: 0.15)

            Spacer()
        }
    }

    private func contactRowExample(name: String, role: String, company: String, meetings: String, avatar: String) -> some View {
        HStack(spacing: 12) {
            Image(avatar)
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(name)
                        .font(.gilroy(.semiBold, size: 15))
                        .foregroundStyle(.white)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 0.45, green: 0.40, blue: 0.95))
                }
                Text("\(role) at \(company)")
                    .font(.gilroy(.regular, size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                Text(meetings)
                    .font(.gilroy(.regular, size: 11))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private extension View {
    /// Staggered entrance: fades + slides up + pops in when `active` becomes true.
    /// Uses only transform modifiers (opacity/offset/scale) so it never affects layout size.
    func appearTransition(active: Bool, delay: Double = 0) -> some View {
        self
            .opacity(active ? 1 : 0)
            .offset(y: active ? 0 : 30)
            .scaleEffect(active ? 1 : 0.96)
            .animation(.spring(response: 0.6, dampingFraction: 0.82).delay(delay), value: active)
    }
}

#Preview {
    GetStartedCarouselView()
        .environment(AuthViewModel())
}
