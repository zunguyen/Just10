import SwiftUI

struct SettingsView: View {
    @Environment(TodoStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onDismiss: () -> Void

    @State private var launchAtLogin = LoginItemManager.shared.isEnabled
    @State private var isConfirmingClear = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            launchAtLoginRow
            Divider().opacity(0.5)
            themeRow
            Divider().opacity(0.5)
            clearAllRow
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

    private var clearAllRow: some View {
        HStack {
            Text("Clear all todos").font(Typography.body)
            Spacer()
            clearControl
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var clearControl: some View {
        if isConfirmingClear {
            HStack(spacing: 12) {
                Button("Confirm") {
                    store.clearAll()
                    isConfirmingClear = false
                    onDismiss()
                }
                .font(Typography.body)
                .foregroundStyle(.red)
                .buttonStyle(.plain)
                .accessibilityLabel("Confirm clear all todos")

                Button("Cancel") { isConfirmingClear = false }
                    .font(Typography.body)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
        } else {
            Button("Clear") {
                if reduceMotion {
                    isConfirmingClear = true
                } else {
                    withAnimation(.easeInOut(duration: 0.15)) { isConfirmingClear = true }
                }
            }
            .font(Typography.body)
            .foregroundStyle(.red)
            .buttonStyle(.plain)
            .accessibilityLabel("Clear all todos")
        }
    }
}
