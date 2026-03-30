//
//  Untitled.swift
//  ExpenseTracker
//
//  Created by Ruben Alford on 17/03/26.
//

import Foundation

enum InsightType {
    case positive
    case warning
    case neutral
}

struct InsightResult {

    let title: String
    let message: String
    let type: InsightType
}
