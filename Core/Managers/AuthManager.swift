//
//  AuthManager.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 2/03/26.
//

import Foundation
import Combine

struct User: Codable {
    let username: String
    let password: String
}

class AuthManager: ObservableObject {
    
    @Published var isLoggedIn = false
    @Published var currentUser: String = ""
    
    private let usersKey = "users_key"
    private let sessionKey = "session_key"
    
    init() {
        loadSession()
    }
    
    func register(username: String, password: String) -> Bool {
        var users = loadUsers()
        
        if users.contains(where: { $0.username == username }) {
            return false
        }
        
        users.append(User(username: username, password: password))
        saveUsers(users)
        return true
    }
    
    func login(username: String, password: String) -> Bool {
        let users = loadUsers()
        
        if users.contains(where: { $0.username == username && $0.password == password }) {
            currentUser = username
            isLoggedIn = true
            UserDefaults.standard.set(username, forKey: sessionKey)
            return true
        }
        
        return false
    }
    
    func logout() {
        currentUser = ""
        isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }
    
    private func loadUsers() -> [User] {
        guard let data = UserDefaults.standard.data(forKey: usersKey),
              let decoded = try? JSONDecoder().decode([User].self, from: data)
        else { return [] }
        
        return decoded
    }
    
    private func saveUsers(_ users: [User]) {
        if let encoded = try? JSONEncoder().encode(users) {
            UserDefaults.standard.set(encoded, forKey: usersKey)
        }
    }
    
    private func loadSession() {
        if let savedUser = UserDefaults.standard.string(forKey: sessionKey) {
            currentUser = savedUser
            isLoggedIn = true
        }
    }
}
