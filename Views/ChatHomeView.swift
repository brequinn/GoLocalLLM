//
//  ChatHomeView.swift
//  Primary screen combining the model picker, particle hero state, transcript, and composer.
//
/*
 This view is the main chat screen.
 It shows a top bar with controls, a hero animation before the first message,
 a conversation transcript, and the input bar at the bottom.
 It also manages model picking, media selection, and a few sheets.
*/

import AVFoundation        // Media capture and playback utilities used elsewhere in the app
import AVKit               // AVPlayer based UI components
import PhotosUI            // Photos picker for selecting images and videos
import SwiftUI             // SwiftUI framework for building the UI
import UIKit

struct ChatHomeView: View {
    // The view model that owns chat state, generation, media selection, and model management.
    @Bindable private var vm: ChatViewModel

    // Local view state flags that toggle sheets and pickers.
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showAttachmentOptions = false
    @State private var showCameraPicker = false

    // Tracks whether the prompt TextField has focus.
    @FocusState private var promptFocused: Bool

    // Designated initializer to inject the view model.
    init(viewModel: ChatViewModel) { self.vm = viewModel }

    var body: some View {
        // NavigationStack hosts navigation destinations if you add them later.
        NavigationStack {
            // The main vertical layout.
            VStack(spacing: 0) {
                // Custom header bar defined below.
                topBar

                // The content area that either shows a hero effect or the conversation.
                ZStack {
                    // Centered shimmer logo that shows until the first message appears.
                    ShimmeringLogoView()
                        .opacity(vm.messages.isEmpty ? 1 : 0)
                        .allowsHitTesting(false)
                        .animation(.easeInOut(duration: 0.6), value: vm.messages.isEmpty)

                    // The scrollable list of messages.
                    ConversationView(messages: vm.messages)
                        // Tapping the transcript focuses the prompt.
                        .simultaneousGesture(TapGesture().onEnded { focusPrompt() })
                        // Show an overlay preview for any selected media, anchored bottom trailing.
                        .overlay(alignment: .bottomTrailing) {
                            if !vm.mediaSelection.isEmpty {
                                // Show a quick preview stack for any attached media.
                                MediaPreviewsView(mediaSelection: vm.mediaSelection)
                                    .padding(.bottom, 96)
                                    .padding(.trailing)
                            }
                        }
                }
            }
            // Use the system background to match light and dark mode.
            .background(Color(.systemBackground))
            // Settings sheet toggled by the hamburger button in the top bar.
            .sheet(isPresented: $showSettings) { SettingsView().environment(vm) }
            // Conversation history sheet toggled by the clock button in the top bar.
            .sheet(isPresented: $showHistory) { ConversationHistoryView() }
            // Photos picker presented when the user wants to attach images or videos.
            .photosPicker(
                isPresented: $vm.mediaSelection.isShowing,
                selection: $photoPickerItem,
                matching: .any(of: [.images, .videos])
            )
            // When a new picker item arrives, load it through the view model and then clear the local binding.
            .onChange(of: photoPickerItem) { _, newItem in
                guard let item = newItem else { return }
                Task {
                    await vm.loadMedia(from: item)
                    await MainActor.run { photoPickerItem = nil }
                }
            }
            // Run once when the view appears. Prepare models and optionally focus the keyboard.
            .task {
                vm.refreshDefaultFromDownloads()
                await vm.preloadSelected()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    promptFocused = true
                }
            }
            // If the selected model changes, preload it (only if already downloaded).
            .onChange(of: vm.selectedModel) { _, _ in
                Task { await vm.preloadSelected() }
            }
            // When generation stops, refocus the prompt to keep the flow quick.
            .onChange(of: vm.isGenerating) { _, nowGenerating in
                if nowGenerating == false {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        promptFocused = true
                    }
                }
            }
            // The composer is inset into the bottom safe area, acting as a fixed input bar.
            .safeAreaInset(edge: .bottom, spacing: 0) {
                inputBar
            }
        }
    }

    // MARK: Input Bar
    // This is the composer area. It shows a transient status pill, the media add button, the prompt field, and the send button.
    private var inputBar: some View {
        VStack(spacing: 14) {
            // Enhanced status indicator with progress and better visuals
            if let statusType = enhancedStatusType {
                EnhancedStatusView(
                    type: statusType,
                    progress: statusProgress
                )
                .onAppear
                .transition(.scale.combined(with: .opacity))
            }

            // Main composer row with add media, prompt text field, and send button.
            HStack(spacing: 12) {
                // Add media button, only enabled when the selected model supports vision.
                Button {
                    showAttachmentOptions = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 38, height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.systemBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add media")
                .disabled(!vm.selectedModel.isVisionModel)
                // Dim if the current model does not support media.
                .opacity(vm.selectedModel.isVisionModel ? 1 : 0.35)

                // Prompt field and send button live inside a pill shaped container.
                HStack(spacing: 12) {
                    // Multiline TextField for the prompt.
                    TextField("How can I help?", text: $vm.prompt, axis: .vertical)
                        .textInputAutocapitalization(.sentences)
                        .disableAutocorrection(false)
                        .focused($promptFocused)
                        .submitLabel(.send)
                        // Pressing return with the Send label triggers a send.
                        .onSubmit { Task { await trySend() } }

                    // Send button that either enqueues or generates based on the current state.
                    Button {
                        Task { await trySend() }
                    } label: {
                        Group {
                            if vm.isGenerating {
                                // Circular progress view matches the design's spinner.
                                ProgressView()
                                    .progressViewStyle(.circular)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .frame(width: 28, height: 28)
                        .padding(6)
                        .background(
                            Capsule().fill(
                                sendEnabled ?
                                LinearGradient(
                                    colors: [Color(red: 0.2, green: 0.5, blue: 0.95), Color(red: 0.3, green: 0.6, blue: 1.0)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.primary.opacity(0.08), Color.primary.opacity(0.08)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        )
                        .foregroundStyle(sendEnabled ? Color.white : Color.primary.opacity(0.4))
                        .shadow(color: sendEnabled ? Color(red: 0.2, green: 0.5, blue: 0.95).opacity(0.3) : Color.clear, radius: 6, y: 3)
                    }
                    .buttonStyle(.plain)
                    .disabled(!sendEnabled)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 18)
                .frame(minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        // Solid background so the composer blends with the chat surface.
        .background(
            Color(.systemBackground)
                .overlay(Divider(), alignment: .top)
        )
        // Animate the status indicator appearing and disappearing.
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: enhancedStatusType != nil)
        .confirmationDialog("Attach Media", isPresented: $showAttachmentOptions, titleVisibility: .visible) {
            if vm.selectedModel.isVisionModel {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Camera") { showCameraPicker = true }
                }
                Button("Photo Library") { vm.mediaSelection.isShowing = true }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showCameraPicker) {
            CameraPicker { image in
                Task { await vm.attachCapturedImage(image) }
            }
        }
    }

    // Returns enhanced status type for better visual feedback
    private var enhancedStatusType: EnhancedStatusView.StatusType? {
        if let downloading = vm.downloadingModelID, downloading == vm.selectedModel.id {
            let modelName = modelTitleMain(vm.selectedModel.name)
            return .downloading(modelName)
        }
        if vm.isModelLoaded == false {
            let modelName = modelTitleMain(vm.selectedModel.name)
            return .loading(modelName)
        }
        return nil
    }

    private var statusProgress: Double? {
        if let downloading = vm.downloadingModelID, downloading == vm.selectedModel.id {
            return vm.modelDownloadProgress?.fractionCompleted
        }
        return nil
    }

    // Determines whether the send button can be tapped, based on text or media presence.
    private var canSend: Bool {
        // Enable the send control when there's either text or media to submit.
        let hasText = !vm.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMedia = !vm.mediaSelection.isEmpty
        return hasText || hasMedia
    }

    private var sendEnabled: Bool {
        vm.isModelLoaded && canSend
    }

    // Focus the prompt field if not already focused.
    private func focusPrompt() {
        if promptFocused { return }
        DispatchQueue.main.async {
            promptFocused = true
        }
    }

    // Send behavior when the user taps the send control or presses return.
    // If the model is busy, enqueue the current prompt.
    // If idle, generate immediately from the current prompt.
    private func trySend() async {
        if vm.isGenerating {
            await vm.enqueueCurrentPrompt()
        } else {
            await vm.generateFromCurrentPrompt()
        }
    }

    // MARK: Top Bar
    // The header row with hamburger menu, model selector menu, history, and new chat buttons.
    private var topBar: some View {
        let localModels = vm.downloadedModels

        return HStack(spacing: 12) {
            Button { showSettings = true } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 20, weight: .semibold))
            }
            .padding(.leading)

            Spacer()

            if localModels.isEmpty {
                Button {
                    showSettings = true
                } label: {
                    HStack(spacing: 6) {
                        Text("Select a model")
                            .font(.headline)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Menu {
                    ForEach(localModels) { model in
                        modelButton(for: model)
                    }
                    Divider()
                    Button("Manage Models…") { showSettings = true }
                } label: {
                    HStack(spacing: 6) {
                        Text(modelTitleMain(vm.selectedModel.name))
                            .font(.headline)
                        Text(modelTitleSuffix(vm.selectedModel.name))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .menuStyle(.borderlessButton)
            }

            Spacer()

            HStack(spacing: 16) {
                Button { showHistory = true } label: {
                    Image(systemName: "clock")
                        .font(.system(size: 18, weight: .regular))
                }

                Button { vm.clear(.chat) } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18, weight: .regular))
                }
            }
            .padding(.trailing)
        }
        .padding(.vertical, 12)
        .background(
            Color(.systemBackground)
                .overlay(Divider(), alignment: .bottom)
        )
    }

    private func modelButton(for model: LMModel) -> some View {
        // Generic helper so menu sections all render checkmarks consistently.
        Button {
            vm.setModel(model)
        } label: {
            HStack {
                Text(model.displayName)
                if model.id == vm.selectedModel.id {
                    Spacer()
                    Image(systemName: "checkmark")
                }
            }
        }
    }

    // Splits a model name into a primary part and a suffix for display, using colon or space separators.
    private func modelTitleMain(_ full: String) -> String {
        if let idx = full.firstIndex(of: ":") { return String(full[..<idx]) }
        if let space = full.firstIndex(of: " ") { return String(full[..<space]) }
        return full
    }

    // Returns the suffix part of the model name after a colon or first space, else returns empty.
    private func modelTitleSuffix(_ full: String) -> String {
        if let idx = full.firstIndex(of: ":") { return String(full[full.index(after: idx)...]) }
        if let space = full.firstIndex(of: " ") { return String(full[full.index(after: space)...]) }
        return ""
    }
}

// Xcode preview for development. Creates a ChatHomeView with a basic service.
#Preview {
    ChatHomeView(viewModel: ChatViewModel(mlxService: MLXService()))
}
