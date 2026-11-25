import SwiftUI

private enum MobileTab { case inbox, boxes }
enum MailScope: Equatable {
    case all, agent(InboxAgent), folder(UUID)
}

struct MobileRootView: View {
    @ObservedObject var store: MobileNotesStore
    @State private var tab = MobileTab.inbox
    @State private var scope = MailScope.all
    @State private var navigation: [UUID] = []
    @State private var railOpen = false
    @State private var expanded: InboxAgent? = .codex
    @State private var unread = false
    @State private var search = ""
    @State private var searching = false
    @State private var makingFolder = false
    @State private var folderName = ""
    @State private var folderError: String?
    @State private var menuHeight: CGFloat = 52
    @AppStorage(MobileHaptics.preferenceKey) private var hapticsEnabled = true
    @Environment(\.locale) private var locale
    @FocusState private var searchFocus: Bool

    private var dark: Bool { tab == .boxes }
    private var allNotes: [Note] {
        store.notes(in: scope)
    }
    private var title: String {
        switch scope {
        case .all: VellemLanguage.text("Inbox", locale: locale)
        case .agent(let agent): agent.rawValue
        case .folder(let id): store.folders.first { $0.id == id }?.name ?? VellemLanguage.text("Folder", locale: locale)
        }
    }

    var body: some View {
        NavigationStack(path: $navigation) {
            GeometryReader { viewport in
                mailbox(bottomInset: viewport.safeAreaInsets.bottom, height: viewport.size.height)
                    .ignoresSafeArea(.container, edges: .bottom)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                if let note = store.notes.first(where: { $0.id == id }) {
                    MobileNoteDetail(store: store, note: note)
                } else {
                    ScrollView {
                        MobileEmptyState(artwork: .document, title: "Report unavailable",
                                         detail: "This message is no longer in your inbox.",
                                         actionTitle: "Back to inbox") { navigation.removeAll() }
                            .padding(.vertical, 48)
                    }
                }
            }
        }
        .tint(dark && navigation.isEmpty ? .white : .black)
        .preferredColorScheme((dark || railOpen) && navigation.isEmpty ? .dark : .light)
        .onChange(of: railOpen) { _, open in if open { searchFocus = false } }
        .alert("New folder", isPresented: $makingFolder) {
            TextField("Folder name", text: $folderName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                guard let agent = expanded else { return }
                if store.createFolder(folderName, for: agent) {
                    MobileHaptics.shared.notify(.success)
                } else {
                    folderError = "Choose an unused name between 1 and 100 characters."
                    MobileHaptics.shared.notify(.error)
                }
            }
        } message: { Text(expanded?.rawValue ?? "") }
        .alert("Folder unavailable", isPresented: Binding(get: { folderError != nil }, set: { if !$0 { folderError = nil } })) {
            Button("OK") { folderError = nil }
        } message: { Text(LocalizedStringKey(folderError ?? "")) }
    }

    private func mailbox(bottomInset: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            mailboxHeader
                .background {
                    GeometryReader { bar in
                        MobileTopBarMaterial(surface: dark ? MobileStyle.graphite : .white, barHeight: bar.size.height)
                    }
                    .allowsHitTesting(false)
                }
                .zIndex(1)
            mailboxList(height: height)
                .contentMargins(.bottom, searchFocus ? 0 : menuHeight + bottomInset + 4, for: .scrollContent)
                .scrollClipDisabled()
        }
        .clipped()
        .overlay(alignment: .bottom) {
            if !searchFocus {
                mailboxMenu
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { menuHeight = $0 }
                    .padding(.bottom, bottomInset + 4)
            }
        }
        .frame(maxWidth: .infinity)
        .background((dark ? MobileStyle.graphite : Color.white).ignoresSafeArea())
        .foregroundStyle(dark ? .white : .black)
        .modifier(MobileInboxDrawer(isOpen: $railOpen, enabled: !dark && navigation.isEmpty,
                                    scope: scope, hasUnread: store.hasUnread(in:), select: open))
    }

    private func mailboxList(height: CGFloat) -> some View {
        ScrollViewReader { scroll in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    Text(dark ? VellemLanguage.text("Mailboxes", locale: locale) : title).font(.largeTitle.bold()).tracking(-1.4)
                        .id("mailboxHeading")
                        .accessibilityAddTraits(.isHeader).padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 17)
                    if dark { boxesContent } else { inboxContent(height: height) }
                    if let item = store.pending.first(where: { $0.error != nil }), let error = item.error {
                        VStack(alignment: .leading, spacing: 6) {
                            Label(VellemLanguage.serviceMessage(error, locale: locale), systemImage: "exclamationmark.circle")
                            Button("Dismiss") { store.dismiss(item) }
                        }.font(.footnote).padding()
                    }
                }
                .padding(.bottom, 16)
            }
            .refreshable { await store.refresh() }
            .onChange(of: searching) { _, active in
                if active { scroll.scrollTo("mailboxHeading", anchor: .top) }
            }
        }
    }

    private var mailboxHeader: some View {
        HStack(spacing: 8) {
            if !dark {
                Button {
                    searchFocus = false
                    railOpen = true
                    MobileHaptics.shared.selectionChanged()
                } label: {
                    Image(systemName: "sidebar.left").frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel("Show agent inboxes")
                .accessibilityIdentifier("showMailboxRail")
            }
            if !dark && scope != .all {
                Button(action: showBoxes) { Label("Mailboxes", systemImage: "chevron.left") }
            } else {
                HStack(spacing: 5) { Image("FoldMark").resizable().scaledToFit().frame(width: 21, height: 21); Text("Vellem").fontWeight(.semibold) }
            }
            Spacer()
            if !dark {
                Button {
                    searching.toggle()
                    if !searching { search = ""; searchFocus = false }
                } label: {
                    Image(systemName: searching ? "xmark" : "magnifyingglass")
                        .frame(width: 36, height: 36).overlay(Circle().strokeBorder(.quaternary))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .accessibilityLabel(searching ? "Close search" : "Search")
            }
        }.frame(minHeight: 44).padding(.leading, dark ? 20 : 8).padding(.trailing, 20)
    }

    private func open(_ value: MailScope) {
        if tab != .inbox || scope != value || unread { MobileHaptics.shared.selectionChanged() }
        scope = value; tab = .inbox; unread = false; searching = false; search = ""
    }

    private func showBoxes() {
        if tab != .boxes { MobileHaptics.shared.selectionChanged() }
        tab = .boxes
        searchFocus = false
    }

    @ViewBuilder private var mailboxMenu: some View {
        let tabs = HStack(spacing: 2) {
            tabButton(.inbox, "Inbox", "tray")
            tabButton(.boxes, "Mailboxes", "tray.2")
        }
        .padding(4)

        if #available(iOS 26, *) {
            tabs.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            tabs.background(.regularMaterial, in: Capsule())
        }
    }

    private func tabButton(_ value: MobileTab, _ text: LocalizedStringKey, _ symbol: String) -> some View {
        let selected = tab == value
        let hasUnread = value == .inbox && store.hasUnread(in: .all)
        return Button { if value == .inbox { open(.all) } else { showBoxes() } } label: {
            Label {
                Text(text)
            } icon: {
                Image(systemName: selected ? symbol + ".fill" : symbol)
                    .overlay(alignment: .topTrailing) {
                        if hasUnread { MailboxUnreadDot().offset(x: 3, y: -2) }
                    }
            }
                .font(.subheadline.weight(selected ? .bold : .medium))
                .padding(.horizontal, 17).frame(minHeight: 44)
                .foregroundStyle(.primary)
                .background {
                    if selected { Capsule().fill(.primary.opacity(0.13)) }
                }
                .contentShape(Capsule())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityValue(hasUnread ? "Unread messages" : "")
    }

    @ViewBuilder private func inboxContent(height: CGFloat) -> some View {
        if searching {
            TextField("Search reports", text: $search).textFieldStyle(.plain).focused($searchFocus)
                .onAppear { searchFocus = true }
                .submitLabel(.search).onSubmit { searchFocus = false }
                .padding(12).background(Color(white: 0.95), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 21).padding(.bottom, 8)
        }
        let scoped = allNotes
        HStack(spacing: 7) {
            filter("All", active: !unread) { unread = false }
            filter("Unread  \(scoped.filter { !$0.isRead }.count)", active: unread) { unread = true }
        }.padding(.horizontal, 21).padding(.bottom, 9)
        if let error = store.syncError, !store.notes.isEmpty {
            HStack { Text(LocalizedStringKey(error)); Spacer(); Button("Refresh") { Task { await store.refresh() } } }
                .font(.footnote).padding(.horizontal, 21).padding(.vertical, 8)
        }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = query.isEmpty ? scoped : scoped.filter { note in
            note.title.localizedCaseInsensitiveContains(query) || note.text.localizedCaseInsensitiveContains(query)
                || (store.agent(for: note)?.rawValue ?? note.sourceApp ?? "").localizedCaseInsensitiveContains(query)
        }
        let items = unread ? matches.filter { !$0.isRead } : matches
        if items.isEmpty {
            if store.isLoading && store.notes.isEmpty && store.syncError == nil {
                ProgressView("Receiving messages…").frame(maxWidth: .infinity).padding(25)
            } else {
                emptyMailbox(query: query, hasMatches: !matches.isEmpty)
                    .padding(.top, searchFocus ? 8 : min(100, max(20, (height - 300) * 0.19)))
                    .padding(.bottom, 18)
            }
        } else {
            let sections = Dictionary(grouping: items) { Calendar.current.startOfDay(for: $0.createdAt) }
            ForEach(sections.keys.sorted(by: >), id: \.self) { day in
                MobileSectionLine(title: Calendar.current.isDateInToday(day) ? "Today" : Calendar.current.isDateInYesterday(day) ? "Yesterday" : day.formatted(.dateTime.day().month(.wide).year().locale(locale)))
                ForEach((sections[day] ?? []).sorted { $0.createdAt > $1.createdAt }) { note in
                    Button {
                        guard !railOpen else { return }
                        navigation.append(note.id); store.markRead(note)
                    } label: { MobileMessageRow(note: note, agent: store.agent(for: note)) }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    @ViewBuilder private func emptyMailbox(query: String, hasMatches: Bool) -> some View {
        if let error = store.syncError, store.notes.isEmpty {
            MobileEmptyState(artwork: .document, title: "Inbox unavailable", detail: error,
                             actionTitle: "Try again") { Task { await store.refresh() } }
        } else if unread && hasMatches {
            MobileEmptyState(artwork: .read, title: query.isEmpty ? "You’re all caught up" : "These messages have been read",
                             detail: query.isEmpty ? "New unread messages will appear here."
                                                   : "The messages matching your search have already been read.",
                             compact: searchFocus, actionTitle: query.isEmpty ? "Show all messages" : "Show all matches") {
                MobileHaptics.shared.selectionChanged()
                unread = false
            }
        } else if !query.isEmpty {
            MobileEmptyState(artwork: .search, title: "No results",
                             detail: "Try another word or an agent’s name.",
                             compact: searchFocus, actionTitle: "Clear search") {
                MobileHaptics.shared.selectionChanged()
                search = ""
                searchFocus = true
            }
        } else {
            switch scope {
            case .all:
                MobileFirstMessage(agent: nil)
            case .agent(let agent):
                MobileFirstMessage(agent: agent).id(agent)
            case .folder(let id):
                let mailbox = store.folders.first { $0.id == id }?.mailbox.flatMap(InboxAgent.init(rawValue:))
                let candidates = mailbox.map { store.notes(in: $0) } ?? store.notes.filter { !$0.isDailyNote }
                MobileEmptyState(artwork: .folder, title: "No messages in this folder",
                                 detail: "To file a message here, open it and tap the folder icon.",
                                 actionTitle: candidates.isEmpty ? nil : "Choose a message") {
                    open(mailbox.map(MailScope.agent) ?? .all)
                }
            }
        }
    }

    private func filter(_ text: LocalizedStringKey, active: Bool, action: @escaping () -> Void) -> some View {
        Button {
            guard !active else { return }
            MobileHaptics.shared.selectionChanged()
            action()
        } label: { Text(text).font(.subheadline.weight(.medium))
            .foregroundStyle(active ? .white : .black).padding(.horizontal, 15).padding(.vertical, 7)
            .background(active ? MobileStyle.graphite : Color(white: 0.95), in: Capsule())
            .frame(minHeight: 44) }.buttonStyle(.plain).accessibilityAddTraits(active ? .isSelected : [])
    }

    @ViewBuilder private var boxesContent: some View {
        let allUnread = store.hasUnread(in: .all)
        Button { open(.all) } label: {
            HStack {
                Label("All messages", systemImage: "tray.2")
                Spacer()
                if allUnread { MailboxUnreadDot() }
                Text("\(store.notes(in: .all).count)").foregroundStyle(.secondary)
            }
                .font(.subheadline.weight(.semibold)).padding(14).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
        }.accessibilityValue(allUnread ? "Unread messages" : "")
        .padding(.horizontal, 20).padding(.bottom, 16)
        MobileSectionLine(title: "Agents")
        ForEach(InboxAgent.mobileMailboxOrder, id: \.self) { agent in
            let isOpen = expanded == agent
            let agentNotes = store.notes(in: agent)
            let agentUnread = agentNotes.contains { !$0.isRead }
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    MobileHaptics.shared.selectionChanged()
                    withAnimation(.easeOut(duration: 0.16)) { expanded = isOpen ? nil : agent }
                } label: {
                    HStack(spacing: 10) {
                        MobileAgentMark(agent: agent, dark: true); Text(agent.rawValue).fontWeight(.semibold); Spacer()
                        if agentUnread { MailboxUnreadDot() }
                        Text("\(agentNotes.count)").foregroundStyle(.secondary)
                        Image(systemName: isOpen ? "chevron.down" : "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }.frame(minHeight: 48).contentShape(Rectangle())
                }
                .accessibilityValue(agentUnread ? "Unread messages" : "")
                if isOpen {
                    boxRow(VellemLanguage.format("All %@ messages", agent.rawValue, locale: locale), "tray", hasUnread: agentUnread) { open(.agent(agent)) }
                    ForEach(store.agentFolders(agent)) { f in
                        boxRow(f.name, "folder", hasUnread: store.hasUnread(in: .folder(f.id))) { open(.folder(f.id)) }
                    }
                    boxRow(VellemLanguage.text("New folder", locale: locale), "plus") { folderName = ""; makingFolder = true }
                }
            }.font(.subheadline).padding(.horizontal, 10).padding(.bottom, isOpen ? 5 : 0)
            .background(isOpen ? .white.opacity(0.055) : .clear, in: RoundedRectangle(cornerRadius: 12))
            .overlay { if isOpen { RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.13)) } }
            .padding(.horizontal, 19)
        }
        let general = store.folders.filter { !$0.isSmart && $0.mailbox == nil }
        if !general.isEmpty {
            MobileSectionLine(title: "Shared folders")
            ForEach(general) { f in
                boxRow(f.name, "folder", hasUnread: store.hasUnread(in: .folder(f.id))) { open(.folder(f.id)) }
                    .padding(.horizontal, 18)
            }
        }
        MobileSectionLine(title: "Preferences")
        LanguagePicker()
            .font(.subheadline).padding(.horizontal, 24).frame(minHeight: 44)
        Toggle(isOn: $hapticsEnabled) {
            Label("Haptic feedback", systemImage: "waveform")
        }
        .font(.subheadline).padding(.horizontal, 24).frame(minHeight: 44)
    }
    private func boxRow(_ text: String, _ icon: String, hasUnread: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(text, systemImage: icon).font(.subheadline)
                Spacer(minLength: 4)
                if hasUnread { MailboxUnreadDot().padding(.trailing, 4) }
            }.frame(minHeight: 44).padding(.leading, 33).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityValue(hasUnread ? "Unread messages" : "")
    }
}

enum MobileStyle { static let graphite = Color(red: 0.123, green: 0.128, blue: 0.118) }

struct MobileTopBarMaterial: View {
    let surface: Color
    let barHeight: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Group {
            if reduceTransparency {
                surface.frame(height: barHeight)
            } else {
                Rectangle().fill(.regularMaterial)
                    .overlay {
                        LinearGradient(colors: [surface, surface.opacity(0.9), surface.opacity(0.4)],
                                       startPoint: .top, endPoint: .bottom)
                    }
                    .mask {
                        LinearGradient(stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.46),
                            .init(color: .black.opacity(0.77), location: 0.67),
                            .init(color: .black.opacity(0.24), location: 0.87),
                            .init(color: .clear, location: 1)
                        ], startPoint: .top, endPoint: .bottom)
                    }
                    .frame(height: barHeight + 20)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct MobileSectionLine: View {
    let title: String
    var body: some View {
        HStack(spacing: 10) { Text(LocalizedStringKey(title)).font(.footnote.weight(.semibold)).foregroundStyle(.secondary); Rectangle().fill(.secondary.opacity(0.23)).frame(height: 0.5) }
            .padding(.horizontal, 22).padding(.vertical, 8).accessibilityAddTraits(.isHeader)
    }
}

struct MobileAgentMark: View {
    let agent: InboxAgent?
    var dark = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(dark ? Color(white: 0.21) : Color(white: 0.98))
            if let agent {
                Image("Inbox" + agent.rawValue).resizable().renderingMode(agent == .grokbot ? .original : .template)
                    .scaledToFit().padding(agent == .grokbot ? 2 : 5).foregroundStyle(dark ? .white : .black)
            } else { Image(systemName: "doc.text").font(.caption) }
        }.frame(width: 28, height: 28)
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.22), lineWidth: 0.6))
        .accessibilityHidden(true)
    }
}

private struct MobileMessageRow: View {
    let note: Note
    let agent: InboxAgent?
    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            MobileAgentMark(agent: agent)
            VStack(alignment: .leading, spacing: 4) {
                HStack { Text(agent?.rawValue ?? note.sourceApp ?? "Vellem").font(.footnote.weight(.semibold)).lineLimit(1)
                    Spacer(); Text(note.createdAt, format: .dateTime.hour().minute()).font(.caption).foregroundStyle(.secondary) }
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.title).font(.headline.weight(note.isRead ? .medium : .semibold)).lineLimit(2)
                        if !note.preview.isEmpty { Text(note.preview).font(.subheadline).lineLimit(2).foregroundStyle(.secondary) }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    if let url = MobileMessageThumbnail.first(in: note) { MobileMessageThumbnail(url: url) }
                }
                Divider().padding(.top, 9)
            }
        }.overlay(alignment: .topLeading) {
            if !note.isRead { Circle().frame(width: 5, height: 5).offset(x: -12, y: 11) }
        }.padding(.horizontal, 22).padding(.top, 10).contentShape(Rectangle())
        .accessibilityElement(children: .combine).accessibilityValue(note.isRead ? "" : "Unread message")
    }
}
