import SwiftUI

struct ContentView: View {
    private enum Layout {
        static let appRadius: CGFloat = 12
        static let backgroundColor = Color(red: 0.953, green: 0.953, blue: 0.953)
    }

    @State private var showSettings = false

    var body: some View {
        Group {
            if showSettings {
                SettingsView(onDismiss: { showSettings = false })
            } else {
                TodoListView(onSettings: { showSettings = true })
            }
        }
        .frame(width: 380, height: 500)
        .background(Layout.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: Layout.appRadius, style: .continuous))
    }
}
