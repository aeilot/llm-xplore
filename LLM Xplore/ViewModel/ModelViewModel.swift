import Foundation
import SwiftData
import Combine

@MainActor
final class ModelViewModel: ObservableObject {
    @Published var selectedModelID: UUID?
    @Published var isPresentingAddModelSheet = false

    private let defaultModelKey = "defaultModelID"

    private var defaultModelIDRaw: String {
        get {
            UserDefaults.standard.string(forKey: defaultModelKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultModelKey)
        }
    }

    var defaultModelID: UUID? {
        UUID(uuidString: defaultModelIDRaw)
    }

    func sync(with models: [LanguageModel]) {
        if models.isEmpty {
            selectedModelID = nil
            defaultModelIDRaw = ""
            return
        }

        if selectedModelID == nil {
            selectedModelID = defaultModel(in: models)?.id ?? models.first?.id
        }

        if defaultModelIDRaw.isEmpty, let firstModel = models.first {
            defaultModelIDRaw = firstModel.id.uuidString
        }

        if let defaultModelID,
           models.contains(where: { $0.id == defaultModelID }) == false {
            defaultModelIDRaw = models.first?.id.uuidString ?? ""
        }

        if let selectedModelID,
           models.contains(where: { $0.id == selectedModelID }) == false {
            self.selectedModelID = defaultModel(in: models)?.id ?? models.first?.id
        }
    }

    func defaultModel(in models: [LanguageModel]) -> LanguageModel? {
        guard let defaultModelID else { return nil }
        return models.first(where: { $0.id == defaultModelID })
    }

    func isDefaultModel(_ model: LanguageModel) -> Bool {
        model.id == defaultModelID
    }

    func setDefaultModel(_ model: LanguageModel) {
        defaultModelIDRaw = model.id.uuidString
    }

    func save(_ model: LanguageModel, in modelContext: ModelContext, existingModels: [LanguageModel]) {
        modelContext.insert(model)

        if existingModels.isEmpty {
            defaultModelIDRaw = model.id.uuidString
        }

        selectedModelID = model.id
    }

    func delete(_ model: LanguageModel, from modelContext: ModelContext, existingModels: [LanguageModel]) {
        let deletedModelWasSelected = selectedModelID == model.id
        let deletedModelWasDefault = defaultModelID == model.id

        modelContext.delete(model)

        let remainingModels = existingModels.filter { $0.id != model.id }

        if deletedModelWasDefault {
            defaultModelIDRaw = remainingModels.first?.id.uuidString ?? ""
        }

        if deletedModelWasSelected {
            selectedModelID = remainingModels.first?.id
        }
    }
}
