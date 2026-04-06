//
//  ContentView.swift
//  LLM Xplore
//
//  Created by Chenluo Deng on 4/6/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatSession.updatedAt, order: .reverse) private var sessions: [ChatSession]

    var body: some View {
        NavigationViewWrapper {
            List {
                ForEach(sessions) { session in
                    NavigationLink {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(session.title)
                                .font(.headline)
                            Text(session.lastMessagePreview ?? "No messages yet")
                                .foregroundStyle(.secondary)
                            Text(session.updatedAt, format: Date.FormatStyle(date: .numeric, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                            Text(session.updatedAt, format: Date.FormatStyle(date: .numeric, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteSessions)
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        }
    }

    private func addItem() {
        withAnimation {
            let newSession = ChatSession()
            modelContext.insert(newSession)
        }
    }

    private func deleteSessions(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(sessions[index])
            }
        }
    }
}

fileprivate struct NavigationViewWrapper<Content: View>: View {
    let content: () -> Content

    var body: some View {
#if os(macOS)
        NavigationSplitView {
            content()
        } detail: {
            Text("Select an item")
        }
#else
        content()
#endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ChatSession.self, LanguageModel.self], inMemory: true)
}
