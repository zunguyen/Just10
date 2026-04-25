import SwiftUI

/// Typography constants that match Requirements §7.1: body 14pt, secondary 13pt.
/// `.callout` (12pt) and `.caption` (10pt) are below the 13pt floor and must not
/// be used for any user-facing text. Decorative icons can use any size.
enum Typography {
    /// 14pt body text — todo titles, settings labels, primary buttons.
    static let body = Font.system(size: 14, weight: .regular)
    /// 14pt medium body — header labels.
    static let bodyMedium = Font.system(size: 14, weight: .medium)
    /// 13pt secondary text — counters, footer labels, hints.
    static let secondary = Font.system(size: 13, weight: .regular)
    /// 13pt medium — section headers like "Completed".
    static let secondaryMedium = Font.system(size: 13, weight: .medium)
}
