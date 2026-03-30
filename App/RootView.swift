//
//  RootView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 3/03/26.
//

import SwiftUI

struct RootView: View {

    @EnvironmentObject var auth: AuthManager
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        Group {
            if !hasSeenOnboarding {
                OnboardingView()
            } else if auth.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}
