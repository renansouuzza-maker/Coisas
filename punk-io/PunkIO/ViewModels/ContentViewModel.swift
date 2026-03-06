import Foundation
import SwiftUI

@MainActor
class ContentViewModel: ObservableObject {
    @Published var trendingContent: [ViralContent] = []
    @Published var filteredContent: [ViralContent] = []
    @Published var trendingProfiles: [CreatorProfile] = []
    @Published var selectedPlatform: PlatformSource?
    @Published var searchQuery: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdated: Date?

    private let service = ViralContentService.shared
    private var autoRefreshTask: Task<Void, Never>?

    // MARK: - Lifecycle

    func startAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = Task {
            while !Task.isCancelled {
                await loadContent()
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60s
            }
        }
    }

    func stopAutoRefresh() {
        autoRefreshTask?.cancel()
        autoRefreshTask = nil
    }

    // MARK: - Data Loading

    func loadContent() async {
        isLoading = trendingContent.isEmpty
        errorMessage = nil

        do {
            async let contentTask = service.fetchTrendingContent(platform: selectedPlatform)
            async let profilesTask = service.fetchTrendingProfiles()

            let (content, profiles) = try await (contentTask, profilesTask)

            withAnimation(.easeInOut(duration: 0.3)) {
                trendingContent = content
                trendingProfiles = profiles
                lastUpdated = Date()
                applyFilters()
            }
        } catch {
            errorMessage = "Erro ao carregar conteúdo: \(error.localizedDescription)"
        }

        isLoading = false
    }

    func search() async {
        guard !searchQuery.isEmpty else {
            applyFilters()
            return
        }

        isLoading = true
        do {
            let results = try await service.searchContent(query: searchQuery)
            withAnimation {
                filteredContent = results
            }
        } catch {
            errorMessage = "Erro na busca: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func selectPlatform(_ platform: PlatformSource?) {
        selectedPlatform = platform
        applyFilters()
    }

    // MARK: - Helpers

    private func applyFilters() {
        var result = trendingContent

        if let platform = selectedPlatform {
            result = result.filter { $0.platform == platform }
        }

        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(q) ||
                $0.tags.contains(where: { $0.lowercased().contains(q) })
            }
        }

        filteredContent = result
    }

    var timeSinceUpdate: String {
        guard let last = lastUpdated else { return "Nunca" }
        let interval = Date().timeIntervalSince(last)
        if interval < 60 { return "Agora" }
        if interval < 3600 { return "Há \(Int(interval / 60))min" }
        return "Há \(Int(interval / 3600))h"
    }
}
