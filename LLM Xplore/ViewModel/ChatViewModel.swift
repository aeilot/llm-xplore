//
//  ChatViewModel.swift
//  LLM Xplore
//
//  Created by Chenluo Deng on 4/16/26.
//

import MLXLLM
import MLXLMCommon
import Tokenizers
import SwiftUI
import Combine
import HFAPI
import MLXLMTokenizers
import SwiftData
import ExyteChat

@MainActor
final class ChatViewModel: ObservableObject {
    @Published private(set) var messages: [ExyteChat.Message]
    @Published var isGenerating = false
    @Published var errorMessage: String?

    private(set) var languageModel: LanguageModel?
    let session: Conversation

    init(languageModel: LanguageModel?, session: Conversation) {
        self.languageModel = languageModel
        self.session = session
        self.messages = session.messages.map(Self.makeMessage)
    }

    func updateLanguageModel(_ languageModel: LanguageModel?) {
        self.languageModel = languageModel
    }

    func send(draft: DraftMessage, in modelContext: SwiftData.ModelContext) {
        let prompt = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        guard !isGenerating else { return }
        guard let languageModel else {
            errorMessage = "Select a default model before sending a message."
            return
        }

        errorMessage = nil
        isGenerating = true

        if session.modelContext == nil {
            modelContext.insert(session)
        }

        session.addMessage(role: .user, content: prompt)
        session.finalizeTitleIfNeeded(from: prompt)
        session.beginAssistant()
        refreshMessages()
        persist(modelContext)

        Task {
            do {
                let model = try await loadModel(
                    from: HubClient.default as! Downloader,
                    using: TokenizersLoader(),
                    id: languageModel.huggingFaceRepoID,
                )
                
                let chatSession = ChatSession(model)

                let response = try await chatSession.respond(to: prompt)

                await MainActor.run {
                    if session.messages.last?.role == .assistant {
                        session.messages[session.messages.count - 1].content = response
                        session.updatedAt = .now
                    } else {
                        session.addMessage(role: .assistant, content: response)
                    }
                    refreshMessages()
                    persist(modelContext)
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    if session.messages.last?.role == .assistant,
                       session.messages.last?.content.isEmpty == true {
                        session.messages[session.messages.count - 1].content =
                            "Error: \(error.localizedDescription)"
                        session.updatedAt = .now
                    } else {
                        session.addMessage(role: .assistant, content: "Error: \(error.localizedDescription)")
                    }
                    refreshMessages()
                    persist(modelContext)
                    errorMessage = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }

    private func refreshMessages() {
        messages = session.messages.map(Self.makeMessage)
    }

    private func persist(_ modelContext: SwiftData.ModelContext) {
        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func makeMessage(from chatMessage: ChatMessage) -> ExyteChat.Message {
        ExyteChat.Message(
            id: chatMessage.id.uuidString,
            user: makeUser(for: chatMessage.role),
            createdAt: chatMessage.timestamp,
            text: chatMessage.content
        )
    }

    private static func makeUser(for role: ChatMessageRole) -> ExyteChat.User {
        switch role {
        case .user:
            ExyteChat.User(id: "user", name: "You", avatarURL: nil, isCurrentUser: true)
        case .assistant:
            ExyteChat.User(id: "assistant", name: "Assistant", avatarURL: nil, isCurrentUser: false)
        case .system:
            ExyteChat.User(id: "system", name: "System", avatarURL: nil, isCurrentUser: false)
        }
    }
}
