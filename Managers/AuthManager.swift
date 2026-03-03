//
//  AuthManager.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 2/03/26.
//

import Foundation
import Combine

class AuthManager: ObservableObject {
    
    // Estado de sesión
    @Published var isLoggedIn: Bool {
        didSet {
            UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn")
        }
    }
    
    // Usuario actual
    @Published var currentUser: String?
    
    init() {
        self.isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
        self.currentUser = UserDefaults.standard.string(forKey: "currentUser")
    }
    
    // MARK: - Registro
    
    func register(username: String, password: String) -> String {
        
        // Validaciones
        if username.trimmingCharacters(in: .whitespaces).isEmpty ||
            password.trimmingCharacters(in: .whitespaces).isEmpty {
            return "No puede haber campos vacíos"
        }
        
        if username.count < 4 {
            return "El usuario debe tener mínimo 4 caracteres"
        }
        
        if password.count < 4 {
            return "La contraseña debe tener mínimo 4 caracteres"
        }
        
        // Cargar usuarios guardados
        var users = loadUsers()
        
        if users[username] != nil {
            return "Ese usuario ya existe"
        }
        
        // Guardar nuevo usuario
        users[username] = password
        saveUsers(users)
        
        return "success"
    }
    
    // MARK: - Login
    
    func login(username: String, password: String) -> String {
        
        let users = loadUsers()
        
        if users.isEmpty {
            return "No hay usuarios registrados"
        }
        
        guard let savedPassword = users[username] else {
            return "Usuario no encontrado"
        }
        
        if savedPassword != password {
            return "Contraseña incorrecta"
        }
        
        // Login exitoso
        currentUser = username
        isLoggedIn = true
        UserDefaults.standard.set(username, forKey: "currentUser")
        
        return "success"
    }
    
    // MARK: - Logout
    
    func logout() {
        isLoggedIn = false
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: "currentUser")
    }
    
    // MARK: - Persistencia
    
    private func loadUsers() -> [String: String] {
        return UserDefaults.standard.dictionary(forKey: "users") as? [String: String] ?? [:]
    }
    
    private func saveUsers(_ users: [String: String]) {
        UserDefaults.standard.set(users, forKey: "users")
    }
}
