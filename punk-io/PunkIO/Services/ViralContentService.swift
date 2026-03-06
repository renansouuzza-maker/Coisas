import Foundation

// MARK: - Viral Content Service

/// Service responsible for fetching and managing viral content from multiple platforms.
/// In production, connect this to real APIs (TikTok, Instagram Graph API, YouTube Data API, etc.)
/// For now, it uses realistic mock data to demonstrate the full app experience.
actor ViralContentService {
    static let shared = ViralContentService()

    private var cachedContent: [ViralContent] = []
    private var lastFetchDate: Date?
    private let refreshInterval: TimeInterval = 60 // refresh every 60 seconds

    // MARK: - Public API

    func fetchTrendingContent(platform: PlatformSource? = nil, limit: Int = 50) async throws -> [ViralContent] {
        if let cached = lastFetchDate,
           Date().timeIntervalSince(cached) < refreshInterval,
           !cachedContent.isEmpty {
            return filterContent(cachedContent, platform: platform, limit: limit)
        }

        // Simulate network delay
        try await Task.sleep(nanoseconds: 800_000_000)

        let content = generateMockContent()
        cachedContent = content
        lastFetchDate = Date()

        return filterContent(content, platform: platform, limit: limit)
    }

    func fetchContentDetail(id: UUID) async throws -> ViralContent? {
        if cachedContent.isEmpty {
            _ = try await fetchTrendingContent()
        }
        return cachedContent.first { $0.id == id }
    }

    func fetchTrendingProfiles(platform: PlatformSource? = nil) async throws -> [CreatorProfile] {
        let content = try await fetchTrendingContent()
        var seen = Set<UUID>()
        var profiles: [CreatorProfile] = []
        for item in content {
            if !seen.contains(item.author.id) {
                seen.insert(item.author.id)
                profiles.append(item.author)
            }
        }
        if let platform = platform {
            return profiles.filter { $0.platform == platform }
        }
        return profiles
    }

    func searchContent(query: String) async throws -> [ViralContent] {
        let all = try await fetchTrendingContent()
        let q = query.lowercased()
        return all.filter {
            $0.title.lowercased().contains(q) ||
            $0.summary.lowercased().contains(q) ||
            $0.tags.contains(where: { $0.lowercased().contains(q) }) ||
            $0.author.username.lowercased().contains(q)
        }
    }

    // MARK: - Private

    private func filterContent(_ content: [ViralContent], platform: PlatformSource?, limit: Int) -> [ViralContent] {
        var result = content
        if let platform = platform {
            result = result.filter { $0.platform == platform }
        }
        return Array(result.sorted { $0.trendScore > $1.trendScore }.prefix(limit))
    }

    // MARK: - Mock Data Generator

    private func generateMockContent() -> [ViralContent] {
        let creators = generateMockCreators()
        let now = Date()

        let contentData: [(String, String, String, String, PlatformSource, ContentType, HookType, [String])] = [
            (
                "Como eu fiz R$50K em 30 dias com IA",
                "Creator mostra passo a passo como usou ferramentas de IA para automatizar um negócio digital e faturar R$50K no primeiro mês. Ele detalha as ferramentas, o investimento inicial e a estratégia de marketing.",
                "A ideia central é usar IA generativa para criar conteúdo em escala para múltiplas plataformas, monetizando através de afiliados e produtos digitais. O diferencial está na automação completa do funil.",
                "Eu sei que parece mentira, mas nos últimos 30 dias eu faturei mais de 50 mil reais usando apenas inteligência artificial. E não, eu não sou programador. Vou te mostrar exatamente como fiz isso...",
                .tiktok, .video, .promise,
                ["IA", "dinheiro", "negócio digital", "automação"]
            ),
            (
                "O segredo que ninguém te conta sobre o algoritmo",
                "Especialista em growth revela o mecanismo interno do algoritmo do Instagram que determina alcance. Ele explica o conceito de 'velocity score' e como hackear os primeiros 30 minutos de um post.",
                "A ideia é focar nos primeiros 30 minutos após postar: engajamento rápido com saves e shares vale 3x mais que likes. Usar stories para direcionar tráfego ao post novo é o hack principal.",
                "Todo mundo fala sobre o algoritmo, mas ninguém explica ISSO. O Instagram tem um sistema de pontuação nos primeiros 30 minutos do seu post que define se ele vai viralizar ou morrer...",
                .instagram, .reel, .curiosity,
                ["algoritmo", "Instagram", "growth", "hack"]
            ),
            (
                "Pare de fazer Reels assim (está matando seu alcance)",
                "Análise de 500 Reels virais mostra os 3 erros mais comuns que creators cometem. O vídeo mostra antes/depois de perfis que corrigiram esses erros e triplicaram o alcance.",
                "Os 3 erros: 1) Começar com introdução longa (hook fraco), 2) Não usar texto na tela nos 2 primeiros segundos, 3) Não ter CTA no meio do vídeo. A correção desses 3 pontos triplica o alcance.",
                "Se você está fazendo Reels e não passa de 500 views, provavelmente está cometendo pelo menos um desses 3 erros. Eu analisei mais de 500 Reels virais e descobri um padrão...",
                .youtube, .short, .controversy,
                ["Reels", "alcance", "erros", "viral"]
            ),
            (
                "Trend alert: essa transição vai dominar 2026",
                "Nova transição usando efeito de glitch + morph está explodindo no TikTok. Tutorial completo de como replicar usando apenas o CapCut, sem precisar de After Effects.",
                "Transição glitch-morph: gravar 2 clips com posição similar, usar efeito glitch de 0.3s como bridge, aplicar keyframe de escala 100→120→100%. Funciona para qualquer nicho.",
                "Essa transição apareceu há 3 dias e já tem mais de 200 milhões de views combinados. E o melhor: você consegue fazer só com o CapCut. Olha como fica...",
                .tiktok, .video, .tutorial,
                ["transição", "TikTok", "CapCut", "trend"]
            ),
            (
                "Thread: 10 lições de quem saiu de 0 a 100K seguidores",
                "Creator documenta toda a jornada de 0 a 100K seguidores em 6 meses, com prints de analytics, erros cometidos e as 10 lições mais importantes aprendidas no processo.",
                "Crescimento veio de: 1) Postar 3x/dia, 2) Responder TODO comentário na primeira hora, 3) Fazer 5 collabs/mês, 4) Reciclar conteúdo entre plataformas. Consistência > viralidade.",
                "Há 6 meses eu tinha 0 seguidores. Hoje passei de 100K. Essa thread tem TUDO que eu aprendi — inclusive os erros que quase me fizeram desistir. 🧵",
                .twitter, .thread, .story,
                ["crescimento", "seguidores", "estratégia", "jornada"]
            ),
            (
                "POV: você descobre esse hack de edição",
                "Técnica de edição que usa cortes a cada 2 segundos com zoom progressivo para manter retenção acima de 80%. Demonstração prática com métricas reais de antes e depois.",
                "Edição rápida com cortes de 2s + zoom de 5% progressivo a cada corte. Adicionar sound effects nos cortes. Resultado: retenção média sobe de 45% para 82%.",
                "Eu não acreditava que uma mudança tão simples na edição podia fazer TANTA diferença. Olha o antes e depois das minhas métricas de retenção...",
                .tiktok, .video, .shock,
                ["edição", "retenção", "hack", "métricas"]
            ),
            (
                "Carrossel que gerou 50K saves em 24h",
                "Breakdown completo de um carrossel sobre 'ferramentas de IA grátis' que viralizou. Análise do design, copy de cada slide, e a estrutura que pode ser replicada para qualquer nicho.",
                "Estrutura: Slide 1 = Hook visual forte. Slides 2-8 = Uma ferramenta por slide com screenshot. Slide 9 = Resumo. Slide 10 = CTA 'Salva pra não perder'. Design minimalista com alto contraste.",
                "Esse carrossel levou 2 horas pra fazer e gerou mais de 50 mil saves em um dia. Vou te mostrar a estrutura exata que usei — e que você pode copiar pra qualquer nicho.",
                .instagram, .carousel, .promise,
                ["carrossel", "saves", "design", "IA", "ferramentas"]
            ),
            (
                "Você está usando ChatGPT errado (veja como usar certo)",
                "Guia avançado de prompt engineering para criadores de conteúdo. Mostra como usar system prompts, chain of thought e templates para gerar conteúdo 10x melhor.",
                "Framework RICE para prompts: Role (defina o papel), Instructions (seja específico), Context (dê exemplos), Execute (peça output estruturado). Templates prontos para cada tipo de conteúdo.",
                "95% das pessoas usam o ChatGPT assim: 'me dá uma ideia de post'. E aí reclamam que o resultado é genérico. Vou te mostrar como os top creators estão usando de verdade...",
                .youtube, .video, .question,
                ["ChatGPT", "IA", "prompts", "produtividade"]
            ),
            (
                "Desafio: 30 dias postando com essa estratégia",
                "Creator propõe desafio de 30 dias seguindo uma estratégia específica de conteúdo e mostra os resultados de quem já completou. Inclui template de calendário editorial e exemplos.",
                "Estratégia 3-2-1: 3 posts educativos, 2 de entretenimento, 1 pessoal por semana. Cada post segue a fórmula Hook→Valor→CTA. Template de calendário editorial incluído.",
                "Eu desafiei 50 pessoas a postarem por 30 dias seguindo UMA estratégia simples. Os resultados? Assustadores. A média de crescimento foi de 340%. Quer tentar?",
                .threads, .post, .challenge,
                ["desafio", "estratégia", "30 dias", "crescimento"]
            ),
            (
                "A psicologia por trás dos vídeos mais virais",
                "Neurocientista explica os 5 gatilhos psicológicos presentes em todos os vídeos com mais de 10M de views. Análise científica com exemplos práticos de como aplicar cada gatilho.",
                "5 gatilhos: 1) Gap de curiosidade nos 2s iniciais, 2) Pattern interrupt a cada 3-5s, 3) Tensão narrativa crescente, 4) Payoff emocional, 5) Loop aberto no final. Base em neurociência da atenção.",
                "Eu sou neurocientista e analisei os 100 vídeos mais virais do último mês. TODOS tinham esses 5 elementos em comum. E quando você entende a ciência por trás, tudo muda...",
                .youtube, .video, .curiosity,
                ["psicologia", "viral", "neurociência", "gatilhos"]
            ),
        ]

        return contentData.enumerated().map { index, data in
            let creator = creators[index % creators.count]
            let hook = HookPunch(
                hook: String(data.3.prefix(100)),
                punchLine: "E isso muda tudo sobre como você cria conteúdo.",
                callToAction: "Salva esse conteúdo e começa a aplicar hoje!",
                emotionalTrigger: data.6.rawValue,
                hookType: data.6,
                cloneTemplate: """
                [HOOK]: \(String(data.3.prefix(80)))...
                [DESENVOLVIMENTO]: Adapte a ideia central para seu nicho
                [CTA]: \(data.6 == .question ? "Comenta sua opinião" : "Salva pra aplicar depois")
                """
            )

            return ViralContent(
                id: UUID(),
                title: data.0,
                summary: data.1,
                idea: data.2,
                transcription: data.3,
                thumbnailURL: "https://picsum.photos/seed/punk\(index)/800/450",
                originalURL: "https://example.com/viral/\(index)",
                platform: data.4,
                contentType: data.5,
                author: creator,
                hookPunch: hook,
                metrics: ContentMetrics(
                    views: Int.random(in: 100_000...10_000_000),
                    likes: Int.random(in: 10_000...500_000),
                    comments: Int.random(in: 1_000...50_000),
                    shares: Int.random(in: 5_000...200_000),
                    saves: Int.random(in: 2_000...100_000),
                    viralVelocity: Double.random(in: 1.5...25.0)
                ),
                tags: data.7,
                trendScore: Double.random(in: 70...100),
                discoveredAt: now.addingTimeInterval(-Double.random(in: 0...86400)),
                updatedAt: now
            )
        }
    }

    private func generateMockCreators() -> [CreatorProfile] {
        [
            CreatorProfile(id: UUID(), username: "@lucasdigital", displayName: "Lucas Digital", avatarURL: "https://i.pravatar.cc/150?u=lucas", platform: .tiktok, followers: 2_500_000, engagementRate: 8.5, bio: "Transformando ideias em negócios digitais 🚀", isVerified: true, topNiche: "Negócios Digitais"),
            CreatorProfile(id: UUID(), username: "@mariagrowth", displayName: "Maria Growth", avatarURL: "https://i.pravatar.cc/150?u=maria", platform: .instagram, followers: 890_000, engagementRate: 12.3, bio: "Growth hacker | +500 marcas atendidas", isVerified: true, topNiche: "Growth Marketing"),
            CreatorProfile(id: UUID(), username: "@pedrocreator", displayName: "Pedro Creator", avatarURL: "https://i.pravatar.cc/150?u=pedro", platform: .youtube, followers: 1_200_000, engagementRate: 6.7, bio: "Ensino você a criar conteúdo que converte", isVerified: true, topNiche: "Content Creation"),
            CreatorProfile(id: UUID(), username: "@anatrends", displayName: "Ana Trends", avatarURL: "https://i.pravatar.cc/150?u=ana", platform: .tiktok, followers: 3_100_000, engagementRate: 15.2, bio: "Caçadora de trends | Sempre 1 passo à frente", isVerified: true, topNiche: "Trends & Viral"),
            CreatorProfile(id: UUID(), username: "@thiagotech", displayName: "Thiago Tech", avatarURL: "https://i.pravatar.cc/150?u=thiago", platform: .twitter, followers: 450_000, engagementRate: 9.1, bio: "AI + Criatividade = 💰", isVerified: false, topNiche: "Tech & IA"),
            CreatorProfile(id: UUID(), username: "@juliacopy", displayName: "Julia Copywriter", avatarURL: "https://i.pravatar.cc/150?u=julia", platform: .threads, followers: 320_000, engagementRate: 11.8, bio: "Palavras que vendem. Copy que converte.", isVerified: false, topNiche: "Copywriting"),
            CreatorProfile(id: UUID(), username: "@rafadesign", displayName: "Rafa Design", avatarURL: "https://i.pravatar.cc/150?u=rafa", platform: .instagram, followers: 670_000, engagementRate: 7.9, bio: "Design que para o scroll ✋", isVerified: true, topNiche: "Design & Branding"),
            CreatorProfile(id: UUID(), username: "@brunoedits", displayName: "Bruno Edits", avatarURL: "https://i.pravatar.cc/150?u=bruno", platform: .tiktok, followers: 1_800_000, engagementRate: 13.4, bio: "Editor profissional | CapCut master", isVerified: true, topNiche: "Video Editing"),
            CreatorProfile(id: UUID(), username: "@carolneuro", displayName: "Carol Neuro", avatarURL: "https://i.pravatar.cc/150?u=carol", platform: .youtube, followers: 560_000, engagementRate: 10.5, bio: "Neurocientista | Desvendando o cérebro viral", isVerified: true, topNiche: "Neurociência"),
            CreatorProfile(id: UUID(), username: "@danicommerce", displayName: "Dani Commerce", avatarURL: "https://i.pravatar.cc/150?u=dani", platform: .instagram, followers: 410_000, engagementRate: 8.9, bio: "E-commerce de 0 a 1M 📦", isVerified: false, topNiche: "E-commerce"),
        ]
    }
}
