import SwiftUI

enum DeviceSize {
    static var isSmall: Bool {
        let h = UIScreen.main.bounds.height
        return h <= 736
    }
}
