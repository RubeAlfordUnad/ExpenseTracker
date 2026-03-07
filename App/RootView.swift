//
//  RootView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 3/03/26.
//

import SwiftUI

struct RootView: View {
    
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    
    var body: some View {
        
        if hasSeenOnboarding {
            LoginView()
        } else {
            OnboardingView()
        }
    }
}
