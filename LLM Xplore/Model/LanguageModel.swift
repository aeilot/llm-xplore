//
//  LanguageModel.swift
//  LLM Xplore
//
//  Created by Chenluo Deng on 4/6/26.
//

import Foundation
import SwiftData

enum ModelInstallState: String, Codable, CaseIterable {
    case notInstalled
    case downloading
    case installed
}

@Model
final class LanguageModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var huggingFaceRepoID: String
    var localIdentifier: String
    var modelFamily: String
    var parameterSummary: String
    var createdAt: Date
    var lastUsedAt: Date?
    var installStateRawValue: String

    var installState: ModelInstallState {
        get { ModelInstallState(rawValue: installStateRawValue) ?? .notInstalled }
        set { installStateRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        huggingFaceRepoID: String,
        localIdentifier: String,
        modelFamily: String,
        parameterSummary: String,
        createdAt: Date = .now,
        lastUsedAt: Date? = nil,
        installState: ModelInstallState = .installed
    ) {
        self.id = id
        self.name = name
        self.huggingFaceRepoID = huggingFaceRepoID
        self.localIdentifier = localIdentifier
        self.modelFamily = modelFamily
        self.parameterSummary = parameterSummary
        self.createdAt = createdAt
        self.lastUsedAt = lastUsedAt
        self.installStateRawValue = installState.rawValue
    }

    func markUsed(at date: Date = .now) {
        lastUsedAt = date
    }
}
