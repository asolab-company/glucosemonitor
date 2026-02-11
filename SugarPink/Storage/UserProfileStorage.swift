import Combine
import Foundation
import SwiftUI

final class UserProfileStore: ObservableObject {
    @Published private(set) var profile: UserProfile

    init() {
        self.profile = UserProfileStorage.load()
    }

    func load() {
        profile = UserProfileStorage.load()
    }

    func update(_ newProfile: UserProfile) {
        UserProfileStorage.save(newProfile)
        profile = newProfile
    }
}

struct UserProfile {
    var gender: String?
    var age: Int?
    var unit: String?
    
    static var empty: UserProfile {
        UserProfile(gender: nil, age: nil, unit: nil)
    }
}

enum UserProfileStorage {
    private static let keyGender = "sugarpink.userProfile.gender"
    private static let keyAge = "sugarpink.userProfile.age"
    private static let keyUnit = "sugarpink.userProfile.unit"
    
    static func load() -> UserProfile {
        let ud = UserDefaults.standard
        let age = ud.object(forKey: keyAge) as? Int
        return UserProfile(
            gender: ud.string(forKey: keyGender),
            age: age,
            unit: ud.string(forKey: keyUnit)
        )
    }
    
    static func save(_ profile: UserProfile) {
        let ud = UserDefaults.standard
        if let v = profile.gender { ud.set(v, forKey: keyGender) } else { ud.removeObject(forKey: keyGender) }
        if let v = profile.age { ud.set(v, forKey: keyAge) } else { ud.removeObject(forKey: keyAge) }
        if let v = profile.unit { ud.set(v, forKey: keyUnit) } else { ud.removeObject(forKey: keyUnit) }
    }
}

enum GlucoseDisplay {
    static func value(mgDl: Double, unit: String?) -> Double {
        (unit == "mmol/L") ? (mgDl / 18.0) : mgDl
    }

    static func formatted(mgDl: Double, unit: String?) -> String {
        let u = unit ?? "mg/dL"
        let v = value(mgDl: mgDl, unit: unit)
        let decimals = (u == "mmol/L") ? 1 : 0
        let format = (u == "mmol/L") ? "%.1f" : "%.0f"
        return String(format: "\(format) \(u)", v)
    }

    static func placeholder(unit: String?) -> String {
        let u = unit ?? "mg/dL"
        return "-- \(u)"
    }
}
