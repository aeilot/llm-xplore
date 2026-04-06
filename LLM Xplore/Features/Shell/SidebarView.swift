import SwiftUI
import SwiftData
import Observation

struct SidebarView: View {
    @Bindable var controller: AppShellController
    @Query(sort: \ChatSession.updatedAt, order: .reverse) private var sessions: [ChatSession]

    private var filteredSessions: [ChatSession] {
        let query = controller.sidebarSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sessions }

        return sessions.filter { session in
            session.title.localizedCaseInsensitiveContains(query)
                || (session.lastMessagePreview?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    var body: some View {
        List {
            Section {
                SidebarRouteButton(
                    title: "LLM Xplore",
                    systemImage: "bubble.left.and.bubble.right",
                    isSelected: controller.destination == .home
                ) {
                    controller.selectHome()
                }

                SidebarRouteButton(
                    title: "Models",
                    systemImage: "square.grid.2x2",
                    isSelected: controller.destination == .models
                ) {
                    controller.selectModels()
                }
            }

            Section("Chat History") {
                if filteredSessions.isEmpty {
                    Text(controller.sidebarSearchText.isEmpty ? "No chat history yet" : "No chats match your search")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filteredSessions) { session in
                        SidebarChatButton(
                            session: session,
                            isSelected: isSelected(session)
                        ) {
                            controller.selectChat(session.id)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(
            text: $controller.sidebarSearchText,
            placement: .sidebar,
            prompt: "Search chats"
        )
        .navigationTitle("LLM Xplore")
    }

    private func isSelected(_ session: ChatSession) -> Bool {
        if case .chat(session.id) = controller.destination {
            return true
        }
        return controller.selectedChatID == session.id
    }
}

private struct SidebarRouteButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
    }
}

private struct SidebarChatButton: View {
    let session: ChatSession
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title)
                Text(session.lastMessagePreview ?? "No messages yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
    }
}
