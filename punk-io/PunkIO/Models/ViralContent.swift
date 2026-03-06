import Foundation

// MARK: - Platform Source

enum PlatformSource: String, Codable, CaseIterable, Identifiable {
    case tiktok = "TikTok"
    case instagram = "Instagram"
    case youtube = "YouTube"
    case twitter = "X/Twitter"
    case threads = "Threads"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .tiktok: return "play.rectangle.fill"
        case .instagram: return "camera.fill"
        case .youtube: return "play.tv.fill"
        case .twitter: return "bubble.left.fill"
        case .threads: return "at"
        }
    }

    var color: String {
        switch self {
        case .tiktok: return "tiktokPink"
        case .instagram: return "instaPurple"
        case .youtube: return "youtubeRed"
        case .twitter: return "twitterBlue"
        case .threads: return "threadsBlack"
        }
    }
}

// MARK: - Content Type

enum ContentType: String, Codable, CaseIterable {
    case video = "Video"
    case reel = "Reel"
    case short = "Short"
    case post = "Post"
    case thread = "Thread"
    case carousel = "Carousel"
}

// MARK: - Viral Content

struct ViralContent: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let summary: String
    let idea: String
    let transcription: String
    let thumbnailURL: String
    let originalURL: String
    let platform: PlatformSource
    let contentType: ContentType
    let author: CreatorProfile
    let hookPunch: HookPunch
    let metrics: ContentMetrics
    let tags: [String]
    let trendScore: Double
    let discoveredAt: Date
    let updatedAt: Date

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ViralContent, rhs: ViralContent) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Creator Profile

struct CreatorProfile: Identifiable, Codable, Hashable {
    let id: UUID
    let username: String
    let displayName: String
    let avatarURL: String
    let platform: PlatformSource
    let followers: Int
    let engagementRate: Double
    let bio: String
    let isVerified: Bool
    let topNiche: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CreatorProfile, rhs: CreatorProfile) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Hook Punch

struct HookPunch: Codable, Hashable {
    let hook: String
    let punchLine: String
    let callToAction: String
    let emotionalTrigger: String
    let hookType: HookType
    let cloneTemplate: String
}

enum HookType: String, Codable, CaseIterable {
    case curiosity = "Curiosidade"
    case controversy = "Controvérsia"
    case story = "Storytelling"
    case challenge = "Desafio"
    case tutorial = "Tutorial"
    case shock = "Choque"
    case question = "Pergunta"
    case promise = "Promessa"
}

// MARK: - Content Metrics

struct ContentMetrics: Codable, Hashable {
    let views: Int
    let likes: Int
    let comments: Int
    let shares: Int
    let saves: Int
    let viralVelocity: Double // growth rate per hour

    var engagementRate: Double {
        guard views > 0 else { return 0 }
        return Double(likes + comments + shares + saves) / Double(views) * 100
    }

    var formattedViews: String { Self.formatNumber(views) }
    var formattedLikes: String { Self.formatNumber(likes) }
    var formattedComments: String { Self.formatNumber(comments) }
    var formattedShares: String { Self.formatNumber(shares) }

    static func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000)
        } else if n >= 1_000 {
            return String(format: "%.1fK", Double(n) / 1_000)
        }
        return "\(n)"
    }
}
