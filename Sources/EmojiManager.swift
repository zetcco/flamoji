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
    
    // Base database
    private let baseEmojis: [EmojiDef] = [
        // Faces & Emotion
        EmojiDef(symbol: "😀", tags: ["smile", "happy", "face", "grin"]),
        EmojiDef(symbol: "😂", tags: ["laugh", "cry", "tears", "joy", "haha", "lmao"]),
        EmojiDef(symbol: "🥲", tags: ["smile", "cry", "tear", "happy", "relieved", "pain", "sad"]),
        EmojiDef(symbol: "😎", tags: ["cool", "glasses", "sunglasses", "smile", "boss"]),
        EmojiDef(symbol: "🤔", tags: ["think", "hmm", "ponder", "wonder", "face"]),
        EmojiDef(symbol: "😭", tags: ["cry", "sob", "sad", "tears", "bawl"]),
        EmojiDef(symbol: "💀", tags: ["skull", "dead", "death", "skeleton", "deadass"]),
        EmojiDef(symbol: "👀", tags: ["eyes", "look", "see", "watch", "stare", "peep"]),
        EmojiDef(symbol: "🥰", tags: ["love", "hearts", "affection", "cute", "adore"]),
        EmojiDef(symbol: "🤷‍♂️", tags: ["shrug", "idk", "confused", "dunno", "man"]),
        EmojiDef(symbol: "🤦‍♂️", tags: ["facepalm", "disappointed", "sigh", "stupid"]),
        
        // Gestures
        EmojiDef(symbol: "👍", tags: ["thumbs", "up", "yes", "approve", "good", "ok"]),
        EmojiDef(symbol: "👎", tags: ["thumbs", "down", "no", "bad", "disapprove"]),
        EmojiDef(symbol: "🙌", tags: ["hands", "raise", "celebrate", "praise", "yay"]),
        EmojiDef(symbol: "🙏", tags: ["pray", "please", "thanks", "ask", "hands"]),
        EmojiDef(symbol: "🤝", tags: ["handshake", "deal", "agree", "meet"]),
        
        // Symbols & Objects
        EmojiDef(symbol: "🔥", tags: ["fire", "hot", "flame", "lit", "red"]),
        EmojiDef(symbol: "✨", tags: ["sparkles", "stars", "magic", "shiny", "clean"]),
        EmojiDef(symbol: "💯", tags: ["100", "hundred", "perfect", "score", "keep"]),
        EmojiDef(symbol: "🛑", tags: ["stop", "red", "sign", "halt", "error"]),
        EmojiDef(symbol: "✅", tags: ["check", "mark", "green", "yes", "done", "success"]),
        EmojiDef(symbol: "❌", tags: ["cross", "x", "red", "no", "cancel", "wrong"]),
        EmojiDef(symbol: "❤️", tags: ["heart", "red", "love", "like"]),
        
        // Tech & Work
        EmojiDef(symbol: "💻", tags: ["computer", "mac", "laptop", "pc", "work", "code"]),
        EmojiDef(symbol: "📱", tags: ["phone", "mobile", "iphone", "call", "app"]),
        EmojiDef(symbol: "🚀", tags: ["rocket", "launch", "space", "ship", "fast", "shipit"]),
        EmojiDef(symbol: "🐛", tags: ["bug", "insect", "error", "fix", "code"]),
        EmojiDef(symbol: "🔨", tags: ["hammer", "build", "tool", "work", "fix"]),
        EmojiDef(symbol: "🎨", tags: ["art", "palette", "design", "colors", "draw"]),
        
        // Food & Nature
        EmojiDef(symbol: "🍎", tags: ["apple", "red", "fruit", "food", "mac"]),
        EmojiDef(symbol: "🍕", tags: ["pizza", "food", "slice", "cheese"]),
        EmojiDef(symbol: "☕️", tags: ["coffee", "cup", "drink", "cafe", "tea", "morning"]),
        EmojiDef(symbol: "🌍", tags: ["earth", "world", "globe", "planet", "global"])
    ]
    
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
