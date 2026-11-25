import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct MobileMessageDocument: UIViewRepresentable {
    @Environment(\.locale) var locale
    let note: Note
    let agent: InboxAgent?
    let folder: String
    let size: CGFloat
    let bottomInset: CGFloat
    let failure: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.setURLSchemeHandler(MobileAttachmentHandler(), forURLScheme: "vellem-image")
        config.userContentController.add(context.coordinator, name: "copyCode")
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.scrollView.contentInsetAdjustmentBehavior = .always
        if #available(iOS 26.0, *) { view.scrollView.topEdgeEffect.style = .soft }
        context.coordinator.current = self
        if let page = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "ReaderResources") {
            context.coordinator.page = page; view.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        } else { DispatchQueue.main.async { failure() } }
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        if view.scrollView.contentInset.bottom != bottomInset {
            view.scrollView.contentInset.bottom = bottomInset
            view.scrollView.verticalScrollIndicatorInsets.bottom = bottomInset
        }
        context.coordinator.current = self
        context.coordinator.update(view)
    }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.configuration.userContentController.removeScriptMessageHandler(forName: "copyCode"); view.navigationDelegate = nil; view.stopLoading()
    }
    @MainActor final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var page: URL?
        var current: MobileMessageDocument?
        private var ready = false
        private var displayed: Note?
        private var displayedLocale: Locale?
        private var folder = "", sender = "", size: CGFloat = 0
        private static var icons = [String: String]()
        func update(_ view: WKWebView) {
            guard ready, let current else { return }
            let n = current.note, author = current.agent?.rawValue ?? n.sourceApp ?? "Vellem"
            guard displayedLocale != current.locale || displayed != n || folder != current.folder || sender != author || size != current.size else { return }
            displayedLocale = current.locale
            displayed = n; folder = current.folder; sender = author; size = current.size
            let name = current.agent.map { "Inbox" + $0.rawValue }
            var icon = name.flatMap { Self.icons[$0] } ?? ""
            if icon.isEmpty, let name, var image = UIImage(named: name) {
                if current.agent != .grokbot { image = image.withTintColor(.black, renderingMode: .alwaysOriginal) }
                let rendered = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).image { _ in image.draw(in: CGRect(x: 3, y: 3, width: 26, height: 26)) }
                if let png = rendered.pngData() { icon = "data:image/png;base64," + png.base64EncodedString(); Self.icons[name] = icon }
            }
            let item: [String: Any] = ["id":n.id.uuidString,"title":n.title,"text":n.text,"envelope":true,"format":n.outputFormat?.rawValue ?? "markdown",
                "sender":author,"folder":folder,"date":n.createdAt.formatted(.dateTime.day().month(.abbreviated).hour().minute().locale(current.locale)),
                "language":current.locale.language.languageCode?.identifier ?? "en","labels":VellemLanguage.readerLabels(locale: current.locale),
                "you":VellemLanguage.text("You", locale: current.locale),"icon":icon,"replies":(n.replies ?? []).map { ["id":$0.id.uuidString,"question":$0.question,"answer":$0.delivery == nil ? $0.answer : VellemLanguage.serviceMessage($0.answer, locale: current.locale),"delivery":$0.delivery?.rawValue ?? "completed"] }]
            view.callAsyncJavaScript("""
                document.documentElement.classList.add('mobile');
                const head = document.getElementById('envelope');
                head.prepend(head.querySelector('.byline'));
                readerAppearance(size, false); renderMessage(item);
                """, arguments: ["item":item,"size":Double(size)], in: nil, in: .page) { [weak self] result in
                if case .failure = result { self?.current?.failure() }
            }
        }
        func webView(_ view: WKWebView, didFinish navigation: WKNavigation!) { ready = true; update(view) }
        func webViewWebContentProcessDidTerminate(_ view: WKWebView) { current?.failure() }
        func webView(_ view: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled { current?.failure() }
        }
        func webView(_ view: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url else { decisionHandler(.cancel); return }
            if url.isFileURL, url.standardizedFileURL.path == page?.standardizedFileURL.path, action.targetFrame?.isMainFrame == true { decisionHandler(.allow); return }
            decisionHandler(.cancel)
            if action.navigationType == .linkActivated, ["https","http","mailto"].contains(url.scheme?.lowercased() ?? "") { UIApplication.shared.open(url) }
        }
        func userContentController(_ controller: WKUserContentController, didReceive msg: WKScriptMessage) {
            if msg.name == "copyCode", msg.frameInfo.isMainFrame, let text = msg.body as? String {
                UIPasteboard.general.string = text
                MobileHaptics.shared.confirm()
            }
        }
    }
}

@MainActor private final class MobileAttachmentHandler: NSObject, WKURLSchemeHandler {
    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        let key = ObjectIdentifier(task), url = task.request.url
        tasks[key] = Task {
            defer { tasks[key] = nil }
            do {
                guard let url, let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "path" })?.value else { throw CocoaError(.fileNoSuchFile) }
                let (bytes, mime) = try await Task.detached(priority: .utility) { try MobileAttachment.load(path) }.value
                guard !Task.isCancelled else { return }
                task.didReceive(URLResponse(url: url, mimeType: mime, expectedContentLength: bytes.count, textEncodingName: nil))
                task.didReceive(bytes); task.didFinish()
            } catch { if !Task.isCancelled { task.didFailWithError(error) } }
        }
    }
    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) { tasks.removeValue(forKey: ObjectIdentifier(task))?.cancel() }
}

enum MobileAttachment {
    static func load(_ path: String) throws -> (Data, String) {
        guard let root = CloudMirrorStore.containerURL?.appending(path: "Attachments").resolvingSymlinksInPath() else { throw CloudMirrorError.unavailable }
        var parts = path.split(separator: "/").map(String.init)
        if let index = parts.firstIndex(of: "Attachments") { parts = Array(parts.dropFirst(index + 1)) }
        else if path.hasPrefix("/") { throw CocoaError(.fileReadNoPermission) }
        guard !parts.isEmpty, !parts.contains(".."), !parts.contains(".") else { throw CocoaError(.fileReadNoPermission) }
        let file = root.appending(path: parts.joined(separator: "/")).standardizedFileURL.resolvingSymlinksInPath()
        guard file.path.hasPrefix(root.path + "/"), let type = UTType(filenameExtension: file.pathExtension), type.conforms(to: .image),
              let mime = type.preferredMIMEType else { throw CocoaError(.fileReadNoPermission) }
        try CloudMirrorStore.startDownloadingIfNeeded(file)
        return (try CloudMirrorStore.coordinatedRead(from: file), mime)
    }
}

struct MobileMessageThumbnail: View {
    let url: URL
    @State private var image: UIImage?
    private static let cache = NSCache<NSURL, UIImage>()

    static func first(in note: Note) -> URL? {
        guard note.outputFormat == nil || note.outputFormat == .markdown,
              let start = note.text.range(of: "!["), let end = note.text[start.upperBound...].range(of: "]("),
              let close = note.text[end.upperBound...].firstIndex(of: ")") else { return nil }
        let destination = note.text[end.upperBound..<close].split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
        guard let url = URL(string: destination.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))),
              url.isFileURL || (url.scheme == nil && url.path.hasPrefix("Attachments/")) else { return nil }
        return url
    }
    var body: some View {
        ZStack {
            Color.clear.frame(width: 0, height: 0)
            if let image {
                Image(uiImage: image).resizable().scaledToFill().frame(width: 52, height: 49)
                    .clipShape(RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.secondary.opacity(0.15)))
            }
        }.task(id: url) {
            if let cached = Self.cache.object(forKey: url as NSURL) { image = cached; return }
            let path = url.path
            let bitmap = await Task.detached(priority: .utility) { () -> CGImage? in
                guard let (data, _) = try? MobileAttachment.load(path),
                      let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
                return CGImageSourceCreateThumbnailAtIndex(source, 0, [
                    kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: 156] as CFDictionary)
            }.value
            guard let bitmap, !Task.isCancelled else { return }
            let result = UIImage(cgImage: bitmap); Self.cache.countLimit = 100
            Self.cache.setObject(result, forKey: url as NSURL); image = result
        }.accessibilityHidden(true)
    }
}
