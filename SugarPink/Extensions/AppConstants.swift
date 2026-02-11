import Foundation

enum AppConstants {
    enum Links {
        static let termsOfUse = "https://docs.google.com/document/d/e/2PACX-1vSDgypHZOjleacCQzDYkk1ab_4RKoPTu5ywjCD1VqOw6kFVviOLf2XoXaP7QygG0B7FSqaswxBuU0YZ/pub"
        static let privacyPolicy = "https://docs.google.com/document/d/e/2PACX-1vSDgypHZOjleacCQzDYkk1ab_4RKoPTu5ywjCD1VqOw6kFVviOLf2XoXaP7QygG0B7FSqaswxBuU0YZ/pub"
        static let medSources = "https://pmc.ncbi.nlm.nih.gov/articles/PMC7057022/"
        static let appStoreURL = "https://apps.apple.com/app/id6759051452"
    }
    
    enum Subscription {
        static let weeklyID = "weeklyglucosepremium"
        static let monthlyID = "monthlyglucosepremium"
        static let yearlyID = "yearlyglucosepremium"
        
        static let allIDs: [String] = [
            weeklyID,
            monthlyID,
            yearlyID
        ]
    }
}

