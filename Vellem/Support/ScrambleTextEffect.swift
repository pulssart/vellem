import Foundation

struct ScrambleFrame {
    let text: String
    let yellowOffsets: Set<Int>
}

enum ScrambleTextEffect {
    private static let characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789#%&?+=<>")

    static func frame(for finalText: String, progress: Double) -> ScrambleFrame {
        let clampedProgress = min(max(progress, 0), 1)
        let visibleCharacters = finalText.filter { !$0.isWhitespace && !$0.isNewline }.count
        guard visibleCharacters > 0 else {
            return ScrambleFrame(text: finalText, yellowOffsets: [])
        }

        var output = ""
        var scannedCharacters = 0
        var stringOffset = 0
        var yellowOffsets = Set<Int>()

        for character in finalText {
            if character.isWhitespace || character.isNewline {
                output.append(character)
                stringOffset += 1
                continue
            }

            defer { scannedCharacters += 1 }

            let revealThreshold = Double(scannedCharacters + 1) / Double(visibleCharacters)
            if revealThreshold <= clampedProgress {
                output.append(character)
            } else {
                output.append(characters.randomElement() ?? character)

                if Double.random(in: 0...1) < 0.2 {
                    yellowOffsets.insert(stringOffset)
                }
            }

            stringOffset += 1
        }

        return ScrambleFrame(text: output, yellowOffsets: yellowOffsets)
    }
}
