import SwiftUI

struct ContentDetailView: View {
    let content: ViralContent
    @State private var selectedTab = 0
    @State private var showCloneSheet = false
    @State private var copiedToClipboard = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero thumbnail
                ZStack(alignment: .bottomLeading) {
                    AsyncImage(url: URL(string: content.thumbnailURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        default:
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .pink, .orange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .aspectRatio(16/9, contentMode: .fill)
                                .overlay(
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.white.opacity(0.7))
                                )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipped()

                    // Gradient overlay
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Info overlay
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Label(content.platform.rawValue, systemImage: content.platform.icon)
                                .font(.caption2.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())

                            Label(content.contentType.rawValue, systemImage: "play.rectangle.fill")
                                .font(.caption2.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                Text("\(Int(content.trendScore))")
                                    .fontWeight(.black)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                        }

                        Text(content.title)
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundStyle(.white)
                    }
                    .padding()
                }

                VStack(spacing: 20) {
                    // Author card
                    HStack(spacing: 12) {
                        AsyncImage(url: URL(string: content.author.avatarURL)) { image in
                            image.resizable()
                        } placeholder: {
                            Circle().fill(Color(.systemGray4))
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                        .overlay(
                            Circle().stroke(
                                LinearGradient(colors: [.purple, .pink], startPoint: .top, endPoint: .bottom),
                                lineWidth: 2
                            )
                        )

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(content.author.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                if content.author.isVerified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                            Text("\(content.author.username) · \(ContentMetrics.formatNumber(content.author.followers)) seguidores")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Engajamento")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f%%", content.author.engagementRate))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 4)

                    // Metrics grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        MetricBox(icon: "eye.fill", label: "Views", value: content.metrics.formattedViews, color: .blue)
                        MetricBox(icon: "heart.fill", label: "Likes", value: content.metrics.formattedLikes, color: .pink)
                        MetricBox(icon: "bubble.right.fill", label: "Comentários", value: content.metrics.formattedComments, color: .green)
                        MetricBox(icon: "arrow.turn.up.right", label: "Shares", value: content.metrics.formattedShares, color: .orange)
                        MetricBox(icon: "bookmark.fill", label: "Saves", value: ContentMetrics.formatNumber(content.metrics.saves), color: .purple)
                        MetricBox(icon: "bolt.fill", label: "Velocidade", value: String(format: "%.1f/h", content.metrics.viralVelocity), color: .yellow)
                    }

                    // Content tabs
                    VStack(spacing: 0) {
                        // Tab selector
                        HStack(spacing: 0) {
                            TabButton(title: "Resumo", icon: "doc.text.fill", isSelected: selectedTab == 0) { selectedTab = 0 }
                            TabButton(title: "Ideia", icon: "lightbulb.fill", isSelected: selectedTab == 1) { selectedTab = 1 }
                            TabButton(title: "Transcrição", icon: "text.quote", isSelected: selectedTab == 2) { selectedTab = 2 }
                            TabButton(title: "Hook", icon: "bolt.fill", isSelected: selectedTab == 3) { selectedTab = 3 }
                        }
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        // Tab content
                        Group {
                            switch selectedTab {
                            case 0: summaryTab
                            case 1: ideaTab
                            case 2: transcriptionTab
                            case 3: hookTab
                            default: EmptyView()
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Tags
                    FlowLayout(spacing: 8) {
                        ForEach(content.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.1))
                                .foregroundStyle(.purple)
                                .clipShape(Capsule())
                        }
                    }

                    // Clone button
                    Button {
                        showCloneSheet = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.on.doc.fill")
                            Text("Clonar com Hook Punch")
                                .fontWeight(.bold)
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .purple.opacity(0.4), radius: 8, y: 4)
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCloneSheet) {
            CloneSheetView(content: content)
        }
    }

    // MARK: - Tab Views

    private var summaryTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Resumo", systemImage: "doc.text.fill")
                .font(.headline)
                .foregroundStyle(.purple)
            Text(content.summary)
                .font(.body)
                .lineSpacing(4)
        }
    }

    private var ideaTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ideia Central", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(.yellow)
            Text(content.idea)
                .font(.body)
                .lineSpacing(4)
        }
    }

    private var transcriptionTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Transcrição", systemImage: "text.quote")
                .font(.headline)
                .foregroundStyle(.blue)
            Text(content.transcription)
                .font(.body)
                .lineSpacing(4)
                .italic()

            Button {
                UIPasteboard.general.string = content.transcription
                copiedToClipboard = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    copiedToClipboard = false
                }
            } label: {
                Label(copiedToClipboard ? "Copiado!" : "Copiar transcrição", systemImage: copiedToClipboard ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
            }
        }
    }

    private var hookTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Hook Punch Analysis", systemImage: "bolt.fill")
                .font(.headline)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 12) {
                HookSection(title: "Hook", text: content.hookPunch.hook, color: .red)
                HookSection(title: "Punch Line", text: content.hookPunch.punchLine, color: .orange)
                HookSection(title: "CTA", text: content.hookPunch.callToAction, color: .green)
                HookSection(title: "Gatilho Emocional", text: content.hookPunch.emotionalTrigger, color: .purple)

                HStack {
                    Text("Tipo:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(content.hookPunch.hookType.rawValue)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct MetricBox: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 3)
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.purple : .clear)
            .foregroundStyle(isSelected ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct HookSection: View {
    let title: String
    let text: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(text)
                .font(.subheadline)
                .lineSpacing(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layoutSubviews(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            guard index < result.positions.count else { break }
            subview.place(at: CGPoint(
                x: bounds.minX + result.positions[index].x,
                y: bounds.minY + result.positions[index].y
            ), proposal: .unspecified)
        }
    }

    private func layoutSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}
