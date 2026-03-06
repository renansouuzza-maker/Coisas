import SwiftUI

struct ProfileCard: View {
    let profile: CreatorProfile

    var body: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: profile.avatarURL)) { image in
                    image.resizable()
                } placeholder: {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(width: 70, height: 70)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.purple, .pink, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.5
                        )
                )

                if profile.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .background(Circle().fill(.white).padding(-2))
                }
            }

            VStack(spacing: 2) {
                Text(profile.displayName)
                    .font(.caption)
                    .fontWeight(.bold)
                    .lineLimit(1)

                Text(profile.username)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 2) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 8))
                Text(ContentMetrics.formatNumber(profile.followers))
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.purple)

            Text(profile.topNiche)
                .font(.system(size: 9))
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.purple.opacity(0.1))
                .clipShape(Capsule())
                .lineLimit(1)
        }
        .frame(width: 110)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
    }
}
