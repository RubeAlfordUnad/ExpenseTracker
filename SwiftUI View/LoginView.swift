//
//  LoginView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 2/03/26.
//

import SwiftUI

struct LoginView: View {
    
    @EnvironmentObject var auth: AuthManager
    
    @State private var user = ""
    @State private var pass = ""
    @State private var error = ""
    
    var body: some View {
        VStack(spacing: 20) {
            
            Spacer()
            
            Text("Bienvenido a Nexora")
                .font(.largeTitle.bold())
            
            VStack(spacing: 15) {
                
                TextField("Usuario", text: $user)
                    .textFieldStyle(.roundedBorder)
                
                SecureField("Contraseña", text: $pass)
                    .textFieldStyle(.roundedBorder)
                
                if !error.isEmpty {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button("Login") {
                    if !auth.login(username: user, password: pass) {
                        error = "Credenciales Inválidas"
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding()
            
            Spacer()
            
            Text("© 2026 Ruben Alford. All rights reserved.")
                .font(.footnote)
                .foregroundColor(.gray)
                .padding(.bottom, 10)
        }
        .padding()
    }
}
