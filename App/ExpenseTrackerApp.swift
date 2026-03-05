//
//  ExpenseTrackerApp.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 26/02/26.
//

import SwiftUI

@main
struct ExpenseTrackerApp: App {
    
    @StateObject var auth = AuthManager()
    
    var body: some Scene {
        WindowGroup {
            if auth.isLoggedIn {
                ContentView()
                    .environmentObject(auth)
            } else {
                LoginView()
                    .environmentObject(auth)
            }
        }
    }
}
