import SwiftUI

struct ContentView: View {
    @State private var showSettings = false

    var body: some View {
        Group {
            if showSettings {
                SettingsView(onDismiss: { showSettings = false })
            } else {
                TodoListView(onSettings: { showSettings = true })
            }
        }
        .frame(width: 320, height: 460)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
