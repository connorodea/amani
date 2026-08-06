import SwiftUI

enum OrbState {
    case idle
    case active
}

struct OrbView: View {
    let state: OrbState

    var body: some View {
        Circle()
            .fill(Color.accentColor.opacity(state == .active ? 0.9 : 0.6))
    }
}
