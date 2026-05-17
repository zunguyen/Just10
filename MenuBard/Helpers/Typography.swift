import SwiftUI

/// Typography constants that match Requirements §7.1: body 14pt, secondary 13pt.
/// `.callout` (12pt) and `.caption` (10pt) are below the 13pt floor and must not
/// be used for any user-facing text. Decorative icons can use any size.
enum Typography {
    /// 16pt title text — main popover title.
    static let title = Font.system(size: 16, weight: .semibold)
    /// 14pt body text — todo titles, settings labels, primary buttons.
    static let body = Font.system(size: 14, weight: .regular)
    /// Extra spacing between wrapped body lines.
    static let bodyLineSpacing: CGFloat = 3
    /// 14pt medium body — header labels.
    static let bodyMedium = Font.system(size: 14, weight: .medium)
    /// 13pt secondary text — counters, footer labels, hints.
    static let secondary = Font.system(size: 13, weight: .regular)
    /// 13pt medium — section headers like "Completed".
    static let secondaryMedium = Font.system(size: 13, weight: .medium)

    /// Icon sizing tokens keep symbol scale consistent with nearby text.
    static let titleIcon = Font.system(size: 16, weight: .semibold)
    static let bodyIcon = Font.system(size: 14, weight: .regular)
    static let actionIcon = Font.system(size: 14, weight: .semibold)
    static let checkmarkIcon = Font.system(size: 12, weight: .bold)
}
