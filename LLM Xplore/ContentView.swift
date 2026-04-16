import SwiftUI
import SwiftData
import ExyteChat

struct ContentView: View {
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var chats: [Conversation]
    @Query(sort: \LanguageModel.createdAt) private var models: [LanguageModel]

    @State private var selectedSidebarItem: SidebarItem? = .newChat
    @StateObject private var modelViewModel = ModelViewModel()

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSidebarItem) {
                Section {
                    Label("LLM Xplore", systemImage: "square.and.pencil")
                        .tag(SidebarItem.newChat)

                    Label("Models", systemImage: "cpu")
                        .tag(SidebarItem.models)
                }

                Section("Chats") {
                    if chats.isEmpty {
                        Text("No chats yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(chats) { chat in
                            ChatSidebarRow(chat: chat)
                                .tag(SidebarItem.chat(chat.id))
                        }
                    }
                }
            }
            .navigationTitle("LLM Xplore")
            .listStyle(.sidebar)
        } detail: {
            switch selectedSidebarItem {
            case .newChat:
                ChatContainerView(
                    title: "New Chat",
                    session: nil,
                    languageModel: modelViewModel.defaultModel(in: models)
                )
            case .models:
                ModelLibraryView(models: models, viewModel: modelViewModel)
            case let .chat(chatID):
                if let chat = chats.first(where: { $0.id == chatID }) {
                    ChatContainerView(
                        title: chat.title,
                        session: chat,
                        languageModel: modelViewModel.defaultModel(in: models)
                    )
                } else {
                    ContentUnavailableView("Chat not found", systemImage: "bubble.left.and.bubble.right")
                }
            case .none:
                ContentUnavailableView("Select a conversation", systemImage: "sidebar.left")
            }
        }
        .onAppear {
            modelViewModel.sync(with: models)
        }
        .onChange(of: models) { _, updatedModels in
            modelViewModel.sync(with: updatedModels)
        }
    }
}

private enum SidebarItem: Hashable {
    case newChat
    case models
    case chat(UUID)
}

private struct ChatSidebarRow: View {
    let chat: Conversation

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(chat.title)
                .lineLimit(1)

            if let preview = chat.lastMessagePreview, !preview.isEmpty {
                Text(preview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct ChatContainerView: View {
    @Environment(\.modelContext) private var modelContext

    let title: String
    let languageModel: LanguageModel?

    @StateObject private var viewModel: ChatViewModel

    init(title: String, session: Conversation?, languageModel: LanguageModel?) {
        self.title = title
        self.languageModel = languageModel
        _viewModel = StateObject(
            wrappedValue: ChatViewModel(
                languageModel: languageModel,
                session: session ?? Conversation()
            )
        )
    }

    var body: some View {
        Group {
            if languageModel == nil {
                ContentUnavailableView(
                    "No default model",
                    systemImage: "cpu",
                    description: Text("Add a model and set it as the default before starting a chat.")
                )
            } else {
                ChatView(messages: viewModel.messages) { draft in
                    viewModel.send(draft: draft, in: modelContext)
                }.setAvailableInputs([.text])
            }
        }
        .navigationTitle(viewModel.session.title)
        .onChange(of: languageModel?.id) { _, _ in
            viewModel.updateLanguageModel(languageModel)
        }
    }
}

private struct ModelLibraryView: View {
    let models: [LanguageModel]
    @ObservedObject var viewModel: ModelViewModel

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List(models, selection: $viewModel.selectedModelID) { model in
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(model.name)
                        .lineLimit(1)

                    if viewModel.isDefaultModel(model) {
                        Text("Default")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.thinMaterial, in: Capsule())
                    }
                }

                Text("\(model.modelFamily) • \(model.parameterSummary)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .tag(model.id)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                    viewModel.setDefaultModel(model)
                } label: {
                    Label("Set Default", systemImage: "star")
                }
                .tint(.yellow)

                Button(role: .destructive) {
                    viewModel.delete(model, from: modelContext, existingModels: models)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Models")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Model", systemImage: "plus") {
                    viewModel.isPresentingAddModelSheet = true
                }
            }
        }
        .sheet(isPresented: $viewModel.isPresentingAddModelSheet) {
            AddModelSheet { model in
                viewModel.save(model, in: modelContext, existingModels: models)
            }
        }
    }
}

private struct ModelDetailView: View {
    let model: LanguageModel

    var body: some View {
        Form {
            Section("Overview") {
                LabeledContent("Name", value: model.name)
                LabeledContent("Family", value: model.modelFamily)
                LabeledContent("Parameters", value: model.parameterSummary)
                LabeledContent("State", value: model.installState.rawValue.capitalized)
                LabeledContent("Default", value: "No")
            }

            Section("Identifiers") {
                LabeledContent("Hugging Face", value: model.huggingFaceRepoID)
                LabeledContent("Local ID", value: model.localIdentifier)
            }
        }
        .navigationTitle(model.name)
    }
}

private struct AddModelSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var huggingFaceRepoID = ""
    @State private var localIdentifier = ""
    @State private var modelFamily = ""
    @State private var parameterSummary = ""

    let onSave: (LanguageModel) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Hugging Face Repo ID", text: $huggingFaceRepoID)
                TextField("Local Identifier", text: $localIdentifier)
                TextField("Model Family", text: $modelFamily)
                TextField("Parameter Summary", text: $parameterSummary)
            }
            .navigationTitle("Add Model")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(
                            LanguageModel(
                                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                huggingFaceRepoID: huggingFaceRepoID.trimmingCharacters(in: .whitespacesAndNewlines),
                                localIdentifier: localIdentifier.trimmingCharacters(in: .whitespacesAndNewlines),
                                modelFamily: modelFamily.trimmingCharacters(in: .whitespacesAndNewlines),
                                parameterSummary: parameterSummary.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        )
                        dismiss()
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
    }

    private var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        huggingFaceRepoID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        localIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        modelFamily.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        parameterSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Conversation.self, LanguageModel.self, AppPreferences.self], inMemory: true)
}
