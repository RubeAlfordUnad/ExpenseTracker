//
//  AuthManager.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 2/03/26.
//

import Foundation
import Combine

class AuthManager: ObservableObject {
    
    @Published var isLoggedIn: Bool {
        didSet {
            UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn")
        }
    }
    
    init() {
        self.isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
    }
    
    func login(username: String, password: String) -> Bool {
        if username == "admin" && password == "1234" {
            isLoggedIn = true
            return true
        }
        return false
    }
    
    func logout() {
        isLoggedIn = false
    }
}
