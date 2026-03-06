import SwiftUI

struct ProfilesListView: View {
    let profiles: [CreatorProfile]
    @State private var selectedPlatform: PlatformSource?

    var filteredProfiles: [CreatorProfile] {
        guard let platform = selectedPlatform else { return profiles }
        return profiles.filter { $0.platform == platform }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PlatformFilterBar(selected: $selectedPlatform)

                LazyVStack(spacing: 12) {
                    ForEach(filteredProfiles) { profile in
                        ProfileRowCard(profile: profile)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Perfis em Alta")
    }
}

struct ProfileRowCard: View {
    let profile: CreatorProfile

    var body: some View {
        HStack(spacing: 14) {
            AsyncImage(url: URL(string: profile.avatarURL)) { image in
                image.resizable()
            } placeholder: {
                Circle()
                    .fill(
                        LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(
                    LinearGradient(colors: [.purple, .pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 2.5
                )
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(profile.displayName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    if profile.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }

                Text(profile.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Label(ContentMetrics.formatNumber(profile.followers), systemImage: "person.2.fill")
                    Label(String(format: "%.1f%%", profile.engagementRate), systemImage: "chart.line.uptrend.xyaxis")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Image(systemName: profile.platform.icon)
                    .font(.caption)
                    .foregroundStyle(.purple)

                Text(profile.topNiche)
                    .font(.system(size: 9))
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.1))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}
