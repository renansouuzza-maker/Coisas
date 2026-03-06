import SwiftUI

struct ViralContentCard: View {
    let content: ViralContent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail
            ZStack(alignment: .topLeading) {
                AsyncImage(url: URL(string: content.thumbnailURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                    case .failure:
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .aspectRatio(16/9, contentMode: .fill)
                            .overlay(
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.white.opacity(0.8))
                            )
                    default:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .aspectRatio(16/9, contentMode: .fill)
                            .overlay(ProgressView())
                    }
                }
                .clipped()

                // Platform badge
                HStack(spacing: 6) {
                    Image(systemName: content.platform.icon)
                        .font(.caption2.bold())
                    Text(content.platform.rawValue)
                        .font(.caption2.bold())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(10)

                // Trend score
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(Int(content.trendScore))")
                                .fontWeight(.black)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(10)
                    }
                    Spacer()
                }
            }

            // Content info
            VStack(alignment: .leading, spacing: 8) {
                Text(content.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text(content.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Author row
                HStack(spacing: 8) {
                    AsyncImage(url: URL(string: content.author.avatarURL)) { image in
                        image.resizable()
                    } placeholder: {
                        Circle().fill(Color(.systemGray4))
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())

                    Text(content.author.displayName)
                        .font(.caption)
                        .fontWeight(.medium)

                    if content.author.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }

                    Spacer()

                    // Hook type badge
                    Text(content.hookPunch.hookType.rawValue)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.purple.opacity(0.15))
                        .foregroundStyle(.purple)
                        .clipShape(Capsule())
                }

                // Metrics row
                HStack(spacing: 16) {
                    MetricLabel(icon: "eye.fill", value: content.metrics.formattedViews)
                    MetricLabel(icon: "heart.fill", value: content.metrics.formattedLikes)
                    MetricLabel(icon: "bubble.right.fill", value: content.metrics.formattedComments)
                    MetricLabel(icon: "arrow.turn.up.right", value: content.metrics.formattedShares)
                    Spacer()
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f/h", content.metrics.viralVelocity))
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                // Tags
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(content.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color(.systemGray6))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(14)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

struct MetricLabel: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(value)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}
