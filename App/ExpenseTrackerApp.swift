//
//  ExpenseTrackerApp.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 26/02/26.
//

import SwiftUI

@main
struct ExpenseTrackerApp: App {
    
    @StateObject private var auth = AuthManager()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
        }
    }
}
