//
//  View+Keyboard.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 20/03/26.
//

import SwiftUI
import UIKit

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
