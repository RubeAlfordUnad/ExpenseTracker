# Nexora

Nexora is a personal finance iOS app built with SwiftUI. It helps users track expenses, income, monthly budgets, debts, recurring payments, money accounts, and transfers between accounts in a clean and practical workflow.

## Overview

The app separates **budget planning** from **where money is actually stored**.

That means:
- a **monthly budget** is used to control spending
- **money accounts** represent where funds are located, such as cash, savings, digital wallets, or other balances
- **transfers** move money between accounts without affecting income, expenses, or the monthly budget

This makes the app more realistic for day-to-day personal finance tracking.

## Features

- Authentication
- Expense tracking
- Income tracking
- Monthly budget dashboard
- Manual money accounts management
- Account balance sync from expenses and income
- Internal transfers between accounts
- Credit card debt tracking
- Recurring monthly payments
- Custom categories for expenses
- Custom categories for income
- Custom categories for money accounts
- Financial overview dashboard
- Statistics and charts
- Local backup and restore

## Architecture

The project follows a modular SwiftUI structure with a lightweight MVVM-style organization.

### Main folders

- `App`  
  App entry flow, tab navigation, app-level orchestration

- `Core`  
  Models, persistence, shared managers, validation, and app-wide utilities

- `Features`  
  Screen-level modules such as Dashboard, Expenses, Income, Transfers, Debts, Recurring Payments, and Settings

- `Services`  
  Supporting business logic such as syncing balances, backup/restore, and other domain helpers

## Tech Stack

- SwiftUI
- SwiftData
- UserDefaults
- Charts

## Main Modules

- Dashboard
- Expenses
- Income
- Transfers
- Debts
- Recurring Payments
- Settings
- Backup & Restore

## Key Concepts

### Monthly Budget
The monthly budget represents a spending limit for the month. It is not the same as available money.

### Money Accounts
Money accounts represent where the user keeps funds, for example:
- Cash
- Savings
- Checking
- Digital wallet
- Investment
- Other balances

### Transfers
Transfers move money from one account to another:
- they do not count as income
- they do not count as expense
- they do not affect the monthly budget

### Balance Sync
When an expense or income is linked to an account:
- creating it updates the account balance
- editing it reverts the previous effect and applies the new one
- deleting it restores the affected balance

## Dashboard Highlights

- Monthly financial summary
- Budget progress
- Money accounts summary
- Recent transfers
- Upcoming recurring payments
- Debt snapshot
- Recent activity with a cleaner limit on visible items

## Requirements

- Xcode 15 or newer recommended
- iOS 17 or newer recommended
- macOS Sonoma or newer recommended for development

## Getting Started

1. Clone the repository.
2. Open the project in Xcode.
3. Make sure all new files are included in the app target.
4. Build and run on a simulator or physical device.

## Development Notes

- If you change SwiftData models, you may need to remove the app from the simulator/device during development to reset the local store.
- Some data is stored using SwiftData and some lightweight preferences remain in UserDefaults.
- Backup and restore should be tested after structural model changes.

## Current Functionality

The app currently supports:
- recording expenses and income
- assigning transactions to money accounts
- keeping balances updated
- moving funds between accounts through transfers
- tracking debts and recurring payments
- customizing reusable categories
- viewing a compact finance dashboard

## Roadmap

Planned or recommended next improvements:

- Account-to-account transfer filters and analytics
- Optional automatic vs manual balance mode per account
- Protection when deleting accounts that already have linked transactions or transfers
- Better transaction-to-account history visibility
- More advanced reports and trend analysis
- Improved onboarding for first-time users
- Cloud sync

## Screenshots

...

## Author

Ruben Alford
