//
//  OnboardingView.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 6/03/26.
//

import SwiftUI

struct OnboardingView: View {
    
    @State private var currentPage = 0
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    
    let pages = [
        OnboardingPage(
            title: "Track Your Expenses",
            description: "Easily record every expense and understand where your money goes.",
            image: "chart.bar.fill"
        ),
        
        OnboardingPage(
            title: "Control Your Budget",
            description: "Set monthly budgets and stay on top of your finances.",
            image: "creditcard.fill"
        ),
        
        OnboardingPage(
            title: "Smarter Financial Decisions",
            description: "Analyze your spending with powerful statistics.",
            image: "brain.head.profile"
        )
    ]
    
    var body: some View {
        
        VStack {
            
            TabView(selection: $currentPage) {
                
                ForEach(0..<pages.count, id: \.self) { index in
                    
                    VStack(spacing: 25) {
                        
                        Spacer()
                        
                        Image(systemName: pages[index].image)
                            .font(.system(size: 80))
                            .foregroundColor(.yellow)
                        
                        Text(pages[index].title)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        
                        Text(pages[index].description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page)
            
            
            Button {
                if currentPage == pages.count - 1 {
                    hasSeenOnboarding = true
                } else {
                    currentPage += 1
                }
                
            } label: {
                
                Text(currentPage == pages.count - 1 ? "Get Started" : "Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.yellow)
                    .foregroundColor(.black)
                    .cornerRadius(14)
            }
            .padding()
        }
    }
}
