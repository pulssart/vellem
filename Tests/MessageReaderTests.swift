import AppKit
import WebKit

@MainActor
private final class CodeClipboard: NSObject, WKScriptMessageHandler {
    var text: String?

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        text = message.body as? String
    }
}

// Run with: swift Tests/MessageReaderTests.swift /path/to/Vellem.app
@MainActor
func checkReader(in app: URL) async throws {
    let resources = app.appendingPathComponent("Contents/Resources/ReaderResources")
    let configuration = WKWebViewConfiguration()
    let clipboard = CodeClipboard()
    configuration.userContentController.add(clipboard, name: "copyCode")
    let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 640, height: 700), configuration: configuration)
    let window = NSWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = view
    window.setFrameOrigin(NSPoint(x: -4000, y: -4000))
    window.orderBack(nil)
    defer { window.orderOut(nil) }
    view.loadFileURL(resources.appendingPathComponent("index.html"), allowingReadAccessTo: resources)
    let deadline = Date.now.addingTimeInterval(20)
    while view.isLoading && Date.now < deadline { try await Task.sleep(for: .milliseconds(30)) }

    func check(_ script: String, _ label: String) async throws {
        let passed = try await view.callAsyncJavaScript("return " + script, contentWorld: .page) as? Bool
        if passed != true { throw NSError(domain: "MessageReaderTests", code: 1, userInfo: [NSLocalizedDescriptionKey: label]) }
    }

    func show(_ text: String, _ format: String = "markdown") async throws {
        let item: [String: Any] = ["text": text, "format": format, "title": "Rapport", "envelope": true,
                                    "sender": "Codex", "folder": "", "date": "", "icon": ""]
        _ = try await view.callAsyncJavaScript("renderMessage(item);", arguments: ["item": item], contentWorld: .page)
    }

    for (language, copy) in [("fr", "Copier"), ("en", "Copy")] {
        let payload = "let language = \"français\""
        let item: [String: Any] = ["id": "same", "title": "Rapport", "text": payload, "format": "code",
                                   "language": language, "labels": ["Copy": copy]]
        let matches = try await view.callAsyncJavaScript("""
            renderMessage(item);
            return document.documentElement.lang === item.language &&
                document.querySelector('pre code').textContent === item.text &&
                Array.from(document.querySelectorAll('button')).some(button => button.textContent === item.labels.Copy);
            """, arguments: ["item": item], contentWorld: .page) as? Bool
        guard matches == true else { throw NSError(domain: "MessageReaderTests", code: 2) }
    }

    let example = #"""
    # Rapport

    ## Métriques de succès cibles

    Métrique | Objectif du trimestre pour le troisième lot à livrer | Q4
    :--- | :---: | ---:
    Latence de la recherche sémantique | < 150 ms | < 80 ms
    Adoption Memory Blocks par agents | — | 30 % des utilisateurs actifs
    Nom avec \| séparateur | [source](https://example.org) | **60 %**
    Libellé<br>sur deux lignes | A | B

    1. Premier
       * Détail
       * [x] Vérifié
       * [ ] À relire

    > Citation
    >
    > > Citation imbriquée

    ```swift
    let number = 3
    ```

    Une note de bas de page[^1].

    [^1]: Source de la mesure.

    <figure><figcaption>Une légende sur plusieurs lignes qui doit rester entièrement lisible dans le lecteur.</figcaption></figure>
    """#
    try await show(example)
    for dark in [false, true] {
        _ = try await view.callAsyncJavaScript("readerAppearance(16, dark);", arguments: ["dark": dark], contentWorld: .page)
        try await check("""
          [...message.querySelectorAll('a, th, .hljs-keyword, .hljs-number, .task-state')].every(element =>
            ['color', 'backgroundColor', 'borderTopColor'].every(property => {
              const [r, g, b] = getComputedStyle(element)[property].match(/[\\d.]+/g).map(Number);
              return r === g && g === b;
            })
          )
          """, "Neutral reader accents, dark mode \(dark)")
    }
    try await check("message.querySelectorAll('thead th').length === 3 && message.querySelectorAll('tbody tr').length === 4", "Markdown table")
    try await check("message.querySelector('thead th:last-child').align === 'right' && message.querySelector('tbody tr:nth-child(3) td').textContent.includes('|') && !!message.querySelector('td br')", "Alignment, escaped pipes and line breaks")
    try await check("!!message.querySelector('ol ul') && message.querySelectorAll('.task-state').length === 2 && !!message.querySelector('blockquote blockquote')", "Nested lists, tasks and quotations")
    try await check("!!message.querySelector('sup a') && !!message.querySelector('figcaption') && !message.querySelector('h1') && !!message.querySelector('pre .hljs-keyword')", "Footnotes, figures, title and code")
    for width in [320, 420, 640, 860] {
        window.setContentSize(NSSize(width: width, height: 700))
        _ = try await view.callAsyncJavaScript("return document.documentElement.clientWidth;", contentWorld: .page)
        for size in [16, 24, 32] {
            _ = try await view.callAsyncJavaScript("readerAppearance(size, false);", arguments: ["size": size], contentWorld: .page)
            try await check("getComputedStyle(message).fontSize === '\(size)px' && document.documentElement.scrollWidth <= window.innerWidth + 1", "Page fits width \(width), size \(size)")
            try await check("[...message.querySelectorAll('th,td,figcaption')].every(c => c.scrollHeight <= c.clientHeight + 1 && c.scrollWidth <= c.clientWidth + 1)", "Uncropped labels at \(width), size \(size)")
        }
    }

    try await show("<table><caption>Comparaison</caption><tr><th colspan='2'>Période</th></tr><tr><td>A</td><td>B</td></tr></table>")
    try await check("message.querySelector('th').colSpan === 2 && message.querySelector('caption').textContent === 'Comparaison'", "HTML table and caption")
    try await show(#"Une fraction $\frac{1}{2}$ et une somme \(x_1 + x_2\). Prix de 10 $ et 20 $."#)
    try await check("message.querySelectorAll('math').length === 2 && !!message.querySelector('mfrac') && !!message.querySelector('msub') && message.textContent.includes('10 $ et 20 $')", "Accessible mathematical notation and literal currency")
    try await show("![Une épreuve](file:///test/Attachments/sheet.png \"Légende de l’épreuve\")")
    try await check("!!message.querySelector('figure') && message.querySelector('figcaption').textContent === 'Légende de l’épreuve'", "Image captions")

    let wide = (1...12).map { "Colonne \($0)" }
    try await show([wide, wide.map { _ in "---" }, wide].map { $0.joined(separator: " | ") }.joined(separator: "\n"))
    try await check("message.querySelector('.table-scroll').scrollWidth > message.clientWidth && document.documentElement.scrollWidth <= window.innerWidth + 1", "Wide table scrolls locally")
    let json = #"{"identifiant":900719925474099312345,"valeur":1.200e-6,"clé":"a\\b","clé":"c"}"#
    try await show(json, "json")
    _ = try await view.callAsyncJavaScript("message.querySelector('button[aria-pressed]').click(); message.querySelector('.code-bar button:last-child').click();", contentWorld: .page)
    try await check("!!message.querySelector('pre.wrap') && !!message.querySelector('button[aria-pressed=true]')", "Wrap action")
    guard clipboard.text == json else { throw NSError(domain: "MessageReaderTests", code: 2,
                                                        userInfo: [NSLocalizedDescriptionKey: "Copy original JSON"]) }
    try await check("message.querySelector('pre').textContent.includes('900719925474099312345') && message.querySelector('pre').textContent.includes('1.200e-6') && message.querySelector('pre').textContent.includes('\\n') && message.querySelector('pre').textContent.split('clé').length === 3", "Lossless JSON display")
    try await show("{broken: 12", "json")
    try await check("message.querySelector('pre').textContent === '{broken: 12'", "Malformed JSON stays readable")
    try await show("<b>literal</b>\n  ## text", "text")
    try await check("message.textContent === '<b>literal</b>\\n  ## text' && !message.querySelector('b')", "Literal text")
    try await show("<b>code</b>\n  x", "code")
    try await check("message.querySelector('pre').textContent === '<b>code</b>\\n  x'", "Literal code")
    let conversation: [String: Any] = ["id": "report-1", "text": "Original output", "format": "text",
        "envelope": false, "title": "Report", "sender": "Claude", "you": "You", "folder": "", "date": "", "icon": "",
        "replies": [["id": "exchange", "question": "<i>Literal question</i>", "answer": "**Answer**"]]]
    _ = try await view.callAsyncJavaScript("renderMessage(item);", arguments: ["item": conversation], contentWorld: .page)
    try await check("message.textContent === 'Original output' && document.querySelector('#replies .plain-text').textContent === '<i>Literal question</i>' && document.querySelector('#replies article strong').textContent === 'Answer'", "Replies below the original output")
    for delivery in ["queued", "completed", "failed"] {
        _ = try await view.callAsyncJavaScript("""
            item.replies[0].delivery = delivery;
            item.replies[0].answer = 'En attente de la réponse du chat Codex…';
            renderMessage(item);
            """, arguments: ["item": conversation, "delivery": delivery], contentWorld: .page)
        let waiting = delivery == "queued"
        try await check("""
            (() => {
                const answer = document.querySelector('#replies article');
                const motion = matchMedia('(prefers-reduced-motion: no-preference) and (forced-colors: none)').matches;
                return answer.classList.contains('reply-pending') === \(waiting) &&
                    getComputedStyle(answer).animationName === (motion && \(waiting) ? 'reply-sheen' : 'none') &&
                    getComputedStyle(answer.previousElementSibling).animationName === 'none';
            })()
            """, "Only a queued reply animates, delivery \(delivery)")
    }
    try await show("Another report")
    try await check("!document.querySelector('#replies').childElementCount", "No thread leakage between reports")
    print("WebKit reader passed at four widths and three type sizes, including Markdown, HTML tables, captions, math, footnotes, code, JSON and text.")
}

NSApplication.shared.setActivationPolicy(.accessory)
Task { @MainActor in
    do {
        guard CommandLine.arguments.count == 2 else { throw CocoaError(.fileNoSuchFile) }
        try await checkReader(in: URL(fileURLWithPath: CommandLine.arguments[1]))
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
        exit(1)
    }
}
NSApplication.shared.run()
