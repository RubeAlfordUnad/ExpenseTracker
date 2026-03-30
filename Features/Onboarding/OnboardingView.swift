//
//  OnboardingView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 6/03/26.
//

import SwiftUI

struct OnboardingView: View {

    @EnvironmentObject var settings: AppSettings

    @State private var currentPage = 0
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    private var pages: [OnboardingPage] {
        [
            OnboardingPage(
                title: settings.t("onboarding.page1.title"),
                description: settings.t("onboarding.page1.description"),
                image: "chart.bar.fill"
            ),
            OnboardingPage(
                title: settings.t("onboarding.page2.title"),
                description: settings.t("onboarding.page2.description"),
                image: "creditcard.fill"
            ),
            OnboardingPage(
                title: settings.t("onboarding.page3.title"),
                description: settings.t("onboarding.page3.description"),
                image: "brain.head.profile"
            )
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Button(settings.t("onboarding.skip")) {
                    finishOnboarding()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)
                .accessibilityIdentifier("onboarding.skip")
            }

            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    VStack(spacing: 24) {
                        Spacer()

                        ZStack {
                            Circle()
                                .fill(Color.yellow.opacity(0.18))
                                .frame(width: 140, height: 140)

                            Image(systemName: page.image)
                                .font(.system(size: 64, weight: .semibold))
                                .foregroundColor(.yellow)
                        }

                        Text(page.title)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Text(page.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)

                        Spacer()
                    }
                    .tag(index)
                    .padding(.bottom, 20)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            VStack(spacing: 12) {
                Button {
                    if currentPage == pages.count - 1 {
                        finishOnboarding()
                    } else {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                } label: {
                    Text(
                        currentPage == pages.count - 1
                        ? settings.t("onboarding.getStarted")
                        : settings.t("onboarding.next")
                        
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.yellow)
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityIdentifier(
                        currentPage == pages.count - 1
                        ? "onboarding.getStarted"
                        : "onboarding.next"
                    )
                }

                Text(settings.t("onboarding.footer"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .background(Color(.systemBackground))
    }

    private func finishOnboarding() {
        hasSeenOnboarding = true
    }
}
