//
//  HomeEntranceTransition.swift
//  SuperDex
//
//  How Home arrives straight after onboarding's card launch. The card
//  screen has already faded to Home's black background, so Home builds
//  itself up on it: each section rises and fades in, one after another,
//  then the tab bar slides up — while MyCardLandingOverlay flies the card
//  in and genies it into My Card.
//
//  Driven from inside HomeView: it renders with `arrived == false` first,
//  then flips it once on screen (Home's first frame is heavy, so a plain
//  insertion transition would play out before anything was drawn).
//

import SwiftUI

extension View {
    /// One section of Home's entrance. `order` sets its place in the
    /// sequence; while `arrived` is false the section is hidden just below
    /// its spot.
    func homeEntranceItem(order: Int, arrived: Bool) -> some View {
        self
            .opacity(arrived ? 1 : 0)
            .offset(y: arrived ? 0 : 26)
            .blur(radius: arrived ? 0 : 6)
            .animation(
                .spring(response: 0.6, dampingFraction: 0.85).delay(Double(order) * 0.08),
                value: arrived
            )
    }
}
