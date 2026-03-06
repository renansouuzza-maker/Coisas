import SwiftUI

struct FeedView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var showSearch = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Live indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                            .overlay(
                                Circle()
                                    .fill(.green.opacity(0.4))
                                    .frame(width: 16, height: 16)
                            )
                        Text("Atualizando em tempo real")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("Atualizado: \(viewModel.timeSinceUpdate)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // Platform filter
                    PlatformFilterBar(selected: $viewModel.selectedPlatform)
                        .onChange(of: viewModel.selectedPlatform) { _, newValue in
                            viewModel.selectPlatform(newValue)
                        }

                    // Trending profiles horizontal scroll
                    if !viewModel.trendingProfiles.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.yellow)
                                Text("Perfis em Alta")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Spacer()
                                NavigationLink {
                                    ProfilesListView(profiles: viewModel.trendingProfiles)
                                } label: {
                                    Text("Ver todos")
                                        .font(.caption)
                                        .foregroundStyle(.purple)
                                }
                            }
                            .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 12) {
                                    ForEach(viewModel.trendingProfiles.prefix(10)) { profile in
                                        ProfileCard(profile: profile)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    // Content feed
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("Viralizando Agora")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Spacer()
                            Text("\(viewModel.filteredContent.count) conteúdos")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)

                        if viewModel.isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Escaneando a internet...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        } else {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.filteredContent) { content in
                                    NavigationLink(value: content) {
                                        ViralContentCard(content: content)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Punk.io")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Image(systemName: "bolt.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSearch.toggle()
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.loadContent() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .searchable(text: $viewModel.searchQuery, isPresented: $showSearch, prompt: "Buscar conteúdos, creators, tags...")
            .onSubmit(of: .search) {
                Task { await viewModel.search() }
            }
            .onChange(of: viewModel.searchQuery) { _, newValue in
                if newValue.isEmpty {
                    viewModel.selectPlatform(viewModel.selectedPlatform)
                }
            }
            .navigationDestination(for: ViralContent.self) { content in
                ContentDetailView(content: content)
            }
            .refreshable {
                await viewModel.loadContent()
            }
            .task {
                viewModel.startAutoRefresh()
            }
            .onDisappear {
                viewModel.stopAutoRefresh()
            }
        }
    }
}
