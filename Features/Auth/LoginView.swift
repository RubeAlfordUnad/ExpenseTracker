//
//  LoginView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 2/03/26.
//

import SwiftUI
import UIKit

struct LoginView: View {
    
    @EnvironmentObject var auth: AuthManager
    
    @State private var username = ""
    @State private var password = ""
    @State private var isRegister = false
    @State private var errorMsg = ""
    
    @FocusState private var isInputActive: Bool
    
    var body: some View {
        ZStack {
            
            LinearGradient(
                colors: [
                    Color.black,
                    Color.black.opacity(0.92),
                    Color.green.opacity(0.15)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                
                Spacer(minLength: 30)
                
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.yellow.opacity(0.12))
                            .frame(width: 90, height: 90)
                        
                        Circle()
                            .stroke(Color.yellow.opacity(0.28), lineWidth: 1.2)
                            .frame(width: 90, height: 90)
                        
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.yellow)
                    }
                    
                    Text("Nexora")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    
                    Text("Tu dinero bajo control")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.68))
                }
                
                VStack(spacing: 20) {
                    
                    HStack(spacing: 12) {
                        authModeButton(
                            title: "Login",
                            isActive: !isRegister,
                            activeColor: .yellow
                        ) {
                            isRegister = false
                            errorMsg = ""
                            isInputActive = false
                        }
                        
                        authModeButton(
                            title: "Register",
                            isActive: isRegister,
                            activeColor: .green
                        ) {
                            isRegister = true
                            errorMsg = ""
                            isInputActive = false
                        }
                    }
                    
                    VStack(spacing: 14) {
                        inputField(
                            icon: "person.fill",
                            placeholder: "Username",
                            text: $username
                        )
                        
                        secureInputField(
                            icon: "lock.fill",
                            placeholder: "Password",
                            text: $password
                        )
                    }
                    
                    if !errorMsg.isEmpty {
                        Text(errorMsg)
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    Button {
                        isInputActive = false
                        handleAction()
                    } label: {
                        Text(isRegister ? "Create account" : "Enter")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(isRegister ? Color.green : Color.yellow)
                            .foregroundColor(.black)
                            .cornerRadius(16)
                            .shadow(color: (isRegister ? Color.green : Color.yellow).opacity(0.28), radius: 10, x: 0, y: 5)
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.white.opacity(0.06))
                        .background(.ultraThinMaterial.opacity(0.15))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
                .padding(.horizontal, 24)
                
                Spacer()
                
                Text(
                    isRegister
                    ? "Create your account and start organizing your finances."
                    : "Log in to continue managing your expenses."
                )
                .font(.caption)
                .foregroundColor(.white.opacity(0.55))
                .padding(.bottom, 18)
                
                VStack(spacing: 4) {
                    Divider()
                        .background(Color.white.opacity(0.15))
                        .padding(.horizontal, 60)
                    
                    Text("Ruben Alford · 2026")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.35))
                    
                    Text("Nexora")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.25))
                }
                .padding(.bottom, 10)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isInputActive = false
            hideKeyboard()
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isInputActive = false
                    hideKeyboard()
                }
            }
        }
    }
    
    private func handleAction() {
        guard !username.isEmpty, !password.isEmpty else {
            errorMsg = "Complete all fields"
            return
        }
        
        if isRegister {
            if auth.register(username: username, password: password) {
                errorMsg = "Account created. Now log in."
                isRegister = false
                password = ""
            } else {
                errorMsg = "That username already exists"
            }
        } else {
            if !auth.login(username: username, password: password) {
                errorMsg = "Incorrect credentials"
            }
        }
    }
    
    @ViewBuilder
    private func authModeButton(title: String, isActive: Bool, activeColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(isActive ? activeColor : Color.white.opacity(0.05))
                .foregroundColor(isActive ? .black : .white)
                .cornerRadius(14)
        }
    }
    
    @ViewBuilder
    private func inputField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.yellow)
                .frame(width: 18)
            
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundColor(.white)
                .focused($isInputActive)
        }
        .padding()
        .background(Color.white.opacity(0.07))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private func secureInputField(icon: String, placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.green)
                .frame(width: 18)
            
            SecureField(placeholder, text: text)
                .foregroundColor(.white)
                .focused($isInputActive)
        }
        .padding()
        .background(Color.white.opacity(0.07))
        .cornerRadius(16)
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
