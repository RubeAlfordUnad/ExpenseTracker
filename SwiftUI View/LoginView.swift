//
//  LoginView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 2/03/26.
//

import SwiftUI

struct LoginView: View {
    
    @EnvironmentObject var auth: AuthManager
    
    @State private var username = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var message = ""
    @State private var isError = false
    
    var body: some View {
        ZStack {
            
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    
                    Spacer(minLength: 60)
                    
                    VStack(spacing: 15) {
                        
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.2))
                                .frame(width: 110, height: 110)
                            
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                                .foregroundColor(.green)
                        }
                        
                        Text("Expense Tracker")
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(.white)
                        
                        Text("Control inteligente de finanzas")
                            .font(.subheadline)
                            .foregroundColor(.yellow)
                    }
                    
                    VStack(spacing: 20) {
                        
                        Text(isRegistering ? "Crear Cuenta" : "Iniciar Sesión")
                            .font(.title2)
                            .bold()
                        
                        TextField("Usuario", text: $username)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        
                        SecureField("Contraseña", text: $password)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        
                        Button(action: handleAction) {
                            Text(isRegistering ? "Registrarse" : "Ingresar")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.black)
                                .cornerRadius(10)
                        }
                        
                        Button(isRegistering ? "Ya tengo cuenta" : "Crear cuenta") {
                            isRegistering.toggle()
                            message = ""
                        }
                        .foregroundColor(.yellow)
                        .font(.footnote)
                        
                        if !message.isEmpty {
                            Text(message)
                                .foregroundColor(isError ? .red : .green)
                                .font(.footnote)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
        }
    }
    
    func handleAction() {
        
        if isRegistering {
            
            let result = auth.register(username: username, password: password)
            
            if result == "success" {
                isError = false
                message = "Cuenta creada exitosamente 🎉"
                
                // Login automático después de registro
                _ = auth.login(username: username, password: password)
                
            } else {
                isError = true
                message = result
            }
            
        } else {
            
            let result = auth.login(username: username, password: password)
            
            if result == "success" {
                isError = false
                message = ""
            } else {
                isError = true
                message = result
            }
        }
    }
}
