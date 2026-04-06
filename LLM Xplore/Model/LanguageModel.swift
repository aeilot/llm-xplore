//
//  LanguageModel.swift
//  LLM Xplore
//
//  Created by Chenluo Deng on 4/6/26.
//

import Foundation
import SwiftData

@Model
final class LanguageModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var huggingFaceRepoID: String
    var localIdentifier: String
    var createdAt: Date
    var lastUsedAt: Date?
    var isAvailable: Bool

    init(
        id: UUID = UUID(),
        name: String,
        huggingFaceRepoID: String,
        localIdentifier: String,
        createdAt: Date = .now,
        lastUsedAt: Date? = nil,
        isAvailable: Bool = true
    ) {
        self.id = id
        self.name = name
        self.huggingFaceRepoID = huggingFaceRepoID
        self.localIdentifier = localIdentifier
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.isAvailable = isAvailable
    }

    func markUsed(at date: Date = .now) {
        lastUsedAt = date
    }
}
