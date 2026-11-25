import Foundation

enum VellemLanguage: String, CaseIterable {
    case system, en, fr

    static let preferenceKey = "interfaceLanguage"

    static var defaults: UserDefaults {
        #if os(macOS)
        UserDefaults(suiteName: "MKAFV9VL9V.com.adriendonot.Vellem") ?? .standard
        #else
        .standard
        #endif
    }

    static var current: Self {
        defaults.string(forKey: preferenceKey).flatMap(Self.init(rawValue:)) ?? .system
    }

    var locale: Locale {
        let language = self == .system
            ? Bundle.preferredLocalizations(from: ["en", "fr"], forPreferences: Locale.preferredLanguages).first ?? "en"
            : rawValue
        var components = Locale.Components(locale: .autoupdatingCurrent)
        components.languageComponents = Locale.Language.Components(identifier: language)
        components.region = Locale.autoupdatingCurrent.region
        return Locale(components: components)
    }

    private static let bundles: [String: Bundle] = Dictionary(uniqueKeysWithValues: ["en", "fr"].compactMap { code in
        guard let url = Bundle.main.url(forResource: code, withExtension: "lproj"),
              let bundle = Bundle(url: url) else { return nil }
        return (code, bundle)
    })

    static func text(_ key: String, locale: Locale = current.locale, table: String? = nil) -> String {
        let code = locale.language.languageCode?.identifier ?? "en"
        let bundle = bundles[code] ?? .main
        return bundle.localizedString(forKey: key, value: key, table: table)
    }

    static func format(_ key: String, _ arguments: CVarArg..., locale: Locale = current.locale) -> String {
        String(format: text(key, locale: locale), locale: locale, arguments: arguments)
    }

    // Older replies store the service's diagnostic in the language it was written in.
    // Localize that status for this device without modifying the shared conversation.
    static func serviceMessage(_ message: String, locale: Locale) -> String {
        if let match = message.wholeMatch(of: /^Codex n’a pas terminé la réponse( \(code -?\d+\))?\. Ouvre la conversation dans Codex pour voir son état\.$/) {
            return format("Codex didn’t finish the reply%@. Open the conversation in Codex to check its status.",
                          String(match.1 ?? ""), locale: locale)
        }
        if let match = message.wholeMatch(of: /^Install the (.+) CLI on this Mac to reply\.$/) {
            return format("Install the %@ CLI on this Mac to reply.", String(match.1), locale: locale)
        }
        if let match = message.wholeMatch(of: /^(.+) couldn’t finish the reply\. Check the CLI’s sign-in and the original conversation\.$/) {
            return format("%@ couldn’t finish the reply. Check the CLI’s sign-in and the original conversation.", String(match.1), locale: locale)
        }
        return text(message, locale: locale)
    }

    static func readerLabels(locale: Locale) -> [String: String] {
        let keys = ["Wrap lines", "Copy", "Copied", "Completed", "Not completed", "Image unavailable", "Table", "Code"]
        return Dictionary(uniqueKeysWithValues: keys.map { ($0, text($0, locale: locale)) })
    }
}
