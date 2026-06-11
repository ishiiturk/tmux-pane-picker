import AVFoundation

@MainActor
protocol AgentApprovalSpeaking: AnyObject {
    func speakApprovalNeeded(count: Int)
}

@MainActor
final class MacOSAgentApprovalSpeaker: AgentApprovalSpeaking {
    private let synthesizer = AVSpeechSynthesizer()

    func speakApprovalNeeded(count: Int) {
        let message = count == 1 ? "エージェントの承認が必要です。" : "\(count) 件のエージェント承認が必要です。"
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = Self.preferredJapaneseVoice()
        utterance.rate = 0.46
        utterance.pitchMultiplier = 1.02
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.05

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        synthesizer.speak(utterance)
    }

    private static func preferredJapaneseVoice() -> AVSpeechSynthesisVoice? {
        let japaneseVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "ja-JP" }

        if let highQualityVoice = japaneseVoices.max(by: { $0.quality.rawValue < $1.quality.rawValue }),
           highQualityVoice.quality.rawValue > AVSpeechSynthesisVoiceQuality.default.rawValue {
            return highQualityVoice
        }

        let preferredIdentifiers = [
            "com.apple.voice.premium.ja-JP.Kyoko",
            "com.apple.voice.enhanced.ja-JP.Kyoko",
            "com.apple.voice.compact.ja-JP.Kyoko"
        ]

        for identifier in preferredIdentifiers {
            if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
                return voice
            }
        }

        return AVSpeechSynthesisVoice(language: "ja-JP")
    }
}

@MainActor
struct AgentApprovalAnnouncer {
    private var awaitingApprovalPaneIDs: Set<TmuxPane.ID> = []

    mutating func update(panes: [TmuxPane], speaker: AgentApprovalSpeaking) {
        let currentAwaitingApprovalPaneIDs = Set(
            panes
                .filter { $0.agentAttention == .awaitingApproval }
                .map(\.id)
        )
        let newAwaitingApprovalPaneIDs = currentAwaitingApprovalPaneIDs.subtracting(awaitingApprovalPaneIDs)

        awaitingApprovalPaneIDs = currentAwaitingApprovalPaneIDs

        guard !newAwaitingApprovalPaneIDs.isEmpty else {
            return
        }

        speaker.speakApprovalNeeded(count: newAwaitingApprovalPaneIDs.count)
    }
}
