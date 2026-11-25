import Foundation

enum PromptCollection {
    case work, personal
}

enum PromptService: String, CaseIterable, Identifiable {
    case web = "Web"
    case granola = "Granola"
    case calendar = "Google Calendar"
    case slack = "Slack"
    case linear = "Linear"
    case notion = "Notion"
    case gmail = "Gmail"

    var id: Self { self }

    var imageName: String {
        self == .calendar ? "GoogleCalendar" : rawValue
    }
}

enum PromptRole: String, CaseIterable {
    case developer = "Developer"
    case productManager = "Product Manager"
    case productDesigner = "Product Designer"
    case coo = "COO"
    case cto = "CTO"
    case marketing = "Marketing"
    case customerSuccess = "Customer Success"
}

struct LibraryPrompt: Identifiable {
    enum Cover { case stack, tiles, sheet(String) }

    let id: String
    let title: String
    let summary: String
    let roles: [PromptRole]
    let services: [PromptService]
    let cover: Cover
    let hue: Double
    let text: String

    static func catalog(in collection: PromptCollection, locale: Locale) -> [LibraryPrompt] {
        func localized(_ key: String) -> String {
            VellemLanguage.text(key, locale: locale, table: "Prompts")
        }

        func prompt(_ id: String, _ roles: [PromptRole], _ services: [PromptService], _ cover: Cover, hue: Double, folder: String) -> LibraryPrompt {
            let destination = String(format: localized("delivery"), locale: locale, localized(folder))
            let text = [localized(id + ".instructions"), localized("sources"), destination].joined(separator: "\n\n")
            return LibraryPrompt(id: id, title: localized(id + ".title"), summary: localized(id + ".summary"),
                                 roles: roles, services: services, cover: cover, hue: hue, text: text)
        }

        if collection == .personal {
            func personal(_ id: String, _ services: [PromptService], _ cover: Cover, hue: Double) -> LibraryPrompt {
                prompt(id, [], services, cover, hue: hue, folder: "folder.personal")
            }

            return [
                personal("claim-check", [.web], .sheet("Original source"), hue: 32),
                personal("family-outing", [.web, .calendar], .tiles, hue: 183),
                personal("school-week", [.gmail, .calendar], .stack, hue: 315),
                personal("learn-a-topic", [.web], .sheet("Reading list"), hue: 234),
                personal("conflicting-reports", [.web], .sheet("Source comparison"), hue: 72),
                personal("purchase-recall", [.gmail, .web], .tiles, hue: 348),
                personal("repair-or-replace", [.web], .sheet("Repair estimate"), hue: 142),
                personal("seasonal-garden", [.web], .sheet("Planting calendar"), hue: 114),
                personal("pantry-meals", [.web], .sheet("Weekly menu"), hue: 18),
                personal("birthday-plan", [.calendar, .gmail], .stack, hue: 277),
                personal("subscription-renewals", [.gmail], .sheet("Renewal dates"), hue: 213),
                personal("home-quotes", [.gmail], .sheet("Quote comparison"), hue: 53),
            ]
        }

        return [
            prompt("design-review", [.productDesigner], [.notion, .linear], .sheet("Design review"), hue: 20, folder: "folder.product"),
            prompt("campaign-brief", [.marketing], [.granola, .notion], .stack, hue: 186, folder: "folder.marketing"),
            prompt("technical-risks", [.cto, .developer], [.linear, .notion], .tiles, hue: 308, folder: "folder.projects"),
            prompt("next-meeting", [.coo, .customerSuccess], [.calendar, .granola], .stack, hue: 0, folder: "folder.meetings"),
            prompt("ticket-origin", [.developer, .productManager, .productDesigner], [.linear, .slack], .tiles, hue: 58, folder: "folder.product"),
            prompt("spec-decisions", [.productManager, .productDesigner], [.granola, .notion], .sheet("Meeting decisions"), hue: 318, folder: "folder.product"),
            prompt("client-thread", [.customerSuccess], [.gmail, .slack], .stack, hue: 155, folder: "folder.customers"),
            prompt("project-status", [.productManager, .coo, .cto], [.notion, .linear], .tiles, hue: 275, folder: "folder.projects"),
            prompt("meeting-record", [.coo, .customerSuccess], [.granola], .sheet("Meeting notes"), hue: 215, folder: "folder.meetings"),
            prompt("research-patterns", [.productDesigner, .productManager, .marketing, .customerSuccess], [.granola, .gmail], .tiles, hue: 28, folder: "folder.research"),
            prompt("release-notes", [.developer, .productManager, .marketing], [.linear, .slack], .sheet("Release notes"), hue: 108, folder: "folder.releases"),
            prompt("travel-itinerary", [.coo], [.gmail, .calendar], .stack, hue: 187, folder: "folder.travel"),
            prompt("project-handoff", [.developer, .productDesigner, .coo], [.notion, .slack], .sheet("Project handoff"), hue: 248, folder: "folder.projects"),
            prompt("deadline-review", [.productManager, .coo, .cto], [.linear, .calendar], .tiles, hue: 350, folder: "folder.planning"),
            prompt("incident-timeline", [.developer, .cto], [.slack, .linear], .stack, hue: 78, folder: "folder.incidents"),
        ]
    }
}
