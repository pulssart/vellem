import SwiftUI

struct MobileNoteDetail: View {
    @ObservedObject var store: MobileNotesStore
    let note: Note
    @State private var sheet: Sheet?
    @State private var draft = ""
    @State private var replyBarHeight: CGFloat = 0
    @State private var readerFailed = false
    @State private var copyToken: UUID?
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .body) private var readerSize = 17.0
    private enum Sheet: String, Identifiable { case reply, move; var id: Self { self } }
    private var agent: InboxAgent? { store.agent(for: note) }
    private var folder: String { store.folders.first { $0.id == note.folderID }?.name ?? "" }
    private var pending: [MobileNotesStore.Pending] {
        store.pending.filter { item in
            if case .reply(let id, _) = item.action.kind { return note.id == id }
            return false
        }
    }
    var body: some View {
        GeometryReader { viewport in
            let topInset = viewport.safeAreaInsets.top
            ZStack(alignment: .bottom) {
                reader(topInset: topInset)
                    .overlay(alignment: .top) {
                        MobileTopBarMaterial(surface: .white, barHeight: topInset)
                    }
                    .ignoresSafeArea(.container, edges: note.conversation == nil ? .top : .vertical)

                if let conversation = note.conversation {
                    replyBar(for: conversation)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { replyBarHeight = $0 }
                }
            }
        }
        .background(.white).navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                // A custom toolbar item keeps UIKit from flattening the animated sheets to one symbol.
                HStack(spacing: 0) {
                    Button {
                        UIPasteboard.general.string = note.text
                        MobileHaptics.shared.confirm()
                        copyToken = UUID()
                        UIAccessibility.post(notification: .announcement, argument: VellemLanguage.text("Text copied", locale: locale))
                    } label: {
                        MessageCopyLabel(token: copyToken, confirmation: "Text copied")
                            .labelStyle(.iconOnly)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("copyMessage")
                }
                Button { sheet = .move } label: { Label("File report", systemImage: "folder") }
            }
        }
        .task(id: copyToken) {
            guard copyToken != nil else { return }
            do { try await Task.sleep(for: .seconds(1.5)) } catch { return }
            copyToken = nil
        }
        .onChange(of: note.id) { _, _ in copyToken = nil }
        .sheet(item: $sheet) { selected in
            NavigationStack {
                if selected == .reply {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(note.conversation?.provider == .codex
                                 ? "Via your Mac. An open Codex chat uses its own permissions."
                                 : "In the original conversation, via your Mac.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        TextField("Your reply…", text: $draft, axis: .vertical)
                            .lineLimit(3...8).padding(12).background(Color(white: 0.96), in: RoundedRectangle(cornerRadius: 13))
                            .onChange(of: draft) { _, text in UserDefaults.standard.set(text, forKey: draftKey) }
                        Button("Send") {
                            guard store.send(draft, to: note) else {
                                MobileHaptics.shared.notify(.error)
                                return
                            }
                            MobileHaptics.shared.confirm()
                            draft = ""; UserDefaults.standard.removeObject(forKey: draftKey); sheet = nil
                        }.buttonStyle(.borderedProminent).tint(.black).disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Spacer()
                    }.padding(20).navigationTitle(VellemLanguage.format("Reply to %@", note.conversation?.provider.rawValue ?? VellemLanguage.text("the agent", locale: locale), locale: locale))
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { sheet = nil } } }
                } else {
                    let choices = store.folders.filter { !$0.isSmart && ($0.mailbox == nil || $0.mailbox == agent?.rawValue) }
                    List {
                        moveRow(VellemLanguage.text("No folder", locale: locale), id: nil)
                        ForEach(choices.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { f in moveRow(f.name, id: f.id) }
                    }.navigationTitle("File report")
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { sheet = nil } } }
                }
            }.tint(.black).presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder private func reader(topInset: CGFloat) -> some View {
        if readerFailed {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(note.title).font(.system(.largeTitle, design: .serif, weight: .bold))
                    Text(verbatim: note.text)
                    ForEach(note.replies ?? []) { turn in
                        Divider(); Text(verbatim: turn.question).bold(); Text(verbatim: turn.delivery == nil ? turn.answer : VellemLanguage.serviceMessage(turn.answer, locale: locale))
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(22).textSelection(.enabled)
            }
            .contentMargins(.top, topInset, for: .scrollContent)
            .contentMargins(.bottom, readerBottomInset)
        } else {
            MobileMessageDocument(note: note, agent: agent, folder: folder, size: readerSize,
                                  bottomInset: readerBottomInset) { readerFailed = true }
        }
    }

    private var readerBottomInset: CGFloat { note.conversation == nil ? 0 : replyBarHeight }

    private func replyBar(for conversation: ReplyConversation) -> some View {
        VStack(spacing: 6) {
            ForEach(pending) { item in
                if case .reply(_, let text) = item.action.kind {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(verbatim: text).lineLimit(2)
                            Text(item.error.map { VellemLanguage.serviceMessage($0, locale: locale) } ?? VellemLanguage.text("Waiting for your Mac", locale: locale)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if item.error != nil {
                            Button("Resume") { draft = text; store.dismiss(item); sheet = .reply }
                        }
                    }
                    .font(.footnote)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            let button = Button {
                draft = UserDefaults.standard.string(forKey: draftKey) ?? ""
                sheet = .reply
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "arrowshape.turn.up.left")
                    Text("Reply to \(conversation.provider.rawValue)…")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption).accessibilityHidden(true)
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("replyToMessage")

            if #available(iOS 26, *) {
                button.buttonStyle(.glass).buttonBorderShape(.capsule).controlSize(.large)
            } else {
                button.buttonStyle(MaterialReplyButtonStyle())
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 7)
    }

    private var draftKey: String { "mobileReplyDraft." + note.id.uuidString }
    private func moveRow(_ title: String, id: UUID?) -> some View {
        Button {
            if store.move(note, to: id) { MobileHaptics.shared.notify(.success) }
            sheet = nil
        } label: {
            HStack { Label(title, systemImage: "folder"); Spacer(); if note.folderID == id { Image(systemName: "checkmark") } }
        }
    }
}

private struct MaterialReplyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16).frame(minHeight: 46)
            .background(.regularMaterial, in: Capsule())
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
