# LLM Xplore Chat Shell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a shared SwiftUI chat prototype for macOS and iOS with a ChatGPT-like two-column shell, mock chat/model services, persisted preferences, and a macOS global quick-ask panel.

**Architecture:** The app will be reorganized around a shared app shell and route controller. Durable data stays in SwiftData models, while async chat/model behavior is driven by mock services behind small protocols. The macOS-only quick-ask flow will be isolated in a coordinator and floating panel wrapper, but it will reuse the shared composer and chat session creation logic.

**Tech Stack:** SwiftUI, SwiftData, Observation, XCTest, AppKit for macOS hotkey/panel wiring

---

## File Structure

### Existing files to modify

- `LLM Xplore/LLM_XploreApp.swift`
- `LLM Xplore/ContentView.swift`
- `LLM Xplore/Model/ChatSession.swift`
- `LLM Xplore/Model/LanguageModel.swift`
- `LLM Xplore.xcodeproj/project.pbxproj`

### New files to create

- `LLM Xplore/Model/AppPreferences.swift`
- `LLM Xplore/App/AppDestination.swift`
- `LLM Xplore/App/AppShellController.swift`
- `LLM Xplore/App/AppDependencies.swift`
- `LLM Xplore/Features/Shell/AppShellView.swift`
- `LLM Xplore/Features/Shell/SidebarView.swift`
- `LLM Xplore/Features/Chat/ChatHomeView.swift`
- `LLM Xplore/Features/Chat/ChatConversationView.swift`
- `LLM Xplore/Features/Chat/ChatComposerView.swift`
- `LLM Xplore/Features/Chat/ChatMessageRow.swift`
- `LLM Xplore/Features/Models/ModelsView.swift`
- `LLM Xplore/Features/Settings/SettingsView.swift`
- `LLM Xplore/Services/ChatResponding.swift`
- `LLM Xplore/Services/MockChatResponseService.swift`
- `LLM Xplore/Services/ModelDownloading.swift`
- `LLM Xplore/Services/MockModelDownloadService.swift`
- `LLM Xplore/Support/PreviewData.swift`
- `LLM Xplore/Support/SeedData.swift`
- `LLM Xplore/macOS/QuickAsk/GlobalHotkeyMonitor.swift`
- `LLM Xplore/macOS/QuickAsk/QuickAskPanelCoordinator.swift`
- `LLM Xplore/macOS/QuickAsk/QuickAskPanelView.swift`
- `LLM XploreTests/LLM_XploreTests.swift`
- `LLM XploreTests/AppShellControllerTests.swift`
- `LLM XploreTests/MockChatResponseServiceTests.swift`
- `LLM XploreTests/MockModelDownloadServiceTests.swift`

### Responsibility map

- `Model/*`: durable SwiftData models and small model helpers
- `App/*`: route enums, app-level controller, and dependency assembly
- `Features/Shell/*`: top-level shared shell and sidebar
- `Features/Chat/*`: home state, conversation state, composer, message rows
- `Features/Models/*`: model list, progress UI, delete/info actions
- `Features/Settings/*`: persisted preferences UI
- `Services/*`: mock chat and download abstractions
- `macOS/QuickAsk/*`: AppKit-backed global hotkey and floating panel
- `LLM XploreTests/*`: regression and behavior tests for controller/service logic

### Task 1: Add Test Target And Expand Durable Models

**Files:**
- Modify: `LLM Xplore.xcodeproj/project.pbxproj`
- Modify: `LLM Xplore/LLM_XploreApp.swift`
- Modify: `LLM Xplore/Model/ChatSession.swift`
- Modify: `LLM Xplore/Model/LanguageModel.swift`
- Create: `LLM Xplore/Model/AppPreferences.swift`
- Test: `LLM XploreTests/LLM_XploreTests.swift`

- [ ] **Step 1: Write the failing model/persistence smoke test**

```swift
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
```

- [ ] **Step 2: Run the test target command to verify it fails**

Run:

```bash
xcodebuild -project 'LLM Xplore.xcodeproj' -scheme 'LLM Xplore' -destination 'platform=macOS' -only-testing:'LLM XploreTests/LLM_XploreTests' test
```

Expected:
- fail because `LLM XploreTests` target does not exist yet
- fail because `AppPreferences`, `modelFamily`, `parameterSummary`, and `installState` do not exist yet

- [ ] **Step 3: Add the minimal test target and model changes**

Add an XCTest bundle target to `LLM Xplore.xcodeproj/project.pbxproj` named `LLM XploreTests` with source folder `LLM XploreTests`.

Create `LLM Xplore/Model/AppPreferences.swift`:

```swift
import Foundation
import SwiftData

@Model
final class AppPreferences {
    @Attribute(.unique) var id: UUID
    var defaultChatModelID: UUID?
    var defaultQuickAskModelID: UUID?
    var opensMainWindowAfterQuickAskSend: Bool

    init(
        id: UUID = UUID(),
        defaultChatModelID: UUID? = nil,
        defaultQuickAskModelID: UUID? = nil,
        opensMainWindowAfterQuickAskSend: Bool = true
    ) {
        self.id = id
        self.defaultChatModelID = defaultChatModelID
        self.defaultQuickAskModelID = defaultQuickAskModelID
        self.opensMainWindowAfterQuickAskSend = opensMainWindowAfterQuickAskSend
    }
}
```

Update `LLM Xplore/Model/LanguageModel.swift`:

```swift
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
}
```

Update `LLM Xplore/Model/ChatSession.swift`:

```swift
@Model
final class ChatSession {
    // existing properties...

    func beginAssistantPlaceholder(at timestamp: Date = .now) {
        messages.append(
            ChatMessage(role: .assistant, content: "", timestamp: timestamp)
        )
        updatedAt = timestamp
    }

    func appendAssistantChunk(_ chunk: String, at timestamp: Date = .now) {
        guard let index = messages.lastIndex(where: { $0.role == .assistant }) else {
            beginAssistantPlaceholder(at: timestamp)
            appendAssistantChunk(chunk, at: timestamp)
            return
        }

        messages[index].content.append(chunk)
        updatedAt = timestamp
    }

    func finalizeTitleIfNeeded(from prompt: String) {
        guard title == "New Chat" else { return }
        title = String(prompt.prefix(48)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

Update `LLM Xplore/LLM_XploreApp.swift` schema:

```swift
let schema = Schema([
    ChatSession.self,
    LanguageModel.self,
    AppPreferences.self,
])
```

- [ ] **Step 4: Run the test command again to verify it passes**

Run:

```bash
xcodebuild -project 'LLM Xplore.xcodeproj' -scheme 'LLM Xplore' -destination 'platform=macOS' -only-testing:'LLM XploreTests/LLM_XploreTests' test
```

Expected:
- `LLM_XploreTests` passes

- [ ] **Step 5: Commit**

```bash
git add 'LLM Xplore.xcodeproj/project.pbxproj' \
        'LLM Xplore/LLM_XploreApp.swift' \
        'LLM Xplore/Model/ChatSession.swift' \
        'LLM Xplore/Model/LanguageModel.swift' \
        'LLM Xplore/Model/AppPreferences.swift' \
        'LLM XploreTests/LLM_XploreTests.swift'
git commit -m "feat: add app preferences and model metadata"
```

### Task 2: Build The Shared App Shell And Navigation Controller

**Files:**
- Create: `LLM Xplore/App/AppDestination.swift`
- Create: `LLM Xplore/App/AppShellController.swift`
- Create: `LLM Xplore/App/AppDependencies.swift`
- Create: `LLM Xplore/Features/Shell/AppShellView.swift`
- Create: `LLM Xplore/Features/Shell/SidebarView.swift`
- Modify: `LLM Xplore/ContentView.swift`
- Test: `LLM XploreTests/AppShellControllerTests.swift`

- [ ] **Step 1: Write the failing route-selection tests**

```swift
import XCTest
@testable import LLM_Xplore

final class AppShellControllerTests: XCTestCase {
    func testSelectingHomeClearsSelectedChat() {
        let controller = AppShellController()
        let sessionID = UUID()

        controller.selectChat(sessionID)
        controller.selectHome()

        XCTAssertEqual(controller.destination, .home)
        XCTAssertNil(controller.selectedChatID)
    }

    func testSelectingModelsLeavesChatSelectionUntouchedButChangesDestination() {
        let controller = AppShellController()
        let sessionID = UUID()

        controller.selectChat(sessionID)
        controller.selectModels()

        XCTAssertEqual(controller.destination, .models)
        XCTAssertEqual(controller.selectedChatID, sessionID)
    }
}
```

- [ ] **Step 2: Run the controller tests to verify they fail**

Run:

```bash
xcodebuild -project 'LLM Xplore.xcodeproj' -scheme 'LLM Xplore' -destination 'platform=macOS' -only-testing:'LLM XploreTests/AppShellControllerTests' test
```

Expected:
- fail because `AppShellController` and `AppDestination` do not exist

- [ ] **Step 3: Implement the minimal shell/controller structure**

Create `LLM Xplore/App/AppDestination.swift`:

```swift
import Foundation

enum AppDestination: Hashable {
    case home
    case chat(UUID)
    case models
    case settings
}
```

Create `LLM Xplore/App/AppShellController.swift`:

```swift
import Foundation
import Observation

@Observable
final class AppShellController {
    var destination: AppDestination = .home
    var selectedChatID: UUID?
    var sidebarSearchText = ""
    var quickAskRequestedChatID: UUID?

    func selectHome() {
        destination = .home
        selectedChatID = nil
    }

    func selectChat(_ id: UUID) {
        selectedChatID = id
        destination = .chat(id)
    }

    func selectModels() {
        destination = .models
    }

    func selectSettings() {
        destination = .settings
    }
}
```

Create `LLM Xplore/App/AppDependencies.swift`:

```swift
import Foundation

struct AppDependencies {
    let chatResponder: any ChatResponding
    let modelDownloader: any ModelDownloading

    static let live = AppDependencies(
        chatResponder: MockChatResponseService(),
        modelDownloader: MockModelDownloadService()
    )
}
```

Update `LLM Xplore/ContentView.swift` to host `AppShellView()` instead of the placeholder list.

Create `LLM Xplore/Features/Shell/AppShellView.swift` and `LLM Xplore/Features/Shell/SidebarView.swift` using:
- macOS `NavigationSplitView`
- primary sidebar entries `LLM Xplore` and `Models`
- `Chat History` label + searchable list
- toolbar button for settings

- [ ] **Step 4: Run the controller tests again**

Run:

```bash
xcodebuild -project 'LLM Xplore.xcodeproj' -scheme 'LLM Xplore' -destination 'platform=macOS' -only-testing:'LLM XploreTests/AppShellControllerTests' test
```

Expected:
- `AppShellControllerTests` passes

- [ ] **Step 5: Commit**

```bash
git add 'LLM Xplore/App/AppDestination.swift' \
        'LLM Xplore/App/AppShellController.swift' \
        'LLM Xplore/App/AppDependencies.swift' \
        'LLM Xplore/Features/Shell/AppShellView.swift' \
        'LLM Xplore/Features/Shell/SidebarView.swift' \
        'LLM Xplore/ContentView.swift' \
        'LLM XploreTests/AppShellControllerTests.swift'
git commit -m "feat: add shared app shell and navigation controller"
```

### Task 3: Implement The Chat Home, Conversation Flow, And Mock Streaming Responses

**Files:**
- Create: `LLM Xplore/Services/ChatResponding.swift`
- Create: `LLM Xplore/Services/MockChatResponseService.swift`
- Create: `LLM Xplore/Features/Chat/ChatHomeView.swift`
- Create: `LLM Xplore/Features/Chat/ChatConversationView.swift`
- Create: `LLM Xplore/Features/Chat/ChatComposerView.swift`
- Create: `LLM Xplore/Features/Chat/ChatMessageRow.swift`
- Modify: `LLM Xplore/Features/Shell/AppShellView.swift`
- Test: `LLM XploreTests/MockChatResponseServiceTests.swift`

- [ ] **Step 1: Write the failing mock-stream service tests**

```swift
import XCTest
@testable import LLM_Xplore

final class MockChatResponseServiceTests: XCTestCase {
    func testMockResponderStreamsMultipleChunksAndCompletes() async throws {
        let service = MockChatResponseService()
        let model = LanguageModel(
            name: "Phi-4 Mini",
            huggingFaceRepoID: "microsoft/phi-4-mini",
            localIdentifier: "phi-4-mini",
            modelFamily: "Phi",
            parameterSummary: "Mini",
            installState: .installed
        )

        var events: [ChatResponseEvent] = []
        let stream = try await service.send(prompt: "hello", model: model, existingSession: nil)

        for try await event in stream {
            events.append(event)
        }

        XCTAssertTrue(events.contains(.started))
        XCTAssertGreaterThan(events.filter { if case .tokenChunk = $0 { return true } else { return false } }.count, 1)
        XCTAssertTrue(events.contains { if case .completed = $0 { return true } else { return false } })
    }
}
```

- [ ] **Step 2: Run the mock-stream tests to verify they fail**

Run:

```bash
xcodebuild -project 'LLM Xplore.xcodeproj' -scheme 'LLM Xplore' -destination 'platform=macOS' -only-testing:'LLM XploreTests/MockChatResponseServiceTests' test
```

Expected:
- fail because `ChatResponseEvent`, `ChatResponding`, and `MockChatResponseService` do not exist

- [ ] **Step 3: Implement the response contract and chat UI**

Create `LLM Xplore/Services/ChatResponding.swift`:

```swift
import Foundation

enum ChatResponseEvent: Equatable {
    case started
    case tokenChunk(String)
    case completed(String)
    case failed(String)
}

protocol ChatResponding {
    func send(
        prompt: String,
        model: LanguageModel,
        existingSession: ChatSession?
    ) async throws -> AsyncThrowingStream<ChatResponseEvent, Error>
}
```

Create `LLM Xplore/Services/MockChatResponseService.swift`:

```swift
import Foundation

struct MockChatResponseService: ChatResponding {
    func send(
        prompt: String,
        model: LanguageModel,
        existingSession: ChatSession?
    ) async throws -> AsyncThrowingStream<ChatResponseEvent, Error> {
        let reply = "Mock response from \(model.name): \(prompt)"
        let chunks = reply.split(separator: " ").map { String($0) + " " }

        return AsyncThrowingStream { continuation in
            continuation.yield(.started)

            Task {
                for chunk in chunks {
                    try? await Task.sleep(for: .milliseconds(120))
                    continuation.yield(.tokenChunk(chunk))
                }

                continuation.yield(.completed(reply))
                continuation.finish()
            }
        }
    }
}
```

Create the shared chat views with these responsibilities:
- `ChatHomeView`: centered composer + starter actions
- `ChatConversationView`: scrollable message column + bottom composer
- `ChatComposerView`: reusable text editor, model pill, send callback
- `ChatMessageRow`: role-aware bubble layout

Wire `AppShellView` detail rendering so:
- `.home` shows `ChatHomeView`
- `.chat(id)` shows `ChatConversationView`

Inside the send path:
- create a session on first send from home
- append user message immediately
- create an empty assistant message
- apply streamed chunks to the assistant message

- [ ] **Step 4: Run the tests and a macOS build**

Run:

```bash
xcodebuild -project 'LLM Xplore.xcodeproj' -scheme 'LLM Xplore' -destination 'platform=macOS' -only-testing:'LLM XploreTests/MockChatResponseServiceTests' test
xcodebuild -project 'LLM Xplore.xcodeproj' -scheme 'LLM Xplore' -destination 'platform=macOS' build
```

Expected:
- `MockChatResponseServiceTests` passes
- macOS app build succeeds

- [ ] **Step 5: Commit**

```bash
git add 'LLM Xplore/Services/ChatResponding.swift' \
        'LLM Xplore/Services/MockChatResponseService.swift' \
        'LLM Xplore/Features/Chat/ChatHomeView.swift' \
        'LLM Xplore/Features/Chat/ChatConversationView.swift' \
        'LLM Xplore/Features/Chat/ChatComposerView.swift' \
        'LLM Xplore/Features/Chat/ChatMessageRow.swift' \
        'LLM Xplore/Features/Shell/AppShellView.swift' \
        'LLM XploreTests/MockChatResponseServiceTests.swift'
git commit -m "feat: add chat flow and mock streaming responses"
```

### Task 4: Add Model Management And Mock Downloads

**Files:**
- Create: `LLM Xplore/Services/ModelDownloading.swift`
- Create: `LLM Xplore/Services/MockModelDownloadService.swift`
- Create: `LLM Xplore/Features/Models/ModelsView.swift`
- Modify: `LLM Xplore/Features/Shell/AppShellView.swift`
- Test: `LLM XploreTests/MockModelDownloadServiceTests.swift`

- [ ] **Step 1: Write the failing download-service test**

```swift
import XCTest
@testable import LLM_Xplore

final class MockModelDownloadServiceTests: XCTestCase {
    func testDownloadProgressEndsInInstalledState() async throws {
        let service = MockModelDownloadService()
        let model = LanguageModel(
            name: "DeepSeek R1 Distill",
            huggingFaceRepoID: "deepseek-ai/DeepSeek-R1-Distill",
            localIdentifier: "deepseek-r1-distill",
            modelFamily: "DeepSeek",
            parameterSummary: "Distill",
            installState: .notInstalled
        )

        var states: [ModelDownloadEvent] = []
        let stream = service.download(modelID: model.id)

        for await event in stream {
            states.append(event)
        }

        XCTAssertTrue(states.contains(.started))
        XCTAssertTrue(states.contains { if case .progress(let value) = $0 { return value > 0.5 } else { return false } })
        XCTAssertEqual(states.last, .completed)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
xcodebuild -project 'LLM Xplore.xcodeproj' -scheme 'LLM Xplore' -destination 'platform=macOS' -only-testing:'LLM XploreTests/MockModelDownloadServiceTests' test
```

Expected:
- fail because `MockModelDownloadService` and `ModelDownloadEvent` do not exist

- [ ] **Step 3: Implement the minimal download service and models screen**

Create `LLM Xplore/Services/ModelDownloading.swift`:

```swift
import Foundation

enum ModelDownloadEvent: Equatable {
    case started
    case progress(Double)
    case completed
}

protocol ModelDownloading {
    func download(modelID: UUID) -> AsyncStream<ModelDownloadEvent>
}
```

Create `LLM Xplore/Services/MockModelDownloadService.swift`:

```swift
import Foundation

struct MockModelDownloadService: ModelDownloading {
    func download(modelID: UUID) -> AsyncStream<ModelDownloadEvent> {
        AsyncStream { continuation in
            continuation.yield(.started)

            Task {
                for step in 1...5 {
                    try? await Task.sleep(for: .milliseconds(180))
                    continuation.yield(.progress(Double(step) / 5.0))
                }
                continuation.yield(.completed)
                continuation.finish()
            }
        }
    }
}
```

Create `LLM Xplore/Features/Models/ModelsView.swift`:
- list available models
- show family/summary/install state
- render progress bars for active downloads
- expose `Download`, `Delete`, and `Info` buttons

Update `AppShellView` to route `.models` to `ModelsView`.

- [ ] **Step 4: Run the test and macOS build**

Run:

```bash
xcodebuild -project 'LLM Xplore.xcodeproj' -scheme 'LLM Xplore' -destination 'platform=macOS' -only-testing:'LLM XploreTests/MockModelDownloadServiceTests' test
xcodebuild -project 'LLM Xplore.xcodeproj' -scheme 'LLM Xplore' -destination 'platform=macOS' build
```

Expected:
- `MockModelDownloadServiceTests` passes
- macOS app build succeeds

- [ ] **Step 5: Commit**

```bash
git add 'LLM Xplore/Services/ModelDownloading.swift' \
        'LLM Xplore/Services/MockModelDownloadService.swift' \
        'LLM Xplore/Features/Models/ModelsView.swift' \
        'LLM Xplore/Features/Shell/AppShellView.swift' \
        'LLM XploreTests/MockModelDownloadServiceTests.swift'
git commit -m "feat: add model management and mock downloads"
```

### Task 5: Add Settings, Seed Data, And Preference Wiring

**Files:**
- Create: `LLM Xplore/Features/Settings/SettingsView.swift`
- Create: `LLM Xplore/Support/SeedData.swift`
- Create: `LLM Xplore/Support/PreviewData.swift`
- Modify: `LLM Xplore/App/AppDependencies.swift`
- Modify: `LLM Xplore/LLM_XploreApp.swift`
- Modify: `LLM Xplore/Features/Shell/AppShellView.swift`
- Test: `LLM XploreTests/LLM_XploreTests.swift`

- [ ] **Step 1: Write the failing settings-seeding test**

```swift
func testSeedDataCreatesDefaultPreferencesAndStarterModels() throws {
    let container = try ModelContainer(
        for: ChatSession.self,
        LanguageModel.self,
        AppPreferences.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)

    SeedData.populateIfNeeded(in: context)

    let models = try context.fetch(FetchDescriptor<LanguageModel>())
    let preferences = try context.fetch(FetchDescriptor<AppPreferences>())

    XCTAssertGreaterThanOrEqual(models.count, 3)
    XCTAssertEqual(preferences.count, 1)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
xcodebuild -project 'LLM Xplore.xcodeproj' -scheme 'LLM Xplore' -destination 'platform=macOS' -only-testing:'LLM XploreTests/LLM_XploreTests' test
```

Expected:
- fail because `SeedData` does not exist

- [ ] **Step 3: Implement the settings screen and seed path**

Create `LLM Xplore/Support/SeedData.swift`:

```swift
import SwiftData

enum SeedData {
    static func populateIfNeeded(in context: ModelContext) {
        let modelCount = (try? context.fetchCount(FetchDescriptor<LanguageModel>())) ?? 0
        if modelCount == 0 {
            context.insert(LanguageModel(
                name: "Qwen 3 8B Instruct",
                huggingFaceRepoID: "Qwen/Qwen3-8B",
                localIdentifier: "qwen3-8b",
                modelFamily: "Qwen 3",
                parameterSummary: "8B",
                installState: .installed
            ))
            context.insert(LanguageModel(
                name: "Phi-4 Mini",
                huggingFaceRepoID: "microsoft/phi-4-mini",
                localIdentifier: "phi-4-mini",
                modelFamily: "Phi",
                parameterSummary: "Mini",
                installState: .installed
            ))
            context.insert(LanguageModel(
                name: "DeepSeek R1 Distill",
                huggingFaceRepoID: "deepseek-ai/DeepSeek-R1-Distill",
                localIdentifier: "deepseek-r1-distill",
                modelFamily: "DeepSeek",
                parameterSummary: "Distill",
                installState: .notInstalled
            ))
        }

        let preferencesCount = (try? context.fetchCount(FetchDescriptor<AppPreferences>())) ?? 0
        if preferencesCount == 0 {
            context.insert(AppPreferences())
        }

        try? context.save()
    }
}
```

Create `LLM Xplore/Features/Settings/SettingsView.swift` with:
- picker for default chat model
- picker for default quick-ask model
- toggle for opening the main app after quick ask send

Update `LLM Xplore/LLM_XploreApp.swift` to call `SeedData.populateIfNeeded(in:)` once on launch.

- [ ] **Step 4: Run the test and macOS build**

Run:

```bash
xcodebuild -project 'LLM Xplore.xcodeproj' -scheme 'LLM Xplore' -destination 'platform=macOS' -only-testing:'LLM XploreTests/LLM_XploreTests' test
xcodebuild -project 'LLM Xplore.xcodeproj' -scheme 'LLM Xplore' -destination 'platform=macOS' build
```

Expected:
- updated seed-data test passes
- macOS app build succeeds

- [ ] **Step 5: Commit**

```bash
git add 'LLM Xplore/Features/Settings/SettingsView.swift' \
        'LLM Xplore/Support/SeedData.swift' \
        'LLM Xplore/Support/PreviewData.swift' \
        'LLM Xplore/App/AppDependencies.swift' \
        'LLM Xplore/LLM_XploreApp.swift' \
        'LLM Xplore/Features/Shell/AppShellView.swift' \
        'LLM XploreTests/LLM_XploreTests.swift'
git commit -m "feat: add settings and seeded starter data"
```

### Task 6: Add The macOS Global Quick Ask Panel

**Files:**
- Create: `LLM Xplore/macOS/QuickAsk/GlobalHotkeyMonitor.swift`
- Create: `LLM Xplore/macOS/QuickAsk/QuickAskPanelCoordinator.swift`
- Create: `LLM Xplore/macOS/QuickAsk/QuickAskPanelView.swift`
- Modify: `LLM Xplore/LLM_XploreApp.swift`
- Modify: `LLM Xplore/App/AppShellController.swift`
- Modify: `LLM Xplore/Features/Chat/ChatComposerView.swift`
- Test: `LLM XploreTests/AppShellControllerTests.swift`

- [ ] **Step 1: Write the failing quick-ask handoff test**

```swift
func testQuickAskHandoffStoresRequestedChatID() {
    let controller = AppShellController()
    let sessionID = UUID()

    controller.handleQuickAskCreatedChat(sessionID)

    XCTAssertEqual(controller.quickAskRequestedChatID, sessionID)
    XCTAssertEqual(controller.destination, .chat(sessionID))
}
```

- [ ] **Step 2: Run the controller tests to verify they fail**

Run:

```bash
xcodebuild -project 'LLM Xplore.xcodeproj' -scheme 'LLM Xplore' -destination 'platform=macOS' -only-testing:'LLM XploreTests/AppShellControllerTests' test
```

Expected:
- fail because `handleQuickAskCreatedChat(_:)` does not exist

- [ ] **Step 3: Implement the minimal macOS-only quick panel**

Create `LLM Xplore/macOS/QuickAsk/GlobalHotkeyMonitor.swift`:

```swift
#if os(macOS)
import AppKit

final class GlobalHotkeyMonitor {
    var onToggle: (() -> Void)?

    func start() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let isOptionSpace = event.modifierFlags.contains(.option) && event.keyCode == 49
            if isOptionSpace {
                self?.onToggle?()
            }
        }
    }
}
#endif
```

Create `LLM Xplore/macOS/QuickAsk/QuickAskPanelCoordinator.swift` and `QuickAskPanelView.swift`:
- host a floating `NSPanel`
- embed the shared composer
- dismiss with `Escape`
- create a fresh session on send

Add to `AppShellController`:

```swift
func handleQuickAskCreatedChat(_ id: UUID) {
    quickAskRequestedChatID = id
    selectChat(id)
}
```

Wire startup from `LLM_XploreApp.swift` so the quick panel is available only on macOS.

- [ ] **Step 4: Run the controller test and macOS build**

Run:

```bash
xcodebuild -project 'LLM Xplore.xcodeproj' -scheme 'LLM Xplore' -destination 'platform=macOS' -only-testing:'LLM XploreTests/AppShellControllerTests' test
xcodebuild -project 'LLM Xplore.xcodeproj' -scheme 'LLM Xplore' -destination 'platform=macOS' build
```

Expected:
- controller tests pass
- macOS app build succeeds with quick panel code behind `#if os(macOS)`

- [ ] **Step 5: Commit**

```bash
git add 'LLM Xplore/macOS/QuickAsk/GlobalHotkeyMonitor.swift' \
        'LLM Xplore/macOS/QuickAsk/QuickAskPanelCoordinator.swift' \
        'LLM Xplore/macOS/QuickAsk/QuickAskPanelView.swift' \
        'LLM Xplore/LLM_XploreApp.swift' \
        'LLM Xplore/App/AppShellController.swift' \
        'LLM Xplore/Features/Chat/ChatComposerView.swift' \
        'LLM XploreTests/AppShellControllerTests.swift'
git commit -m "feat: add macOS quick ask panel"
```

## Self-Review

### Spec coverage

- Shared two-column shell: covered in Task 2
- `LLM Xplore` + `Models` + chat history sidebar: covered in Task 2
- Chat home + conversation flow + model selection + mock response API: covered in Task 3
- Model management with mock downloads/delete/info: covered in Task 4
- Settings for default models and quick-ask behavior: covered in Task 5
- macOS `Option + Space` floating quick-ask panel: covered in Task 6

No spec gaps remain.

### Placeholder scan

- No `TODO`, `TBD`, or deferred placeholders remain in the task list.
- All tasks name exact files and explicit commands.

### Type consistency

- Route type is consistently `AppDestination`
- shell owner is consistently `AppShellController`
- chat service abstraction is consistently `ChatResponding`
- model download abstraction is consistently `ModelDownloading`

The only intentionally flexible detail is the exact SwiftUI view layout implementation inside each feature screen. The responsibility boundaries and names are fixed.
