import Foundation

/// Parses Bing image captions, which arrive as `"Description text (© Credit)"`.
enum Caption {
    /// Splits a caption into its descriptive text and trailing parenthetical
    /// credit. Uses the last `(` so descriptions that themselves contain
    /// parentheses still parse correctly.
    static func split(_ description: String?) -> (text: String, copyright: String) {
        guard let description, let openIndex = description.lastIndex(of: "(") else {
            return (description ?? "", "")
        }
        let text = description[..<openIndex].trimmingCharacters(in: .whitespaces)
        var copyright = String(description[description.index(after: openIndex)...])
        if copyright.hasSuffix(")") { copyright.removeLast() }
        return (text, copyright)
    }
}
