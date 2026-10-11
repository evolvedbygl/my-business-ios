//  RootTabView.swift
//  GLSmallBusiness
//
//  Created by Gold Life LLC on 5/28/26.

import SwiftUI
import GoldLifeUI

/// App root (iPhone, compact width): Contacts (2026-08-21) and Jobs (the All Jobs list, with the
/// Calendar pushed from its toolbar — same-day rework). Receipts live in the Menu (Job Records →
/// All Receipts) and Stats on the Business screen (→ Statistics).
///
/// The modern `Tab(...)` API with `.tabViewStyle(.automatic)`: a bottom tab bar everywhere this
/// shell runs. (iPad regular-width sessions never see it — they mount IPadRootSplitView's
/// three-column split instead; this TabView is the iPhone and compact-width shell.) Top-level tab
/// identity, so screenshot automation can select a tab programmatically.
enum ScreenTab: Hashable { case contacts, contracts, calendar, assistant }

struct RootTabView: View {
    @State private var selection: ScreenTab = {
        #if DEBUG
        // The people -demoScreen names (customers/employees/subcontractors) all land on the
        // Contacts tab; WHICH segment shows is AppRouter's init reading the same argument.
        return DemoMode.screen == "calendar" ? .contracts : .contacts
        #else
        return .contacts
        #endif
    }()

    var body: some View {
        TabView(selection: $selection) {
            Tab(mbLoc("Contacts"), systemImage: "person.2", value: ScreenTab.contacts) {
                ContactsScreen()
            }
            Tab(mbLoc("Contracts"), systemImage: "doc.text.fill", value: ScreenTab.contracts) {
                // The Contracts tab lands on the contracts LIST (no more Jobs; Contracts is the
                // core hub); the Calendar is one tap away in its toolbar.
                AllContractsScreen(isTabRoot: true)
            }
            if MBFeatureFlags.assistantEnabled {
                Tab(mbLoc("Assistant"), systemImage: "sparkles", value: ScreenTab.assistant) {
                    AssistantScreen()
                }
            }
        }
        .tabViewStyle(.automatic)
        // Scoped to the TabView only — iOS 26's tab bar ignores the global accent asset and
        // rendered the selected item SYSTEM BLUE once the root tint was removed (the root tint had
        // to go: an adaptive tint above the iPad's NavigationSplitView un-bridges the sidebar
        // selection — the recorded MM gotcha). My Money's TabView carries the identical scoped
        // tint.
        .tint(Color("AccentColor"))
        // The tab bar shrinks on scroll-down (iOS 26 native), the same call in the same place as My
        // Money's RootView — the two tab bars must behave identically. A standalone behaviour: it
        // needs no tab accessory, only a scroll view in the tab, which every tab root here is.
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}
