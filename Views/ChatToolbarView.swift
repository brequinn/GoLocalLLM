// Views/ChatToolbarView.swift

import SwiftUI

struct ChatToolbarView: View {
    @Bindable var vm: ChatViewModel

    var body: some View {
        Menu {
            Picker("Model", selection: $vm.selectedModel) {
                ForEach(MLXService.availableModels) { model in
                    Text(model.displayName).tag(model)
                }
            }
        } label: {
            Label("Model", systemImage: "square.stack.3d.up")
        }
    }
}

