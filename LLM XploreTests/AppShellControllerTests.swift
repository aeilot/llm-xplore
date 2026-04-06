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
