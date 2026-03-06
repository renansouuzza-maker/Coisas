import SwiftUI

struct DiscoverView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var selectedCategory = "Todos"

    let categories = ["Todos", "IA & Tech", "Marketing", "Design", "Edição", "Growth", "Copy"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Category chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(categories, id: \.self) { category in
                                Button {
                                    withAnimation { selectedCategory = category }
                                } label: {
                                    Text(category)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedCategory == category ? Color.purple : Color(.systemGray6))
                                        .foregroundStyle(selectedCategory == category ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Top hooks section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "bolt.fill")
                                .foregroundStyle(.orange)
                            Text("Top Hooks do Dia")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal)

                        ForEach(viewModel.filteredContent.prefix(5)) { content in
                            NavigationLink(value: content) {
                                HookPreviewCard(content: content)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Trending ideas
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.yellow)
                            Text("Ideias para Clonar")
                                .font(.headline)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(viewModel.filteredContent.suffix(6)) { content in
                                NavigationLink(value: content) {
                                    IdeaCard(content: content)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Descobrir")
            .navigationDestination(for: ViralContent.self) { content in
                ContentDetailView(content: content)
            }
            .task {
                await viewModel.loadContent()
            }
        }
    }
}

struct HookPreviewCard: View {
    let content: ViralContent

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(colors: [.purple, .pink], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(content.hookPunch.hookType.rawValue)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15))
                        .foregroundStyle(.purple)
                        .clipShape(Capsule())

                    Image(systemName: content.platform.icon)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(Int(content.trendScore))")
                    }
                    .font(.caption2)
                }

                Text(content.hookPunch.hook)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text("por \(content.author.displayName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
        .padding(.horizontal)
    }
}

struct IdeaCard: View {
    let content: ViralContent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: content.platform.icon)
                .font(.title3)
                .foregroundStyle(.purple)

            Text(content.title)
                .font(.caption)
                .fontWeight(.bold)
                .lineLimit(2)
                .foregroundStyle(.primary)

            Text(content.idea)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            Spacer()

            HStack {
                Text(content.metrics.formattedViews)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.purple)
                Text("views")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
    }
}
