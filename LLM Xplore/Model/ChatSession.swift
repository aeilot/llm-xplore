//
//  ChatSession.swift
//  LLM Xplore
//
//  Created by Chenluo Deng on 4/6/26.
//

import Foundation
import SwiftData

enum ChatMessageRole: String, Codable, CaseIterable {
    case system
    case user
    case assistant
}

struct ChatMessage: Identifiable, Codable, Equatable {
    var id: UUID
    var role: ChatMessageRole
    var content: String
    var timestamp: Date

    init(
        id: UUID = UUID(),
        role: ChatMessageRole,
        content: String,
        timestamp: Date = .now
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

@Model
final class ChatSession {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var messages: [ChatMessage]

    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        messages: [ChatMessage] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }

    var lastMessagePreview: String? {
        messages.last?.content
    }

    func addMessage(
        role: ChatMessageRole,
        content: String,
        timestamp: Date = .now
    ) {
        messages.append(
            ChatMessage(
                role: role,
                content: content,
                timestamp: timestamp
            )
        )
        updatedAt = timestamp
    }
}
