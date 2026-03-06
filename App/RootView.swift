//
//  RootView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 3/03/26.
//

import SwiftUI

struct RootView: View {
    
    @EnvironmentObject var auth: AuthManager
    
    var body: some View {
        Group {
            if auth.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}
