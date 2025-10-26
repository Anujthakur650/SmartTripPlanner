import Foundation

extension String {
    func sanitized() -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let transformed = unicodeScalars.map { scalar -> Character in
            if allowed.contains(scalar) {
                return Character(scalar)
            }
            return "-"
        }
        let interim = String(transformed)
        let collapsed = interim.replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: "-_").union(.whitespacesAndNewlines))
        return trimmed.isEmpty ? "export" : trimmed
    }
}
