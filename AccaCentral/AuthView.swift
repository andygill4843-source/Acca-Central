//
//  AuthView.swift
//  AccaCentral
//
//  Created by Andy Gill on 05/08/2026.
//


import SwiftUI

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    @State private var mode: Mode = .login

    @State private var username = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var email = ""
    @State private var displayName = ""
    @State private var rememberMe = true
    @State private var isLoading = false
    @State private var errorMessage: String?

    enum Mode { case login, createAccount }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Acca Central")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.accaPrimary)
                    .padding(.top, 40)

                Picker("Mode", selection: $mode) {
                    Text("Log in").tag(Mode.login)
                    Text("Create account").tag(Mode.createAccount)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 24)

                VStack(spacing: 14) {
                    labeledField("Username", text: $username, autocap: false)

                    if mode == .createAccount {
                        labeledField("Display name", text: $displayName, autocap: true)
                        labeledField("Email", text: $email, autocap: false, keyboard: .emailAddress)
                    }

                    labeledField("Password", text: $password, isSecure: true)

                    if mode == .createAccount {
                        labeledField("Confirm password", text: $confirmPassword, isSecure: true)
                    }

                    if mode == .login {
                        Toggle("Remember me", isOn: $rememberMe)
                            .tint(Color.accaGold)
                    }
                }
                .padding(.horizontal, 24)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.accaLoss)
                        .padding(.horizontal, 24)
                }

                Button(action: submit) {
                    if isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text(mode == .login ? "Log in" : "Create account")
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.accaPrimary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 24)
                .disabled(isLoading)

                Spacer(minLength: 40)
            }
        }
        .background(Color.accaBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private func labeledField(_ label: String, text: Binding<String>, isSecure: Bool = false, autocap: Bool = false, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.accaTextSecondary)
            Group {
                if isSecure {
                    SecureField("", text: text)
                } else {
                    TextField("", text: text)
                        .autocapitalization(autocap ? .words : .none)
                        .keyboardType(keyboard)
                }
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
        }
    }

    private func submit() {
        errorMessage = nil
        isLoading = true

        Task {
            do {
                let user: AppUser
                if mode == .login {
                    user = try await AuthService.shared.logIn(username: username, password: password)
                    appState.rememberMe = rememberMe
                } else {
                    guard password == confirmPassword else {
                        throw NSError(domain: "", code: 0, userInfo: [NSLocalizedDescriptionKey: "Passwords don't match."])
                    }
                    user = try await AuthService.shared.signUp(username: username, email: email, password: password, displayName: displayName)
                    appState.rememberMe = true
                }
                await MainActor.run {
                    isLoading = false
                    appState.didLogIn(as: user)
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}