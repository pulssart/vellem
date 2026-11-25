import AppKit
import SwiftUI

struct PromptLibraryView: View {
    @Environment(\.locale) private var locale
    @State private var collection: PromptCollection = .work
    @State private var role: PromptRole?
    @State private var service: PromptService?
    @State private var copiedID: String?
    @State private var feedbackTask: Task<Void, Never>?
    @State private var preview: LibraryPrompt?
    @State private var copyFailed = false

    private func prompts(for role: PromptRole?) -> [LibraryPrompt] {
        let catalog = LibraryPrompt.catalog(in: collection, locale: locale)
        guard collection == .work, let role else { return catalog }
        return catalog.filter { $0.roles.contains(role) }
    }

    private func selectRole(_ value: PromptRole?) {
        if let service, !prompts(for: value).contains(where: { $0.services.contains(service) }) {
            self.service = nil
        }
        role = value
    }

    var body: some View {
        let collectionPrompts = prompts(for: role)
        let servicesInUse = Set(collectionPrompts.flatMap(\.services))
        let visiblePrompts = service.map { selected in collectionPrompts.filter { $0.services.contains(selected) } } ?? collectionPrompts

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Prompt library")
                        .font(.system(size: 36, weight: .semibold, design: .serif)).tracking(-1.4)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 16)
                    Picker("Collection", selection: $collection) {
                        Text("Work").tag(PromptCollection.work)
                        Text("Personal").tag(PromptCollection.personal)
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                    .onChange(of: collection) { service = nil }
                }
                Text("Click a card, then paste the prompt into your agent to receive the result in Vellem.")
                    .font(.system(size: 14)).foregroundStyle(InboxPalette.muted).padding(.top, 7)
                if collection == .work {
                    roleFilters.padding(.top, 23)
                }
                HStack(alignment: .top, spacing: 7) {
                    serviceButton(nil)
                    ForEach(PromptService.allCases.filter(servicesInUse.contains)) { item in
                        serviceButton(item)
                    }
                }
                .padding(.top, collection == .work ? 16 : 23).padding(.bottom, 22)

                if visiblePrompts.isEmpty {
                    ContentUnavailableView {
                        Label("No matching prompts", systemImage: "books.vertical")
                    } actions: {
                        Button("Show all services") { service = nil; selectRole(nil) }
                    }
                    .frame(maxWidth: .infinity, minHeight: 230)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 284), spacing: 16, alignment: .top)],
                          alignment: .leading, spacing: 16) {
                    ForEach(visiblePrompts) { prompt in
                        PromptCard(prompt: prompt, copied: copiedID == prompt.id) { copy(prompt) }
                            .contextMenu {
                                Button("Read prompt") { preview = prompt }
                                Button("Copy prompt") { copy(prompt) }
                            }
                    }
                }
            }
            .frame(maxWidth: 1080, alignment: .leading)
            .padding(.horizontal, 30).padding(.top, 30).padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(InboxPalette.ink)
        .navigationTitle("Prompt library")
        .sheet(item: $preview) { selected in
            let prompt = LibraryPrompt.catalog(in: collection, locale: locale).first { $0.id == selected.id } ?? selected
            VStack(alignment: .leading, spacing: 16) {
                Text(prompt.title).font(.title2.bold()).accessibilityAddTraits(.isHeader)
                ScrollView { Text(verbatim: prompt.text).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                HStack {
                    Button("Close") { preview = nil }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Copy prompt") { if copy(prompt) { preview = nil } }.keyboardShortcut(.defaultAction)
                }
            }.padding(24).frame(width: 475, height: 350)
        }
        .alert("Couldn’t copy", isPresented: $copyFailed) {
            Button("OK") {}
        } message: { Text("The clipboard is unavailable. Try again in a moment.") }
        .onDisappear { feedbackTask?.cancel() }
    }

    private var roleFilters: some View {
        let options: [PromptRole?] = [nil] + PromptRole.allCases.map { Optional($0) }
        return ViewThatFits(in: .horizontal) {
            roleRow(options[...])
                .fixedSize(horizontal: true, vertical: false)
            VStack(alignment: .leading, spacing: 6) {
                roleRow(options.prefix(4))
                roleRow(options.dropFirst(4))
            }
        }
    }

    private func roleRow(_ options: ArraySlice<PromptRole?>) -> some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let selected = role == option
                Button { selectRole(option) } label: {
                    Text(verbatim: VellemLanguage.text(option?.rawValue ?? "All roles", locale: locale))
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12).frame(minHeight: 28)
                        .foregroundStyle(selected ? .white : InboxPalette.ink)
                        .background(selected ? InboxPalette.ink : Color(white: 0.955), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func serviceButton(_ item: PromptService?) -> some View {
        let name = item?.rawValue ?? VellemLanguage.text("All services", locale: locale)
        return PromptServiceButton(service: item, name: name, selected: service == item) {
            service = service == item ? nil : item
        }
    }

    @discardableResult private func copy(_ prompt: LibraryPrompt) -> Bool {
        let board = NSPasteboard.general
        board.clearContents()
        guard board.setString(prompt.text, forType: .string) else { copyFailed = true; return false }
        feedbackTask?.cancel()
        copiedID = prompt.id
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
            .announcement: VellemLanguage.text("Prompt copied", locale: locale), .priority: NSAccessibilityPriorityLevel.medium.rawValue
        ])
        feedbackTask = Task {
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            copiedID = nil
        }
        return true
    }
}

private struct PromptServiceButton: View {
    let service: PromptService?
    let name: String
    let selected: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    let plate = RoundedRectangle(cornerRadius: 13, style: .continuous)
                    plate.fill(selected && service == nil ? InboxPalette.ink : hovered ? InboxPalette.header : .white)
                    if let service {
                        PromptServiceLogo(service: service, size: 36)
                    } else {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 25, weight: .medium))
                            .foregroundStyle(selected ? .white : InboxPalette.muted)
                    }
                    plate.strokeBorder(InboxPalette.ink.opacity(selected ? 1 : hovered ? 0.4 : 0.15),
                                       lineWidth: selected ? 2 : 1)
                }
                .frame(width: 56, height: 56)
                .overlay(alignment: .bottomTrailing) {
                    if selected && service != nil {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 15, height: 15).background(InboxPalette.ink, in: Circle())
                            .padding(1.5).background(.white, in: Circle())
                            .offset(x: 3, y: 3)
                    }
                }
                Text(verbatim: name)
                    .font(.system(size: 11, weight: selected ? .semibold : .regular))
                    .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                    .foregroundStyle(selected ? InboxPalette.ink : InboxPalette.muted)
            }
            .frame(width: 84)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityLabel(Text(verbatim: name))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct PromptServiceLogo: View {
    let service: PromptService
    let size: CGFloat

    var body: some View {
        Group {
            if service == .web {
                Image(systemName: "globe").resizable().scaledToFit()
                    .foregroundStyle(InboxPalette.ink)
            } else {
                Image(decorative: service.imageName).renderingMode(.original).resizable().scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct PromptCard: View {
    let prompt: LibraryPrompt
    let copied: Bool
    let action: () -> Void
    @Environment(\.locale) private var locale
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                PromptArtwork(prompt: prompt)
                caption
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.black.opacity(hovered ? 0.32 : 0.12)) }
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain).onHover { hovered = $0 }
        .accessibilityLabel(VellemLanguage.format("Copy prompt “%@”", prompt.title, locale: locale))
        .accessibilityHint(Text(verbatim: prompt.services.map(\.rawValue).joined(separator: ", ") + ". " + prompt.summary))
        .accessibilityValue(copied ? "Copied" : "")
        .help(VellemLanguage.format("Copy prompt “%@”", prompt.title, locale: locale))
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(verbatim: prompt.title)
                .font(.system(size: 17, weight: .semibold)).tracking(-0.35)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: prompt.summary)
                .font(.system(size: 13)).foregroundStyle(InboxPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(copied || hovered ? InboxPalette.ink : InboxPalette.muted)
        }
        .padding(15).frame(maxWidth: .infinity, minHeight: 132, maxHeight: .infinity, alignment: .topLeading)
        .background(.white)
    }
}

private struct PromptArtwork: View {
    let prompt: LibraryPrompt

    private var paperScale: CGSize {
        switch prompt.cover {
        case .stack: CGSize(width: 1, height: 1)
        case .tiles: CGSize(width: -1, height: 1)
        case .sheet: CGSize(width: 1, height: -1)
        }
    }

    var body: some View {
        Color.clear.frame(height: 152)
            .background {
                GeometryReader { proxy in
                    Image(decorative: "PromptPaper").resizable().scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(paperScale)
                        .hueRotation(.degrees(prompt.hue)).saturation(0.72)
                }
            }
            .overlay {
                switch prompt.cover {
                case .stack:
                    VStack(spacing: 5) {
                        ForEach(Array(prompt.services.enumerated()), id: \.element) { index, source in
                            HStack(spacing: 8) { PromptServiceLogo(service: source, size: 21); Text(source.rawValue).font(.system(size: 14, weight: .medium)) }
                                .padding(.horizontal, 12).frame(height: 34)
                                .background(.white, in: RoundedRectangle(cornerRadius: 9))
                                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
                                .offset(x: index == 0 ? -21 : 24)
                        }
                    }
                case .tiles:
                    HStack(spacing: 0) {
                        ForEach(Array(prompt.services.enumerated()), id: \.element) { index, source in
                            PromptServiceLogo(service: source, size: 32)
                                .frame(width: 51, height: 51)
                                .background(.white, in: RoundedRectangle(cornerRadius: 13))
                                .shadow(color: .black.opacity(0.14), radius: 4, y: 3)
                                .rotationEffect(.degrees(index == 0 ? -7 : 6))
                                .offset(y: index == 0 ? -4 : 5)
                            if index == 0 { Image(systemName: "link").font(.system(size: 13, weight: .semibold)).frame(width: 31).foregroundStyle(.black.opacity(0.65)) }
                        }
                    }
                case .sheet(let heading):
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 6) {
                            ForEach(prompt.services) { PromptServiceLogo(service: $0, size: 18) }
                            Text(prompt.services.map(\.rawValue).joined(separator: " + "))
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(InboxPalette.muted)
                        }
                        Text(LocalizedStringKey(heading))
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                        VStack(alignment: .leading, spacing: 5) {
                            Capsule().frame(width: 113, height: 3)
                            Capsule().frame(width: 72, height: 3)
                        }.foregroundStyle(.black.opacity(0.13))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(.white, in: RoundedRectangle(cornerRadius: 9))
                    .shadow(color: .black.opacity(0.14), radius: 4, y: 3)
                    .rotationEffect(.degrees(prompt.services.count == 1 ? 3 : -3))
                }
            }
            .clipped().accessibilityHidden(true)
    }
}
