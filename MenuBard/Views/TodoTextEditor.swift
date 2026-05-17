import AppKit
import SwiftUI

struct TodoTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool

    var placeholder: String? = nil
    var isEditable: Bool = true
    var isCompleted: Bool = false
    var verticalTextInset: CGFloat = 0
    var onCommit: () -> Void = {}
    var onCancel: () -> Void = {}
    var onBlur: () -> Void = {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> KeyHandlingTextView {
        let textView = KeyHandlingTextView()
        textView.delegate = context.coordinator
        textView.placeholder = placeholder
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = isEditable
        textView.isSelectable = isEditable
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false
        textView.setContentHuggingPriority(.required, for: .vertical)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        textView.verticalTextInset = verticalTextInset
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.configureText(
            text,
            isCompleted: isCompleted,
            isEditable: isEditable
        )
        textView.onCommit = context.coordinator.commit
        textView.onCancel = context.coordinator.cancel
        return textView
    }

    func updateNSView(_ textView: KeyHandlingTextView, context: Context) {
        context.coordinator.parent = self
        textView.placeholder = placeholder
        textView.isEditable = isEditable
        textView.isSelectable = isEditable
        textView.isVerticallyResizable = false
        textView.onCommit = context.coordinator.commit
        textView.onCancel = context.coordinator.cancel
        textView.verticalTextInset = verticalTextInset

        if textView.string != text {
            textView.configureText(
                text,
                isCompleted: isCompleted,
                isEditable: isEditable
            )
        } else {
            textView.configureTextAttributes(
                isCompleted: isCompleted,
                isEditable: isEditable
            )
        }
        textView.needsDisplay = true

        DispatchQueue.main.async {
            guard isEditable else { return }
            if isFocused, textView.window?.firstResponder !== textView {
                textView.window?.makeFirstResponder(textView)
            } else if !isFocused, textView.window?.firstResponder === textView {
                textView.window?.makeFirstResponder(nil)
            }
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TodoTextEditor

        init(_ parent: TodoTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textDidBeginEditing(_ notification: Notification) {
            parent.isFocused = true
        }

        func textDidEndEditing(_ notification: Notification) {
            parent.isFocused = false
            parent.onBlur()
        }

        func commit() {
            parent.onCommit()
        }

        func cancel() {
            parent.onCancel()
        }
    }
}

final class KeyHandlingTextView: NSTextView {
    private enum Metrics {
        static let font = NSFont.systemFont(ofSize: 14)
        static let lineSpacing: CGFloat = 3
        static let minHeight: CGFloat = 18
    }

    var placeholder: String?
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?
    var verticalTextInset: CGFloat = 0 {
        didSet {
            textContainerInset = NSSize(width: 0, height: verticalTextInset)
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }

    override var intrinsicContentSize: NSSize {
        guard let textContainer, let layoutManager, bounds.width > 0 else {
            return NSSize(width: NSView.noIntrinsicMetric, height: Metrics.minHeight + verticalTextInset * 2)
        }

        textContainer.containerSize = NSSize(
            width: bounds.width,
            height: .greatestFiniteMagnitude
        )
        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer)
        // Subtract trailing line spacing so reported height matches visible text,
        // allowing SwiftUI's HStack(.center) to align the checkbox correctly.
        let height = ceil(used.height - Metrics.lineSpacing + verticalTextInset * 2)
        return NSSize(
            width: NSView.noIntrinsicMetric,
            height: max(Metrics.minHeight + verticalTextInset * 2, height)
        )
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        textContainer?.containerSize = NSSize(
            width: newSize.width,
            height: .greatestFiniteMagnitude
        )
        invalidateIntrinsicContentSize()
    }

    override func keyDown(with event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        switch event.keyCode {
        case 36, 76:
            if modifiers.contains(.shift) || modifiers.contains(.option) {
                insertNewline(nil)
            } else {
                onCommit?()
            }
        case 53:
            onCancel?()
        default:
            super.keyDown(with: event)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard string.isEmpty, let placeholder else { return }

        placeholder.draw(
            at: NSPoint(x: 0, y: verticalTextInset),
            withAttributes: textAttributes(
                color: .secondaryLabelColor,
                isCompleted: false
            )
        )
    }

    func configureText(_ newText: String, isCompleted: Bool, isEditable: Bool) {
        configureTextAttributes(isCompleted: isCompleted, isEditable: isEditable)

        if isCompleted || !isEditable {
            textStorage?.setAttributedString(
                NSAttributedString(
                    string: newText,
                    attributes: textAttributes(
                        color: isCompleted ? .secondaryLabelColor : .labelColor,
                        isCompleted: isCompleted
                    )
                )
            )
        } else {
            string = newText
        }

        invalidateIntrinsicContentSize()
    }

    func configureTextAttributes(isCompleted: Bool, isEditable: Bool) {
        font = Metrics.font
        textColor = isCompleted ? .secondaryLabelColor : .labelColor
        insertionPointColor = .controlAccentColor
        typingAttributes = textAttributes(
            color: isCompleted ? .secondaryLabelColor : .labelColor,
            isCompleted: isCompleted
        )
        alphaValue = 1
    }

    private func textAttributes(color: NSColor, isCompleted: Bool) -> [NSAttributedString.Key: Any] {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = Metrics.lineSpacing

        var attributes: [NSAttributedString.Key: Any] = [
            .font: Metrics.font,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]

        if isCompleted {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            attributes[.strikethroughColor] = NSColor.secondaryLabelColor
        }

        return attributes
    }
}
