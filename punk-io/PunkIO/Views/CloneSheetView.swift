import SwiftUI

struct CloneSheetView: View {
    let content: ViralContent
    @Environment(\.dismiss) private var dismiss
    @State private var customHook: String = ""
    @State private var selectedHookType: HookType
    @State private var customNiche: String = ""
    @State private var copied = false
    @State private var generatedClone: String = ""

    init(content: ViralContent) {
        self.content = content
        _selectedHookType = State(initialValue: content.hookPunch.hookType)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .pink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Text("Clonar com Hook Punch")
                            .font(.title2)
                            .fontWeight(.black)

                        Text("Adapte esse conteúdo viral para o seu nicho")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top)

                    // Original hook
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Hook Original", systemImage: "text.quote")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)

                        Text(content.hookPunch.hook)
                            .font(.subheadline)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Hook type selector
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Tipo de Hook", systemImage: "bolt.fill")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(HookType.allCases, id: \.self) { type in
                                    Button {
                                        withAnimation { selectedHookType = type }
                                    } label: {
                                        Text(type.rawValue)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(selectedHookType == type ? Color.purple : Color(.systemGray6))
                                            .foregroundStyle(selectedHookType == type ? .white : .primary)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }

                    // Custom niche
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Seu Nicho", systemImage: "target")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)

                        TextField("Ex: fitness, finanças, tech...", text: $customNiche)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Custom hook override
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Personalizar Hook (opcional)", systemImage: "pencil")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)

                        TextEditor(text: $customHook)
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Generate button
                    Button {
                        generateClone()
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Gerar Clone")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Generated result
                    if !generatedClone.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("Seu Conteúdo Clonado", systemImage: "checkmark.circle.fill")
                                    .font(.headline)
                                    .foregroundStyle(.green)
                                Spacer()
                            }

                            Text(generatedClone)
                                .font(.body)
                                .lineSpacing(6)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.green.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            // Actions
                            HStack(spacing: 12) {
                                Button {
                                    UIPasteboard.general.string = generatedClone
                                    copied = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                                } label: {
                                    HStack {
                                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                        Text(copied ? "Copiado!" : "Copiar")
                                    }
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }

                                ShareLink(item: generatedClone) {
                                    HStack {
                                        Image(systemName: "square.and.arrow.up")
                                        Text("Compartilhar")
                                    }
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding()
            }
            .navigationTitle("Clone Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }

    private func generateClone() {
        let niche = customNiche.isEmpty ? "seu nicho" : customNiche
        let hook = customHook.isEmpty ? content.hookPunch.hook : customHook

        withAnimation(.spring(response: 0.4)) {
            generatedClone = """
            🎯 HOOK (\(selectedHookType.rawValue)):
            \(adaptHook(hook, to: niche))

            📝 ROTEIRO:
            \(content.hookPunch.cloneTemplate.replacingOccurrences(of: "Adapte a ideia central para seu nicho", with: "Aplique para \(niche)"))

            💡 IDEIA ADAPTADA:
            \(content.idea)

            ⚡ PUNCH LINE:
            \(content.hookPunch.punchLine)

            📣 CTA:
            \(content.hookPunch.callToAction)

            #\(niche.replacingOccurrences(of: " ", with: "")) #viral #punkio
            """
        }
    }

    private func adaptHook(_ hook: String, to niche: String) -> String {
        // Simple adaptation - in production, use AI to properly adapt
        return "[\(niche.uppercased())] \(hook)"
    }
}
