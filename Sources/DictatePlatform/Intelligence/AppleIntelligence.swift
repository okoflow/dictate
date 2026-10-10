import DictateCore
import Foundation
import FoundationModels

package struct AppleIntelligence: TextRewriter, OnDeviceModel {
    package var availability: OnDeviceModelAvailability {
        guard #available(macOS 26, *) else { return .needsNewerSystem }

        return AppleIntelligenceSession.availability
    }

    package init() {}

    package func rewrite(_ request: RewriteRequest) async throws -> String {
        guard #available(macOS 26, *) else { throw RewriteError.unavailable }

        return try await AppleIntelligenceSession.rewrite(request)
    }
}

@available(macOS 26, *)
private enum AppleIntelligenceSession {
    static var availability: OnDeviceModelAvailability {
        switch SystemLanguageModel.default.availability {
        case .available: .available
        case .unavailable(.appleIntelligenceNotEnabled): .notEnabled
        case .unavailable(.modelNotReady): .notReady
        case .unavailable: .notSupported
        }
    }

    static func rewrite(_ request: RewriteRequest) async throws -> String {
        guard availability == .available else { throw RewriteError.unavailable }

        let session = LanguageModelSession(instructions: RewritePrompt.system(for: request))

        do {
            let response = try await session.respond(
                to: RewritePrompt.userMessage(for: request),
                options: GenerationOptions(temperature: 0.2),
            )

            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch let error as LanguageModelSession.GenerationError {
            throw rewriteError(for: error)
        }
    }

    private static func rewriteError(for error: LanguageModelSession.GenerationError) -> RewriteError {
        switch error {
        case .guardrailViolation, .refusal: .refused
        case .exceededContextWindowSize: .truncated
        case .unsupportedLanguageOrLocale, .assetsUnavailable: .unavailable
        case .rateLimited, .concurrentRequests: .rateLimited
        default: .serviceUnavailable(status: 0)
        }
    }
}
