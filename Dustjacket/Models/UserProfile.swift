import Foundation

struct UserProfile: Codable, Sendable {
    let id: Int
    let username: String
    let bio: String?
    let avatarURL: String?
    let booksCount: Int
    let followersCount: Int
    let followingCount: Int
    let createdAt: String?
}

extension UserProfile {
    init(from user: HardcoverUser) {
        self.id = user.id
        self.username = user.username
        self.bio = user.bio
        self.avatarURL = user.cached_image?.url
        self.booksCount = user.books_count ?? 0
        self.followersCount = user.followers_count ?? 0
        self.followingCount = user.followed_users_count ?? 0
        self.createdAt = user.created_at
    }

    var hardcoverURL: URL? {
        URL(string: "https://hardcover.app/@\(username)")
    }
}
