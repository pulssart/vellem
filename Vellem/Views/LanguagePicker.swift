import SwiftUI

struct LanguagePicker: View {
    @AppStorage(VellemLanguage.preferenceKey, store: VellemLanguage.defaults) private var language: VellemLanguage = .system

    var body: some View {
        #if os(macOS)
        picker
            .pickerStyle(.segmented)
            .onChange(of: language) { WidgetReloader.reload() }
        #else
        LabeledContent {
            picker.labelsHidden().pickerStyle(.menu)
        } label: {
            Label("Language", systemImage: "globe")
        }
        #endif
    }

    private var picker: some View {
        Picker(selection: $language) {
            Text("System default").tag(VellemLanguage.system)
            Text(verbatim: "English").tag(VellemLanguage.en)
            Text(verbatim: "Français").tag(VellemLanguage.fr)
        } label: {
            Label("Language", systemImage: "globe")
        }
        .accessibilityIdentifier("interfaceLanguage")
    }
}
