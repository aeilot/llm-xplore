# LLM Xplore Chat Shell Design

## Summary

Build a shared SwiftUI app shell for `macOS` and `iOS` that centers on a ChatGPT-like two-column chat experience, plus a macOS-only global quick-ask panel triggered by `Option + Space`.

The prototype should include:
- a cross-platform chat UI with model selection and a mock response pipeline shaped for future real inference APIs
- a model management screen with mock downloads, deletion, and model metadata
- a settings screen for default model preferences and quick-ask behavior
- a macOS floating quick-ask panel that always starts a fresh temporary chat

## Goals

- Match the interaction model of ChatGPT closely enough that the product feels familiar.
- Keep the core architecture shared across platforms so the prototype does not fork into separate apps.
- Make async UI flows realistic now, even though downloads and responses are mocked.
- Isolate macOS-only quick-ask behavior behind platform-specific infrastructure without duplicating chat UI logic.

## Non-Goals

- Real model downloads
- Real inference or network-backed chat responses
- Full sync, accounts, or cloud history
- Voice, image input, or advanced attachment flows

## Current Project Context

The current app is a small SwiftUI + SwiftData project with:
- `ChatSession` as the persisted chat entity
- `LanguageModel` as the persisted local model entity
- a minimal `ContentView` showing sessions in a list
- a standard `App` entry point already configured with a shared SwiftData container

This is a good starting point, but the current UI is far below the desired prototype fidelity and does not yet define route state, preferences, quick-ask behavior, or service boundaries for mock async flows.

## Product Shape

### Shared Shell

Use a shared app shell with:
- a two-column `NavigationSplitView` on macOS
- an iOS adaptation using the same route model and screen boundaries, even if the visual navigation container differs

The visual target is a ChatGPT-like desktop app:
- dark, restrained interface
- persistent left sidebar
- single main conversation column
- bottom composer
- minimal chrome

### Sidebar Information Architecture

The left sidebar contains:
1. a primary `LLM Xplore` entry
2. a primary `Models` entry
3. a `Chat History` subtitle
4. a searchable list of chats

Behavior:
- selecting `LLM Xplore` opens a new-chat home state in the detail pane
- selecting `Models` opens model management in the detail pane
- selecting a history item opens that chat in the detail pane
- `Settings` is not a primary sidebar destination; it is accessed from a toolbar or utility control so the sidebar remains close to the requested reference

## Navigation And State Model

### Routes

Define a route model with explicit destinations:
- `home`
- `chat(sessionID: PersistentIdentifier)`
- `models`
- `settings`

This route model should be shared by the app shell and used consistently across macOS and iOS.

### State Ownership

Use three state layers:

1. Persisted data via SwiftData
- chats
- models
- app preferences

2. App shell controller
- current destination
- selected chat
- active search text
- quick-ask handoff state

3. Screen-local view state
- chat composer draft
- response loading and streaming state
- model download progress display state
- settings form state where needed

The shell controller should own navigation state, not individual views.

## Chat Experience

### Home State

The `LLM Xplore` destination shows a new-chat home screen with:
- a centered composer
- a currently selected/default model pill
- lightweight starter prompt affordances

This is not a separate subsystem from chat. It is the empty state of the main chat experience.

### Conversation State

Selecting a chat opens the same detail region as a conversation view with:
- a single readable message column
- user and assistant messages rendered in a ChatGPT-like hierarchy
- a bottom composer that visually matches the home-state composer
- a top bar showing the current model and lightweight utilities

### Send Flow

When the user sends a prompt:
1. insert the user message immediately into UI state
2. if needed, create and persist a `ChatSession`
3. start a mocked assistant response stream
4. render partial assistant output as chunks arrive
5. finalize the assistant message when the stream completes

### New Chat Rules

From the main app:
- sending from `LLM Xplore` creates a new persisted chat session on first send
- the new session appears in `Chat History`
- the title is derived from the first prompt using a simple local heuristic such as truncation or first-line extraction

Drafts that have not been sent are not persisted.

## Mock Response API Design

The UI prototype should not hardcode fake responses directly into views. Instead, create a mock response service behind a future-friendly interface.

### Required States

The response pipeline must support:
- `idle`
- `sending`
- `streaming`
- `completed`
- `failed`

### Stream Events

The mock response stream should emit:
- `started`
- `tokenChunk(String)`
- `completed(fullText: String)`
- `failed(message: String)`

### Service Boundary

The UI should depend on a protocol-shaped abstraction such as:

```swift
protocol ChatResponding {
    func send(
        prompt: String,
        model: LanguageModel,
        existingSession: ChatSession?
    ) async throws -> AsyncThrowingStream<ChatResponseEvent, Error>
}
```

The exact signature may be adjusted during implementation, but the design constraint is fixed:
- the chat UI consumes a streaming abstraction
- the chat UI does not know whether the backend is mocked, local, or remote

## Model Management

### Placement

`Models` is a first-class destination shown in the detail pane when selected from the sidebar.

### Content

Each model entry should present:
- display name
- source or repo identifier
- local identifier
- availability state
- metadata summary such as size or family
- last-used timestamp if available

### Actions

Each model supports:
- `Download`
- `Delete`
- `Info`

### Mock Download Behavior

Downloads are fake but stateful:
- initiating a download starts a timed progress sequence
- progress is visible in the UI
- completion changes the model to locally available
- deletion reverts the model to not-installed state

The mock download logic must sit behind a service boundary so it can be replaced later without redesigning the screen.

## Settings

### Placement

`Settings` is opened from a toolbar or utility control rather than occupying a main sidebar slot.

### Settings Scope

The settings screen includes:
- default chat model
- default quick-ask model
- whether quick-ask opens the full app after send
- placeholders for future response API or inference configuration

These preferences should persist, because the prototype should behave consistently across launches.

## macOS Quick Ask

### Trigger

Global shortcut:
- `Option + Space`

### Presentation

On macOS, pressing the shortcut opens a Spotlight-style floating panel:
- above any app
- compact and centered
- dismissible with `Escape`
- focused on a single composer

### Behavior

Each invocation creates a new temporary quick-ask draft.

Rules:
- it does not continue a previous quick-ask conversation
- it uses the configured quick-ask default model
- it becomes a normal persisted chat only when the user sends

### Send Flow

When the user sends from quick-ask:
1. create a fresh chat session
2. append the user message
3. start the mocked assistant response
4. optionally bring the main app forward and reveal that chat, based on settings

### Platform Boundary

The hotkey registration and floating panel coordinator are macOS-only and should be isolated with `#if os(macOS)`.

The composer and chat logic inside the quick panel should reuse shared chat components wherever practical.

## Data Model Adjustments

The existing models are close but need expansion.

### ChatSession

Required adjustments:
- keep temporary quick-ask drafts out of persistence until send
- derive the persisted title from the first submitted prompt
- support incremental assistant-message updates during streaming

### LanguageModel

Required adjustments:
- add model family or summary metadata
- add download or installation state
- keep live download progress in the mock download service or controller layer, not in persistent storage

### Preferences

Add a persisted preferences model for:
- default chat model id
- default quick-ask model id
- quick-ask open-full-app flag

## Screen Boundaries

Keep files and responsibilities focused.

Expected screen-level components:
- app shell container
- sidebar
- chat home screen
- chat conversation screen
- model management screen
- settings screen
- reusable composer
- macOS quick-ask panel wrapper

Expected services:
- mock chat response service
- mock model download service
- preferences store/controller
- shell navigation controller

## Visual Direction

The visual language should stay deliberate and close to the provided reference:
- dark neutral palette
- restrained borders
- soft rounded surfaces
- sparse toolbar chrome
- high reading comfort in the message column

Avoid adding extra panels or utility clutter that would break the ChatGPT-like two-column feel.

## Risks And Constraints

- Global hotkey registration on macOS is platform-specific and should not leak into shared views.
- SwiftData persistence should not be entangled with temporary quick-ask draft state.
- Mock async flows must be realistic enough to exercise UI transitions without creating brittle timing assumptions.
- The iOS shell should share logic and structure, even if exact macOS visuals do not map one-to-one.

## Recommended Implementation Direction

Implement this in layers:
1. establish the app shell and destination model
2. build the chat home and conversation flows using a shared composer
3. add the mock response service and streaming UI states
4. add the models destination and mock download service
5. add settings and persisted preferences
6. add the macOS global hotkey and floating quick-ask panel

This sequence keeps the prototype functional at each milestone and avoids coupling macOS-specific work to the shared shell too early.
