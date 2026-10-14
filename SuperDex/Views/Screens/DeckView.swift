//
//  DeckView.swift
//  SuperDex
//
//  Deck tab: all of the user's groups, with its own navigation stack.
//

import SwiftUI

/// Deck tab routes that aren't model values.
enum DeckRoute: Hashable { case allEvents }

struct DeckView: View {
    @Environment(HomeViewModel.self) private var viewModel
    @Environment(EventsViewModel.self) private var eventsVM

    var body: some View {
        NavigationStack {
            GroupsView(title: "Deck", showsBackButton: false)
                .navigationDestination(for: CardGroup.self) { group in
                    GroupDetailView(
                        group: group,
                        onEdit: { viewModel.groupBeingEdited = group }
                    )
                }
                .navigationDestination(for: AppEvent.self) { event in
                    EventDetailView(event: event)
                }
                .navigationDestination(for: DeckRoute.self) { route in
                    switch route {
                    case .allEvents:
                        EventsScreen(viewModel: eventsVM, showsBackButton: true)
                    }
                }
        }
    }
}
