import SwiftUI

struct ContentView: View {
    @ObservedObject var store: NotesStore
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openWindow) private var openWindow
    @AppStorage(AppPreferences.hasReceivedMessagesKey) private var hasReceivedMessages = false
    @AppStorage(AppPreferences.hiddenInboxAgentsKey) private var hiddenAgents = HiddenInboxAgents()
    @Environment(\.locale) private var locale
    @FocusState private var searchFocused: Bool
    @State private var searchText = ""
    @State private var searchSelection: UUID?
    @State private var unreadOnly = false
    @State private var openedUnread: UUID?
    @State private var oldestFirst = false
    @State private var showPreviews = true
    @State private var isFullScreen = false
    @State private var showsFolders = false
    @State private var showsPromptLibrary = false
    @State private var lastRailSelection: SidebarMailbox?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var solidBackground: Bool { isFullScreen || reduceTransparency }
    private var panelInset: CGFloat { isFullScreen ? 12 : (store.libraryUnavailable && !showsPromptLibrary ? 0 : 6) }

    private var folder: Folder? {
        store.folders.first { $0.id == store.selectedFolderID }
    }
    private var agent: InboxAgent? { store.isInboxSelected ? store.inboxAgent : nil }
    private var folderPanelIsVisible: Bool { !showsPromptLibrary && showsFolders && !store.libraryUnavailable }
    private var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var title: String {
        if !query.isEmpty { return VellemLanguage.text("Search results", locale: locale) }
        if let folder { return folder.name }
        if showsFolders {
            switch store.sidebarRoot {
            case .folders: return VellemLanguage.text("All filed notes", locale: locale)
            case .today: return VellemLanguage.text("Today’s notes", locale: locale)
            default: return VellemLanguage.text("All notes", locale: locale)
            }
        }
        return VellemLanguage.text(store.sidebarRoot.title, locale: locale)
    }

    private var mailbox: [Note] {
        if !query.isEmpty {
            return store.notes.filter { $0.title.localizedStandardContains(query) || $0.text.localizedStandardContains(query) }
        }
        return store.displayedNotes
    }
    private var selectedID: UUID? { query.isEmpty ? store.selectedNoteID : searchSelection }
    private var showsFirstReception: Bool {
        !hasReceivedMessages && store.notes.isEmpty && store.sidebarRoot == .inbox &&
            folder == nil && query.isEmpty && !unreadOnly
    }

    var body: some View {
        let notes = mailbox
        let filtered = unreadOnly ? notes.filter { !$0.isRead || $0.id == openedUnread } : notes
        let visible = oldestFirst ? Array(filtered.reversed()) : filtered
        let selected = visible.first { $0.id == selectedID }
        GeometryReader { geometry in
            HStack(spacing: 0) {
                rail
                if folderPanelIsVisible {
                    MailboxFolderPanel(store: store, isFullScreen: isFullScreen, close: { setPanel(false) }, onNavigate: resetFilters)
                        .frame(width: min(218, max(145, geometry.size.width - 690)))
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                Group {
                    if showsPromptLibrary {
                        PromptLibraryView()
                            .inboxPanel()
                    } else if store.libraryUnavailable {
                        ContentUnavailableView {
                            Label("Vellem couldn’t open your library", systemImage: "externaldrive.badge.exclamationmark")
                        } actions: {
                            Button("Try again") { store.load() }
                        }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.background)
                            .clipShape(.rect(cornerRadius: isFullScreen ? 12 : 0))
                    } else {
                        HSplitView {
                            mailboxPanel(notes: visible, total: notes.count, unread: notes.filter { !$0.isRead }.count)
                                .frame(minWidth: showsFolders ? 212 : 265, idealWidth: 320, maxWidth: 365)
                                .background(SplitViewAutosave(name: "VellemInboxReaderSplit"))
                                .inboxPanel()
                                .padding(.trailing, isFullScreen ? 6 : 3)
                            Group {
                                if let selected {
                                    NoteReaderView(store: store, note: selected)
                                } else if showsFirstReception {
                                    FirstReceptionView(connect: openAgentSettings)
                                } else if !visible.isEmpty {
                                    MessageSelectionPlaceholder()
                                } else {
                                    Color.clear.accessibilityHidden(true)
                                }
                            }
                            .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
                            .inboxPanel()
                            .padding(.leading, isFullScreen ? 6 : 3)
                        }
                    }
                }
                .padding([.vertical, .trailing], panelInset)
                .padding(.leading, isFullScreen ? panelInset : 0)
            }
        }
        .background { InboxFullScreenObserver(isFullScreen: $isFullScreen) }
        .containerBackground(solidBackground ? InboxPalette.frame : .clear, for: .window)
        .background {
            ZStack {
                if !solidBackground { InboxWindowMaterial() }
                InboxPalette.frame.opacity(solidBackground ? 1 : 0.46)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .preferredColorScheme(.light)
        .ignoresSafeArea(.container, edges: .top)
        .alert("Library error", isPresented: Binding(get: { store.persistenceError != nil }, set: { if !$0 { store.persistenceError = nil } })) {
            Button("OK", role: .cancel) { store.persistenceError = nil }
        } message: { Text(store.persistenceError ?? "") }
        .onChange(of: store.notes.isEmpty, initial: true) { _, isEmpty in
            if !isEmpty && !hasReceivedMessages { hasReceivedMessages = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .vellemFocusSearch)) { _ in
            showsPromptLibrary = false
            Task { @MainActor in searchFocused = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .vellemMailboxReset)) { _ in
            showsPromptLibrary = false
            resetFilters()
            if folder == nil { setPanel(false); lastRailSelection = nil }
        }
        .onChange(of: searchText) { _, _ in searchSelection = nil; openedUnread = nil }
        .onChange(of: hiddenAgents, initial: true) { _, visibility in
            if case .agent(let agent) = store.sidebarRoot, !visibility.isVisible(agent) {
                activate(.inbox)
            }
        }
    }

    private var rail: some View {
        let visibleAgents = InboxAgent.allCases.filter(hiddenAgents.isVisible)
        return VStack(spacing: 6) {
            ScrollView(.vertical) {
                VStack(spacing: 6) {
                    sectionButton(.inbox, symbol: "tray.2")
                    sectionButton(.today, symbol: "calendar")
                    sectionButton(.folders, symbol: "folder")
                    if store.sidebarRoot == .captures || store.hasArchivedCaptures {
                        sectionButton(.captures, symbol: "archivebox")
                    }
                    if !visibleAgents.isEmpty { railDivider }
                    ForEach(visibleAgents, id: \.self) { origin in
                        RailButton(label: origin.rawValue, selected: !showsPromptLibrary && store.sidebarRoot == .agent(origin) && query.isEmpty, hint: railHint(for: .agent(origin)), hasUnread: store.hasUnread(in: .agent(origin))) {
                            activate(.agent(origin))
                        } icon: {
                            AgentMark(agent: origin, size: 23, onRail: true)
                        }
                    }
                }.frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            railDivider
            railItem("Prompt library", symbol: "books.vertical", selected: showsPromptLibrary) {
                showsPromptLibrary = true
                searchFocused = false
                lastRailSelection = nil
            }
            railItem("Settings", symbol: "gearshape") { openSettings() }
        }
        .frame(width: 79)
        .padding(.top, isFullScreen ? panelInset + 5 : 48).padding(.bottom, 13)
        .background {
            (folderPanelIsVisible ? InboxPalette.rail.opacity(solidBackground ? 1 : 0.44) : .clear)
                .contentShape(Rectangle())
                .gesture(WindowDragGesture())
        }
    }

    private var railDivider: some View {
        Capsule().fill(.white.opacity(0.16)).frame(width: 26, height: 1).padding(.vertical, 6)
    }

    private func sectionButton(_ section: SidebarMailbox, symbol: String) -> some View {
        RailButton(label: section.title, selected: !showsPromptLibrary && store.sidebarRoot == section && query.isEmpty, hint: railHint(for: section), hasUnread: store.hasUnread(in: section)) {
            activate(section)
        } icon: {
            Image(systemName: symbol).font(.system(size: 18, weight: .medium))
        }
    }

    private func railHint(for section: SidebarMailbox) -> String {
        if lastRailSelection == section && store.sidebarRoot == section && query.isEmpty {
            return showsFolders ? "Hide folders" : "Show folders"
        }
        return section.title
    }

    private func setPanel(_ visible: Bool) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) { showsFolders = visible }
    }

    private func activate(_ section: SidebarMailbox) {
        showsPromptLibrary = false
        if lastRailSelection == section && store.sidebarRoot == section && query.isEmpty {
            setPanel(!showsFolders)
            return
        }
        resetFilters()
        setPanel(false)
        lastRailSelection = section
        store.selectRoot(section)
    }

    private func railItem(_ label: String, symbol: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        RailButton(label: label, selected: selected, action: action) {
            Image(systemName: symbol).font(.system(size: 18, weight: .medium))
        }
    }

    private func openAgentSettings() {
        UserDefaults.standard.set("Agents", forKey: AppPreferences.settingsTabKey)
        openSettings()
    }

    private func mailboxPanel(notes: [Note], total: Int, unread: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 18, weight: .semibold)).lineLimit(1)
                Text(total, format: .number).font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.secondary).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
                Spacer(minLength: 4)
                Menu {
                    Toggle("Show previews", isOn: $showPreviews)
                    Button(showsFolders ? "Hide folders" : "Show folders") {
                        lastRailSelection = store.sidebarRoot
                        setPanel(!showsFolders)
                    }
                    Picker("Sort", selection: $oldestFirst) {
                        Text("Newest first").tag(false)
                        Text("Oldest first").tag(true)
                    }
                } label: { Image(systemName: "slider.horizontal.3") }
                    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().tint(.secondary)
                    .accessibilityLabel("List options").help("List options")
                Button(action: openAgentSettings) { Image(systemName: "cable.connector") }
                    .buttonStyle(.plain).help("Connect an agent").accessibilityLabel("Connect an agent")
            }
            .padding(.horizontal, 16).frame(height: 49)
            .background { InboxPalette.header }
            .background { Color.clear.contentShape(Rectangle()).gesture(WindowDragGesture()) }
            VStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search inboxes", text: $searchText).textFieldStyle(.plain).focused($searchFocused)
                        .onExitCommand { searchText = ""; searchFocused = false }
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).accessibilityLabel("Clear search")
                    }
                }.padding(.horizontal, 10).frame(height: 30)
                .background(.quaternary.opacity(0.5), in: Capsule())
                .overlay(Capsule().strokeBorder(.primary.opacity(0.09)))
                HStack(spacing: 3) {
                    filterTab("All", value: false)
                    filterTab("Unread", value: true, count: unread)
                    Spacer()
                }
            }.padding(.horizontal, 12).padding(.vertical, 10)
            Divider()
            if notes.isEmpty {
                VStack(spacing: 9) {
                    emptyMailbox(total: total)
                }.multilineTextAlignment(.center).padding(.horizontal, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: Binding<UUID?>(get: { selectedID }, set: { id in
                    guard let id else { return }
                    if unreadOnly { openedUnread = id }
                    if query.isEmpty {
                        store.selectNote(id, inToday: store.isTodaySelected, inFolder: store.isInboxSelected ? nil : folder?.id)
                    } else {
                        searchSelection = id; store.markRead(id)
                    }
                })) {
                    ForEach(notes) { note in
                        InboxMessageRow(note: note, agent: store.agent(for: note), showsPreview: showPreviews)
                            .listRowBackground(selectedID == note.id ? InboxPalette.selection : InboxPalette.paper)
                            .tag(note.id)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .contextMenu {
                                NoteContextMenu(note: note, store: store) { item in
                                    store.viewerNoteID = item.id; openWindow(id: "note-viewer")
                                }
                            }
                            .onDrag { NSItemProvider(object: note.id.uuidString as NSString) }
                    }
                }.listStyle(.plain).scrollContentBackground(.hidden)
                .tint(InboxPalette.selection)
                .environment(\.defaultMinListRowHeight, 0)
            }
        }
    }

    @ViewBuilder
    private func emptyMailbox(total: Int) -> some View {
        if unreadOnly && total > 0 {
            Image(systemName: "checkmark").accessibilityHidden(true)
            Text(query.isEmpty ? "You’re all caught up" : "No unread matches").font(.headline)
            Button(query.isEmpty ? "Show all messages" : "Show all matches") {
                unreadOnly = false
                openedUnread = nil
            }
        } else if !query.isEmpty {
            Image(systemName: "magnifyingglass").accessibilityHidden(true)
            Text("No results for “\(query)”").font(.headline).lineLimit(3)
            Button("Clear search") {
                searchText = ""
                searchFocused = true
            }
        } else if folder != nil {
            Image(systemName: "folder").accessibilityHidden(true)
            Text("No messages in this folder").font(.headline)
            Text("To file a message here, drag it onto this folder.")
                .font(.callout).foregroundStyle(.secondary)
        } else if let agent {
            EmptyAgentMailbox(agent: agent).id(agent)
        } else {
            switch store.sidebarRoot {
            case .today: Text("No messages today").foregroundStyle(.secondary)
            case .folders: Text("No filed messages").foregroundStyle(.secondary)
            case .captures: Text("No quick captures").foregroundStyle(.secondary)
            default: Text("No messages yet").foregroundStyle(.secondary)
            }
        }
    }

    private func filterTab(_ label: LocalizedStringKey, value: Bool, count: Int? = nil) -> some View {
        Button {
            unreadOnly = value; openedUnread = nil
        } label: {
            HStack(spacing: 5) {
                Text(label)
                if let count, count > 0 { Text(count, format: .number).monospacedDigit() }
            }
            .font(.system(size: 11, weight: .semibold)).foregroundStyle(unreadOnly == value ? .primary : .secondary)
            .padding(.horizontal, 10).frame(height: 23)
            .background(unreadOnly == value ? Color.primary.opacity(0.085) : .clear, in: Capsule())
        }
        .buttonStyle(.plain).accessibilityAddTraits(unreadOnly == value ? .isSelected : [])
    }

    private func resetFilters() {
        searchText = ""; searchFocused = false; unreadOnly = false; openedUnread = nil
    }

}

extension Notification.Name {
    static let vellemMailboxReset = Notification.Name("vellemMailboxReset")
}
