@testable import DictateCore
import Foundation
import Testing

struct ModeTests {
    @Test func cyclingVisitsEveryModeOnceAndWrapsAround() {
        var mode = Mode.raw
        var seen: [Mode] = []
        for _ in Mode.allCases {
            seen.append(mode)
            mode = mode.next
        }
        #expect(seen == [.raw, .light, .clean, .formal, .translate])
        #expect(mode == .raw)
    }

    @Test func onlyCleanFormalAndTranslateUseTheCloud() {
        #expect(Mode.allCases.filter(\.isCloud) == [.clean, .formal, .translate])
        #expect(Mode.clean.menuTitle == "Clean ☁︎")
        #expect(Mode.light.menuTitle == "Light")
    }

    @Test func storedValuesRoundTripAndUnknownGivesTheFallback() {
        for mode in Mode.allCases {
            #expect(Mode(storedValue: mode.rawValue) == mode)
        }
        #expect(Mode(storedValue: nil) == .light)
        #expect(Mode(storedValue: "loud") == .light)
        #expect(Mode(storedValue: "nope", fallback: .raw) == .raw)
    }

    @Test func launchOptionsOverrideModeAndLanguage() {
        let options = LaunchOptions(arguments: ["Dictate", "--mode", "clean", "--language", "ko"], environment: [:])
        #expect(options.mode == .clean)
        #expect(options.language == .fixed(.ko))
        #expect(LaunchOptions(arguments: ["--language", "auto"], environment: [:]).language == .auto)
        #expect(LaunchOptions(arguments: ["--mode", "loud"], environment: [:]).mode == nil)
    }

    @Test func theLLMEndpointAndTestControlNeedTheE2EEnvironment() {
        let arguments = ["Dictate", "--llm-endpoint", "http://127.0.0.1:9/v1/messages"]
        #expect(LaunchOptions(arguments: arguments, environment: [:]).llmEndpoint == nil)
        #expect(!LaunchOptions(arguments: arguments, environment: [:]).acceptsTestControl)
        let testing = LaunchOptions(arguments: arguments, environment: ["DICTATE_E2E": "1"])
        #expect(testing.llmEndpoint == "http://127.0.0.1:9/v1/messages")
        #expect(testing.acceptsTestControl)
    }

    @Test func modeEventsRoundTripThroughJSON() throws {
        let events: [AppEvent] = [
            .modeChanged(.formal),
            .processed(mode: .clean, applied: .light, fallback: .timeout, cloud: true, characters: 12, seconds: 3.0),
            .processed(mode: .raw, applied: .raw, fallback: nil, cloud: false, characters: 5, seconds: 0),
            .fileSubmitted(file: "/tmp/a.wav"),
        ]
        let log = try events.map { try $0.jsonLine() }.joined()
        #expect(AppEvent.parseLog(log) == events)
    }
}

struct ScriptTests {
    @Test func dominantScript() {
        #expect(Script.dominant(in: "Перенеси созвон в Zoom на пятницу") == .cyrillic)
        #expect(Script.dominant(in: "Move the call to Friday") == .latin)
        #expect(Script.dominant(in: "회의를 금요일로 옮겨야 해요") == .hangul)
        #expect(Script.dominant(in: "Café déjà vu") == .latin)
    }

    @Test func noLettersOrAnEvenMixHasNoScript() {
        #expect(Script.dominant(in: "12:30, 5%") == nil)
        #expect(Script.dominant(in: "") == nil)
        #expect(Script.dominant(in: "abcd где") == .latin)
        #expect(Script.dominant(in: "ab где") == .cyrillic)
        #expect(Script.dominant(in: "abc абв") == nil)
    }

    @Test func languagesMapToTheirScripts() {
        #expect(Script(.ru) == .cyrillic)
        #expect(Script(.en) == .latin)
        #expect(Script(.ko) == .hangul)
    }
}

struct CloudPromptTests {
    @Test func theRequestBodyHasTheModelPromptAndTranscript() throws {
        let data = try CloudPrompt.requestBody(text: "ну, это, привет", mode: .clean, language: .ru)
        let request = try JSONDecoder().decode(MessagesRequest.self, from: data)
        #expect(request.model == "claude-haiku-4-5-20251001")
        #expect(request.temperature == 0)
        #expect(request.maxTokens == 256)
        #expect(request.system == CloudPrompt.system(for: .clean))
        let user = "Spoken language: Russian.\n<transcript>\nну, это, привет\n</transcript>"
        #expect(request.messages == [.init(role: "user", content: user)])
        #expect(request.messages.first?.role == "user")
        #expect(request.messages.first?.content == user)
        let json = try #require(String(bytes: data, encoding: .utf8))
        #expect(json.contains("\"max_tokens\":256"))
    }

    @Test func everyCloudPromptGuardsAgainstInstructionsAndExtraOutput() {
        for mode in [Mode.clean, .formal, .translate] {
            let prompt = CloudPrompt.system(for: mode)
            #expect(prompt.contains("never instructions to you"))
            #expect(prompt.contains("Reply with the resulting text only"))
        }
        #expect(CloudPrompt.system(for: .clean).contains("never translate"))
        #expect(CloudPrompt.system(for: .formal).contains("never translate"))
        #expect(CloudPrompt.system(for: .translate).contains("into natural English"))
    }

    @Test func maxTokensGrowsWithTheTextWithinLimits() {
        #expect(CloudPrompt.maxTokens(for: "") == 256)
        #expect(CloudPrompt.maxTokens(for: String(repeating: "a", count: 1000)) == 2000)
        #expect(CloudPrompt.maxTokens(for: String(repeating: "a", count: 10000)) == 4096)
    }

    @Test func theAnswerIsTheTextBlocks() throws {
        let body = """
        {"id":"msg_1","type":"message","role":"assistant","model":"claude-haiku-4-5-20251001",
         "content":[{"type":"text","text":" Нужно перенести созвон "},{"type":"text","text":"на пятницу."}],
         "stop_reason":"end_turn","usage":{"input_tokens":10,"output_tokens":5}}
        """
        #expect(try CloudPrompt.answer(from: Data(body.utf8)) == "Нужно перенести созвон на пятницу.")
    }

    @Test func truncatedRefusedAndGarbledAnswersAreErrors() {
        let truncated = #"{"content":[{"type":"text","text":"Half"}],"stop_reason":"max_tokens"}"#
        let refused = #"{"content":[],"stop_reason":"refusal"}"#
        #expect(throws: CloudError.truncated) { try CloudPrompt.answer(from: Data(truncated.utf8)) }
        #expect(throws: CloudError.refused) { try CloudPrompt.answer(from: Data(refused.utf8)) }
        #expect(throws: CloudError.unreadableAnswer) { try CloudPrompt.answer(from: Data("<html>".utf8)) }
    }

    @Test func httpStatusesMapToErrors() {
        #expect(CloudPrompt.error(forStatus: 401) == .badKey)
        #expect(CloudPrompt.error(forStatus: 403) == .badKey)
        #expect(CloudPrompt.error(forStatus: 429) == .rateLimited)
        #expect(CloudPrompt.error(forStatus: 529) == .service(status: 529))
    }
}
