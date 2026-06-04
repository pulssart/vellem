import SwiftUI

struct DecisionContextInspectorView: View {
    @ObservedObject var store: NotesStore
    let note: Note
    var close: () -> Void

    @State private var sourceDetail = ""
    @State private var capturedAt = Date()
    @State private var decisionTitle = ""
    @State private var effect: DecisionEffect = .influenced
    @State private var hasExpiration = false
    @State private var expiresAt = Date()
    @State private var validationRule = ""
    @State private var isResolved = false
    @State private var saveTask: Task<Void, Never>?
    @State private var analysisTask: Task<Void, Never>?
    @State private var isLoadingState = false
    @State private var analysisText: String?
    @State private var analysisError: String?
    @State private var isAnalyzing = false
    @State private var lastAnalyzedFields = ""
    @State private var isContextFieldsExpanded = false

    private let editor = FoundationNoteEditor()

    @AppAccent private var accent

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    analysisSection
                    contextFieldsSection
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            footer
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            load(from: note)
        }
        .onChange(of: note.id) {
            load(from: note)
        }
        .onChange(of: note.decisionContext) {
            load(from: note)
        }
        .onChange(of: sourceDetail) { fieldChanged() }
        .onChange(of: capturedAt) { fieldChanged() }
        .onChange(of: decisionTitle) { fieldChanged() }
        .onChange(of: effect) { fieldChanged() }
        .onChange(of: hasExpiration) { fieldChanged() }
        .onChange(of: expiresAt) { fieldChanged() }
        .onChange(of: validationRule) { fieldChanged() }
        .onChange(of: isResolved) { fieldChanged() }
        .onDisappear {
            flushSave()
            analysisTask?.cancel()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: headerSystemImage)
                .foregroundStyle(statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Decision")
                    .font(.headline)
                Text(headerDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: close) {
                Image(systemName: "xmark")
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .help("Close inspector")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(accent.color.opacity(0.16))
    }

    private var contextFieldsSection: some View {
        DisclosureGroup(isExpanded: $isContextFieldsExpanded) {
            VStack(alignment: .leading, spacing: 18) {
                sourceSection
                decisionSection
                expirationSection
                trailSection
            }
            .padding(.top, 12)
        } label: {
            Text("Decision details")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .help("Source, decision, expiration, and linked notes.")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.6))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        }
    }

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Source")

            fieldTitle(
                "Evidence",
                subtitle: "Where this idea came from. Add the link, person, file, or exact passage."
            )

            TextField("Source, link, person, file, or passage", text: $sourceDetail, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            DatePicker(selection: $capturedAt, displayedComponents: [.date, .hourAndMinute]) {
                fieldTitle(
                    "Captured",
                    subtitle: "When this mattered enough to save."
                )
            }
                .datePickerStyle(.compact)
        }
    }

    private var decisionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Decision")

            fieldTitle(
                "Decision influenced",
                subtitle: "The choice, direction, or question this note changed."
            )

            TextField("Decision influenced", text: $decisionTitle)
                .textFieldStyle(.roundedBorder)

            Picker(selection: $effect) {
                ForEach(DecisionEffect.allCases) { effect in
                    Text(effect.label).tag(effect)
                }
            } label: {
                fieldTitle(
                    "Effect",
                    subtitle: "How this note affected the decision."
                )
            }
            .pickerStyle(.menu)

            Toggle(isOn: $isResolved) {
                fieldTitle(
                    "Resolved",
                    subtitle: "Turn this on when the related decision is closed."
                )
            }
        }
    }

    private var expirationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Expiration")

            Toggle(isOn: $hasExpiration) {
                fieldTitle(
                    "Review later",
                    subtitle: "Use this when the note may stop being reliable."
                )
            }

            if hasExpiration {
                HStack(spacing: 8) {
                    quickExpirationButton("7 days", days: 7)
                    quickExpirationButton("30 days", days: 30)
                    quickExpirationButton("90 days", days: 90)
                }

                DatePicker(selection: $expiresAt, displayedComponents: [.date]) {
                    fieldTitle(
                        "Expires",
                        subtitle: "After this date, treat the note as something to verify again."
                    )
                }
                    .datePickerStyle(.compact)
            }

            fieldTitle(
                "Validation rule",
                subtitle: "What would make this context still true, or prove it outdated."
            )

            TextField("Validation rule", text: $validationRule, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
        }
    }

    private var trailSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Decision trail")
            fieldTitle(
                "Linked notes",
                subtitle: "Other notes connected to the same decision."
            )

            if relatedNotes.isEmpty {
                Text("No other notes linked to this decision.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(relatedNotes) { relatedNote in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(relatedNote.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)

                        if let context = relatedNote.decisionContext {
                            Label(context.effect.label, systemImage: context.status().systemImage)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var analysisSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Analysis")

            fieldTitle(
                "Natural language summary",
                subtitle: "Apple Foundation Models explains what these fields mean for a future decision."
            )

            if isAnalyzing {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Updating summary...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let analysisText {
                Text(analysisText)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
                    }
            }

            if let analysisError {
                Text(analysisError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Clear context", role: .destructive) {
                clearContext()
            }
            .disabled(note.decisionContext == nil && draftContext?.isEmpty != false)

            Spacer()

            Text(footerStatusText)
                .font(.caption.weight(.medium))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var headerDetail: String {
        let cleaned = decisionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "No decision linked yet" : cleaned
    }

    private var currentStatus: DecisionContextStatus {
        draftContext?.status() ?? .active
    }

    private var headerSystemImage: String {
        draftContext?.status().systemImage ?? "scope"
    }

    private var footerStatusText: String {
        draftContext == nil ? "No context" : currentStatus.label
    }

    private var statusColor: Color {
        guard draftContext != nil else {
            return .secondary
        }

        switch currentStatus {
        case .active:
            return accent.color
        case .needsReview:
            return .orange
        case .expired:
            return .red
        case .resolved:
            return .green
        }
    }

    private var relatedNotes: [Note] {
        guard draftContext?.isEmpty == false else { return [] }
        var draft = note
        draft.decisionContext = draftContext
        return store.decisionTrail(for: draft)
    }

    private var draftContext: NoteDecisionContext? {
        let context = NoteDecisionContext(
            sourceDetail: sourceDetail.trimmingCharacters(in: .whitespacesAndNewlines),
            capturedAt: capturedAt,
            decisionTitle: decisionTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            effect: effect,
            expiresAt: hasExpiration ? expiresAt : nil,
            validationRule: validationRule.trimmingCharacters(in: .whitespacesAndNewlines),
            resolvedAt: isResolved ? (note.decisionContext?.resolvedAt ?? .now) : nil,
            updatedAt: note.decisionContext?.updatedAt ?? .now
        )

        return context.isEmpty ? nil : context
    }

    private var decisionContextFieldsForAnalysis: String {
        let source = sourceDetail.trimmingCharacters(in: .whitespacesAndNewlines)
        let decision = decisionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let rule = validationRule.trimmingCharacters(in: .whitespacesAndNewlines)
        let linkedTitles = relatedNotes
            .prefix(5)
            .map(\.title)
            .joined(separator: ", ")

        return """
        Note title: \(note.title)
        Evidence: \(source.isEmpty ? "Empty" : source)
        Captured: \(Self.analysisDateFormatter.string(from: capturedAt))
        Decision influenced: \(decision.isEmpty ? "Empty" : decision)
        Effect: \(effect.label)
        Resolved: \(isResolved ? "Yes" : "No")
        Review later: \(hasExpiration ? "Yes" : "No")
        Expires: \(hasExpiration ? Self.analysisDateFormatter.string(from: expiresAt) : "No expiration")
        Validation rule: \(rule.isEmpty ? "Empty" : rule)
        Current status: \(footerStatusText)
        Linked notes: \(linkedTitles.isEmpty ? "None" : linkedTitles)
        """
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func fieldTitle(_ title: String, subtitle: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .help(subtitle)
    }

    private func quickExpirationButton(_ title: String, days: Int) -> some View {
        Button(title) {
            expiresAt = Calendar.current.date(byAdding: .day, value: days, to: .now) ?? .now
            hasExpiration = true
        }
        .buttonStyle(.borderless)
        .font(.caption.weight(.medium))
    }

    private func load(from note: Note) {
        isLoadingState = true
        analysisTask?.cancel()
        analysisText = nil
        analysisError = nil
        isAnalyzing = false
        lastAnalyzedFields = ""

        if let context = note.decisionContext {
            sourceDetail = context.sourceDetail
            capturedAt = context.capturedAt
            decisionTitle = context.decisionTitle
            effect = context.effect
            hasExpiration = context.expiresAt != nil
            expiresAt = context.expiresAt ?? defaultExpirationDate
            validationRule = context.validationRule
            isResolved = context.resolvedAt != nil
        } else {
            sourceDetail = sourceDescription(for: note) ?? ""
            capturedAt = note.createdAt
            decisionTitle = ""
            effect = .influenced
            hasExpiration = false
            expiresAt = defaultExpirationDate
            validationRule = ""
            isResolved = false
        }

        DispatchQueue.main.async {
            isLoadingState = false
            scheduleAnalysis()
        }
    }

    private func fieldChanged() {
        scheduleSave()
        scheduleAnalysis()
    }

    private func scheduleSave() {
        guard !isLoadingState else { return }
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                persist()
            }
        }
    }

    private func flushSave() {
        saveTask?.cancel()
        guard !isLoadingState else { return }
        persist()
    }

    private func persist() {
        guard var context = draftContext else {
            store.updateDecisionContext(nil, for: note.id)
            return
        }

        context.updatedAt = .now
        store.updateDecisionContext(context, for: note.id)
    }

    private func clearContext() {
        saveTask?.cancel()
        analysisTask?.cancel()
        isLoadingState = true
        analysisText = nil
        analysisError = nil
        isAnalyzing = false
        lastAnalyzedFields = ""
        sourceDetail = sourceDescription(for: note) ?? ""
        capturedAt = note.createdAt
        decisionTitle = ""
        effect = .influenced
        hasExpiration = false
        expiresAt = defaultExpirationDate
        validationRule = ""
        isResolved = false
        store.updateDecisionContext(nil, for: note.id)
        DispatchQueue.main.async {
            isLoadingState = false
            scheduleAnalysis()
        }
    }

    private var defaultExpirationDate: Date {
        Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
    }

    private func scheduleAnalysis() {
        guard !isLoadingState else { return }
        let fields = decisionContextFieldsForAnalysis
        guard fields != lastAnalyzedFields else { return }

        analysisTask?.cancel()
        analysisError = nil
        isAnalyzing = true

        analysisTask = Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }

            do {
                let result = try await editor.analyzeDecisionContext(fields)
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    lastAnalyzedFields = fields
                    analysisText = result
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    analysisError = error.localizedDescription
                    isAnalyzing = false
                }
            }
        }
    }

    private static let analysisDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private func sourceDescription(for note: Note) -> String? {
        switch (note.sourceApp, note.sourceURL) {
        case let (appName?, url?):
            return "\(appName), \(url.absoluteString)"
        case let (appName?, nil):
            return appName
        case let (nil, url?):
            return url.absoluteString
        case (nil, nil):
            return nil
        }
    }
}
