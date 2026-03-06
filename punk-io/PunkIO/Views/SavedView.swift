import SwiftUI

struct SavedView: View {
    @State private var savedItems: [ViralContent] = []
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if savedItems.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)

                        Text("Nenhum conteúdo salvo")
                            .font(.title3)
                            .fontWeight(.bold)

                        Text("Salve conteúdos virais para acessar depois e clonar com Hook Punch")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    List {
                        ForEach(savedItems) { item in
                            NavigationLink(value: item) {
                                SavedItemRow(content: item)
                            }
                        }
                        .onDelete { indexSet in
                            savedItems.remove(atOffsets: indexSet)
                        }
                    }
                    .listStyle(.plain)
                    .searchable(text: $searchText, prompt: "Buscar salvos...")
                }
            }
            .navigationTitle("Salvos")
            .navigationDestination(for: ViralContent.self) { content in
                ContentDetailView(content: content)
            }
        }
    }
}

struct SavedItemRow: View {
    let content: ViralContent

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: content.thumbnailURL)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle().fill(Color(.systemGray5))
            }
            .frame(width: 70, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(content.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: content.platform.icon)
                        .font(.caption2)
                    Text(content.author.displayName)
                        .font(.caption)
                    Text("·")
                    Text(content.hookPunch.hookType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.purple)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
