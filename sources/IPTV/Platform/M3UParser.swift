import Foundation

struct M3UEntry: Identifiable, Sendable {
    let id = UUID()
    var name: String
    var url: String
    var logoUrl: String
    var category: String
    var kind: String
}

enum M3UParser {
    static func parse(content: String) -> [M3UEntry] {
        var entries: [M3UEntry] = []
        let lines = content.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }

        var i = 0
        while i < lines.count {
            let line = lines[i]
            if line.hasPrefix("#EXTINF:") {
                var name = attr("tvg-name", in: line) ?? ""
                let logo = attr("tvg-logo", in: line) ?? ""
                let group = attr("group-title", in: line) ?? ""

                if name.isEmpty, let comma = line.lastIndex(of: ",") {
                    name = String(line[line.index(after: comma)...]).trimmingCharacters(in: .whitespaces)
                }

                var j = i + 1
                while j < lines.count && (lines[j].isEmpty || lines[j].hasPrefix("#")) { j += 1 }

                if j < lines.count, !lines[j].isEmpty {
                    let urlStr = lines[j]
                    entries.append(M3UEntry(
                        name: name.isEmpty ? "Channel \(entries.count + 1)" : name,
                        url: urlStr,
                        logoUrl: logo,
                        category: group,
                        kind: inferKind(from: urlStr)
                    ))
                    i = j + 1
                    continue
                }
            }
            i += 1
        }
        return entries
    }

    private static func attr(_ key: String, in line: String) -> String? {
        let pattern = "\(key)=\"([^\"]*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else { return nil }
        let value = String(line[range])
        return value.isEmpty ? nil : value
    }

    private static func inferKind(from url: String) -> String {
        let lower = url.lowercased()
        if lower.contains("/movie/") || lower.hasSuffix(".mp4") || lower.hasSuffix(".mkv") || lower.hasSuffix(".avi") { return "vod" }
        if lower.contains("/series/") { return "series" }
        return "live"
    }
}
