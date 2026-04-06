import SwiftData
import XCTest
@testable import LLM_Xplore

final class LLM_XploreTests: XCTestCase {
    func testInMemoryContainerCanStorePreferencesAndModelMetadata() throws {
        let container = try ModelContainer(
            for: ChatSession.self,
            LanguageModel.self,
            AppPreferences.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        let context = ModelContext(container)
        let model = LanguageModel(
            name: "Qwen 3 8B Instruct",
            huggingFaceRepoID: "Qwen/Qwen3-8B",
            localIdentifier: "qwen3-8b",
            modelFamily: "Qwen 3",
            parameterSummary: "8B",
            installState: .notInstalled
        )
        let preferences = AppPreferences()

        context.insert(model)
        context.insert(preferences)
        try context.save()

        let storedModels = try context.fetch(FetchDescriptor<LanguageModel>())
        let storedPreferences = try context.fetch(FetchDescriptor<AppPreferences>())

        XCTAssertEqual(storedModels.first?.modelFamily, "Qwen 3")
        XCTAssertEqual(storedModels.first?.installState, .notInstalled)
        XCTAssertEqual(storedPreferences.count, 1)
    }
}
