import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    let onDismiss: () -> Void

    @State private var launchAtLogin = LoginItemManager.shared.isEnabled

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 12) {
                    shortcutCard
                    themeCard
                    launchAtLoginCard
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            Spacer(minLength: 0)
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "chevron.left")
                    .font(Typography.actionIcon)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityLabel("Back to todos")

            Spacer()
            Text("Settings").font(Typography.bodyMedium)
            Spacer()

            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }

    // MARK: Shortcut Card

    private var shortcutCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Shortcut")
                .font(Typography.bodyMedium)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            shortcutRow(label: "New line", keys: [.shift, .enter])

            shortcutRow(label: "Create", keys: [.enter])

            shortcutRow(label: "Quit app", keys: [.command, .q])
        }
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.8)
        }
    }

    private enum ShortcutKey {
        case shift, enter, command, q

        var symbol: String {
            switch self {
            case .shift:   return "shift"
            case .enter:   return "return"
            case .command: return "command"
            case .q:       return "Q"
            }
        }

        var isSymbol: Bool {
            switch self {
            case .shift, .enter, .command: return true
            case .q: return false
            }
        }
    }

    private func shortcutRow(label: String, keys: [ShortcutKey]) -> some View {
        HStack {
            Text(label)
                .font(Typography.body)
            Spacer()
            HStack(spacing: 4) {
                ForEach(keys.indices, id: \.self) { i in
                    keyBadge(keys[i])
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func keyBadge(_ key: ShortcutKey) -> some View {
        Group {
            if key.isSymbol {
                Image(systemName: key.symbol)
                    .font(.system(size: 11, weight: .medium))
            } else {
                Text(key.symbol)
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .foregroundStyle(.secondary)
        .frame(width: 28, height: 22)
        .background {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.8)
        }
    }

    // MARK: Theme Card

    private var themeCard: some View {
        let bound = Bindable(settings)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Theme")
                .font(Typography.bodyMedium)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            Picker("Theme", selection: bound.theme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.label).tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.8)
        }
    }

    // MARK: Launch at Login Card

    private var launchAtLoginCard: some View {
        HStack {
            Text("Launch at Login")
                .font(Typography.body)
            Spacer()
            Toggle("", isOn: $launchAtLogin)
                .toggleStyle(.switch)
                .labelsHidden()
                .scaleEffect(0.7, anchor: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.8)
        }
        .onChange(of: launchAtLogin) { _, newValue in
            LoginItemManager.shared.setEnabled(newValue)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Text("Pick your ten, done and dusted")
                .font(Typography.secondary)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Just 10")
                .font(Typography.bodyMedium)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
