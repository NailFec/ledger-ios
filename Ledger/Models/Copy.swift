import Foundation

enum Copy {
    enum Navigation {
        static let activity = "Activity"
        static let insights = "Insights"
        static let accounts = "Accounts"
        static let settings = "Settings"
        static let newEntry = "New entry"
        static let signIn = "Sign in"
        static let signUp = "Sign up"
        static let signOut = "Sign out"
    }

    enum EntryKind {
        static let expense = "Expense"
        static let income = "Income"
        static let loan = "Loan"
    }

    enum Fields {
        static let amount = "Amount (CNY)"
        static let amountNote = "Amount note"
        static let amountNotePlaceholder = "For example, 10 USD. Not included in totals."
        static let account = "Account"
        static let name = "Name"
        static let date = "Date"
        static let allocation = "Allocation"
        static let tags = "Tags"
        static let subscription = "Subscription"
        static let source = "Source"
        static let type = "Type"
        static let note = "Note"
        static let attachments = "Attachments"
    }

    enum Allocation {
        static let day = "Today"
        static let week = "This week"
        static let month = "This month"
        static let year = "This year"
        static let reserved = "Reserved"
        static let none = "Unallocated"
    }

    enum LoanType {
        static let lend = "Lent"
        static let borrow = "Borrowed"
        static let lendSettle = "Settle lent"
        static let borrowSettle = "Settle borrowed"
    }

    enum Subscription {
        static let repeats = "Repeats"
        static let everyDay = "Every day"
        static let everyWeek = "Every week"
        static let everyMonth = "Every month"
        static let everyYear = "Every year"
        static let everyNDays = "Every N days"

        static func next(_ date: String) -> String {
            "Next: \(date)"
        }
    }

    enum Insights {
        static let yearHeatmap = "Spending this year"
        static let breakdownPie = "Breakdown"
        static let comingSoon = "Coming soon"
    }

    enum Accounts {
        static let balance = "Balance"
        static let toReceive = "To receive"
        static let toRepay = "To repay"
        static let newAccount = "New account"
        static let cannotDeleteLast = "Cannot delete the last account"
    }

    enum Settings {
        static let email = "Email"
        static let tags = "Tags"
        static let incomeSources = "Income sources"
        static let deleteAccount = "Delete account"
        static let deleteAccountBody = "This permanently deletes your Ledger account, entries, and files."
    }

    enum AuthErrors {
        static let invalidEmail = "Enter a valid email."
        static let shortPassword = "Use at least 8 characters."
        static let confirmEmail = "Check your email to confirm your account."
        static let badCredentials = "Email or password is incorrect."
    }
}
