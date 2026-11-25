import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct MarkdownRenderedView: View {
    let note: Note
    var textSizeStep = 0
    var showsEnvelope = false
    var agent: InboxAgent?
    var folderName: String?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale
    @State private var unavailable = false

    var body: some View {
        if unavailable {
            ScrollView {
                VStack(alignment: .leading) {
                    if showsEnvelope { InboxEnvelope(note: note, agent: agent, folder: folderName) }
                    Text(verbatim: note.text)
                        .font(.system(size: CGFloat(16 + 2 * textSizeStep)))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(note.replies ?? []) { reply in
                        Divider()
                        Text(verbatim: reply.question).font(.headline)
                        Text(verbatim: reply.delivery == nil ? reply.answer : VellemLanguage.serviceMessage(reply.answer, locale: locale))
                    }
                }
                .padding(24)
            }
            .textSelection(.enabled)
        } else {
            MessageDocumentView(
                content: ReaderContent(note: note, envelope: showsEnvelope, agent: agent, folder: folderName, locale: locale),
                size: 16 + 2 * textSizeStep, dark: colorScheme == .dark,
                onFailure: { unavailable = true }
            )
        }
    }
}

private struct ReaderContent: Equatable {
    let id: UUID
    let text: String
    let title: String
    let format: String
    let envelope: Bool
    let agent: InboxAgent?
    let sender: String
    let folder: String
    let locale: Locale
    let date: String
    let replies: [NoteReply]

    init(note: Note, envelope: Bool, agent: InboxAgent?, folder: String?, locale: Locale) {
        self.locale = locale
        id = note.id
        replies = note.replies ?? []
        text = note.text
        title = note.title
        format = note.outputFormat?.rawValue ?? "markdown"
        self.envelope = envelope
        self.agent = agent
        sender = agent?.rawValue ?? note.inboxSender
        self.folder = folder ?? note.sourceURL?.host ?? ""
        date = note.updatedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute().locale(locale))
    }
}

private struct MessageDocumentView: NSViewRepresentable {
    let content: ReaderContent
    let size: Int
    let dark: Bool
    let onFailure: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(ReaderImageHandler(), forURLScheme: "vellem-image")
        configuration.userContentController.add(context.coordinator, name: "copyCode")
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        context.coordinator.update(self, in: view)
        if let page = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "ReaderResources") {
            context.coordinator.page = page
            view.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        } else {
            DispatchQueue.main.async { onFailure() }
        }
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) { context.coordinator.update(self, in: view) }

    static func dismantleNSView(_ view: WKWebView, coordinator: Coordinator) {
        view.navigationDelegate = nil
        view.configuration.userContentController.removeScriptMessageHandler(forName: "copyCode")
        view.stopLoading()
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var page: URL?
        private var pending: MessageDocumentView?
        private var displayed: ReaderContent?
        private var currentSize: Int?
        private var currentDark: Bool?
        private var ready = false
        private var retried = false
        private static var icons = [String: String]()

        func update(_ reader: MessageDocumentView, in webView: WKWebView) {
            pending = reader
            guard ready else { return }
            let appearanceChanged = currentDark != reader.dark || currentSize != reader.size
            let reload = displayed != reader.content || currentDark != reader.dark
            guard appearanceChanged || reload else { return }
            let item = reader.content
            var args: [String: Any] = ["size": reader.size, "dark": reader.dark]
            var script = "readerAppearance(size, dark);"
            if reload {
                args["item"] = [
                    "id": item.id.uuidString, "you": VellemLanguage.text("You", locale: item.locale),
                    "language": item.locale.language.languageCode?.identifier ?? "en", "labels": VellemLanguage.readerLabels(locale: item.locale),
                    "replies": item.replies.map { ["id": $0.id.uuidString, "question": $0.question, "answer": $0.delivery == nil ? $0.answer : VellemLanguage.serviceMessage($0.answer, locale: item.locale), "delivery": $0.delivery?.rawValue ?? "completed"] },
                    "text": item.text, "title": item.title, "format": item.format,
                    "envelope": item.envelope, "sender": item.sender, "folder": item.folder, "date": item.date,
                    "icon": item.envelope ? Self.icon(for: item.agent, dark: reader.dark) : ""
                ] as [String: Any]
                script += "renderMessage(item);"
            }
            currentSize = reader.size
            currentDark = reader.dark
            displayed = item
            webView.callAsyncJavaScript(script, arguments: args, in: nil, in: .page) { [weak self] result in
                if case .failure = result, self?.displayed?.id == item.id { self?.pending?.onFailure() }
            }
        }

        private static func icon(for agent: InboxAgent?, dark: Bool) -> String {
            let key = (agent?.rawValue ?? "") + (dark ? ".dark" : ".light")
            if let cached = icons[key] { return cached }
            let renderer = ImageRenderer(content: AgentMark(agent: agent, size: 34)
                .environment(\.colorScheme, dark ? .dark : .light))
            renderer.scale = 2
            guard let image = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else { return "" }
            let uri = "data:image/png;base64," + png.base64EncodedString()
            icons[key] = uri
            return uri
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            ready = true
            if let pending { update(pending, in: webView) }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { pending?.onFailure() }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            guard let page, !retried else { pending?.onFailure(); return }
            retried = true
            ready = false
            displayed = nil
            currentSize = nil
            webView.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, message.name == "copyCode", let text = message.body as? String else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url else { decisionHandler(.cancel); return }
            if url.isFileURL, url.path == page?.path, action.targetFrame?.isMainFrame == true {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)
                if action.navigationType == .linkActivated, ["https", "http", "mailto"].contains(url.scheme?.lowercased()) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

private final class ReaderImageHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        do {
            guard let url = task.request.url, url.host == "attachment",
                  let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "path" })?.value
            else { throw CocoaError(.fileReadInvalidFileName) }
            let root = AppGroup.attachmentsURL.resolvingSymlinksInPath().standardizedFileURL
            let relativePath = path.hasPrefix("Attachments/") ? String(path.dropFirst("Attachments/".count)) : path
            let file = (path.hasPrefix("/") ? URL(fileURLWithPath: path) : root.appendingPathComponent(relativePath))
                .resolvingSymlinksInPath().standardizedFileURL
            guard file.path.hasPrefix(root.path + "/"),
                  let type = UTType(filenameExtension: file.pathExtension), type.conforms(to: .image),
                  let mime = type.preferredMIMEType else { throw CocoaError(.fileReadNoPermission) }
            let data = try Data(contentsOf: file, options: .mappedIfSafe)
            task.didReceive(URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: nil))
            task.didReceive(data)
            task.didFinish()
        } catch {
            task.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}
