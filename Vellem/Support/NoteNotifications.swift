import AppKit
import Foundation
import os
import UserNotifications

enum NoteNotifications {
    private static let logger = Logger(subsystem: "com.adriendonot.Vellem", category: "notifications")

    static func requestAuthorization(delegate: UNUserNotificationCenterDelegate) {
        let center = UNUserNotificationCenter.current()
        center.delegate = delegate
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                logger.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
            } else {
                logger.info("Notification authorization granted: \(granted)")
            }
        }
    }

    static func notifyNewNote(_ note: Note, source: String) {
        let sourceLabel = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = body(for: note, source: sourceLabel.isEmpty ? "External capture" : sourceLabel)
        appendDiagnostic("notifyNewNote note=\(note.id.uuidString) source=\(sourceLabel)")
        deliverLegacyNotification(title: "New note in Vellem", body: body, noteID: note.id)

        let content = UNMutableNotificationContent()
        content.title = "New note in Vellem"
        content.body = body
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.userInfo = [
            ExternalNoteEvent.noteIDKey: note.id.uuidString
        ]

        let request = UNNotificationRequest(
            identifier: "vellem-note-\(note.id.uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                appendDiagnostic("UserNotifications failed note=\(note.id.uuidString) error=\(error.localizedDescription)")
                logger.error("UserNotifications delivery failed: \(error.localizedDescription, privacy: .public)")
            } else {
                appendDiagnostic("UserNotifications queued note=\(note.id.uuidString)")
                logger.info("UserNotifications request queued for note \(note.id.uuidString, privacy: .public)")
            }
        }
    }

    private static func body(for note: Note, source: String) -> String {
        let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteTitle = title.isEmpty ? "Untitled" : title
        return "\(source): \(noteTitle)"
    }

    private static func deliverLegacyNotification(title: String, body: String, noteID: Note.ID) {
        DispatchQueue.main.async {
            let notification = NSUserNotification()
            notification.title = title
            notification.informativeText = body
            notification.soundName = NSUserNotificationDefaultSoundName
            notification.userInfo = [
                ExternalNoteEvent.noteIDKey: noteID.uuidString
            ]
            NSUserNotificationCenter.default.deliver(notification)
            appendDiagnostic("Legacy delivered")
            logger.info("Legacy notification delivered")
        }
    }

    private static func appendDiagnostic(_ message: String) {
        let line = "\(Date()) \(message)\n"
        let url = AppGroup.containerURL.appending(path: "notification-debug.log")

        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path),
               let handle = try? FileHandle(forWritingTo: url) {
                try handle.seekToEnd()
                if let data = line.data(using: .utf8) {
                    try handle.write(contentsOf: data)
                }
                try handle.close()
            } else {
                try line.write(to: url, atomically: true, encoding: .utf8)
            }
        } catch {
            logger.error("Notification diagnostic write failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
