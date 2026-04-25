import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    let onDismiss: () -> Void

    @State private var launchAtLogin = LoginItemManager.shared.isEnabled

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            launchAtLoginRow
            Divider().opacity(0.5)
            themeRow
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
    Image(systemName: "chevron.left")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(8) // ← expands the hit area by 8pt on all sides
        .contentShape(Rectangle()) // ← tells SwiftUI the whole padded area is tappable
}
.buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityLabel("Back to todos")

            Spacer()
            Text("Settings").font(Typography.bodyMedium)
            Spacer()

            Color.clear.frame(width: 16, height: 16)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

  private var launchAtLoginRow: some View {
    HStack {
        Text("Launch at Login").font(Typography.body)
        Spacer()
        Toggle("", isOn: $launchAtLogin)
            .toggleStyle(.switch)
            .labelsHidden()
            .scaleEffect(0.7, anchor: .trailing)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .onChange(of: launchAtLogin) { _, newValue in
        LoginItemManager.shared.setEnabled(newValue)
    }
}

    private var themeRow: some View {
        let bound = Bindable(settings)
        return HStack {
            Text("Theme").font(Typography.body)
            Spacer()
            Picker("Theme", selection: bound.theme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.label).tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 160)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

}
