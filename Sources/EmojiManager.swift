import Foundation

struct EmojiDef: Hashable {
    let symbol: String
    let tags: [String]
    
    func matches(query: String) -> Bool {
        if query.isEmpty { return true }
        let lowerQuery = query.lowercased()
        let queryWords = lowerQuery.split(separator: " ").map(String.init)
        
        // All typed words must match at least one tag
        return queryWords.allSatisfy { word in
            tags.contains { $0.localizedCaseInsensitiveContains(word) }
        }
    }
}

struct EmojiManager {
    static let shared = EmojiManager()
    
    let baseEmojis: [EmojiDef]
    
    init() {
        // Load the massive emoji dictionary from our bundled JSON file
        guard let url = Bundle.module.url(forResource: "emojis", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              // The JSON is formatted as a dictionary: {"😀": ["face", "grin", "happy"], ...}
              let dict = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            print("⚠️ Failed to load emojis.json! Make sure it's in the Sources folder and Package.swift is updated.")
            self.baseEmojis = []
            return
        }
        
        // Convert the JSON dictionary into our workable structs
        self.baseEmojis = dict.map { EmojiDef(symbol: $0.key, tags: $0.value) }
    }
    
    // Fetches the persistent usage dictionary from disk
    private var usageStats: [String: Int] {
        UserDefaults.standard.dictionary(forKey: "flamojiUsage") as? [String: Int] ?? [:]
    }
    
    // Increments the count for a specific emoji and saves it to disk
    func recordUsage(symbol: String) {
        var stats = usageStats
        stats[symbol, default: 0] += 1
        UserDefaults.standard.set(stats, forKey: "flamojiUsage")
    }
    
    // Returns the base array, sorted dynamically by usage stats
    var allEmojis: [EmojiDef] {
        let stats = usageStats
        return baseEmojis.sorted { a, b in
            let countA = stats[a.symbol] ?? 0
            let countB = stats[b.symbol] ?? 0
            return countA > countB
        }
    }
    
    func search(query: String) -> [EmojiDef] {
        let sorted = allEmojis
        if query.isEmpty { return sorted }
        return sorted.filter { $0.matches(query: query) }
    }
}
