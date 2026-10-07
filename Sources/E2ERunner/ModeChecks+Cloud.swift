import DictateCore
import Foundation

/// The cloud half of the M4 checks.
extension ModeChecks {
    /// What each filler fixture says first and then corrects ("Thursday, no, Friday"), per language of the output.
    private static let corrections: [Language: (dropped: String, kept: String)] = [
        .ru: ("четверг", "пятниц"),
        .en: ("thursday", "friday"),
        .ko: ("목요일", "금요일"),
    ]

    /// Fillers Whisper writes as words, which Clean, Formal and Translate must remove (Light keeps them).
    private static let fillers: [Language: Set<String>] = [
        .ru: ["ну", "значит"],
        .en: ["um", "uh"],
        .ko: ["그러니까"],
    ]

    /// With the stub behind the proxy: the request is what the plan says (model, version header, placeholder key,
    /// the Clean prompt, the transcript in tags, temperature 0), and the answer is what gets delivered.
    func cloudPlumbing() -> Outcome {
        run {
            proxy.behaviour = .stub
            let before = proxy.received.count
            let delivery = try dictate("ru-plain-2", mode: .clean)
            guard proxy.received.count == before + 1, let request = proxy.received.last else {
                throw Verdict.fail("expected one request at the LLM proxy, got \(proxy.received.count - before)")
            }
            guard request.headers["x-api-key"] == "e2e" else {
                throw Verdict.fail("the request did not carry the placeholder key (the real key must never go to the proxy)")
            }
            guard request.headers["anthropic-version"] == CloudPrompt.apiVersion else {
                throw Verdict.fail("anthropic-version is \(request.headers["anthropic-version"] ?? "missing")")
            }
            guard let sent = try? JSONDecoder().decode(SentRequest.self, from: request.body) else {
                throw Verdict.fail("the request body is not a Messages API request")
            }
            let expectedUser = CloudPrompt.userMessage(text: delivery.raw, language: .ru)
            guard sent.model == CloudPrompt.model, sent.temperature == 0, sent.system == CloudPrompt.system(for: .clean),
                  sent.messages.map(\.role) == ["user"], sent.messages.first?.content == expectedUser
            else {
                throw Verdict.fail(
                    "unexpected request: model \(sent.model), temperature \(sent.temperature), \(sent.messages.count) message(s)"
                )
            }
            guard delivery.applied == .clean, delivery.cloud, delivery.text == LLMProxy.stubPrefix + delivery.raw else {
                throw Verdict.fail("delivered \"\(delivery.text)\" (applied \(delivery.applied)), expected the stub's answer")
            }
            return .measured("\(CloudPrompt.model), answer delivered as sent")
        }
    }

    /// The proxy answers after 4 s: Light within the 3 s deadline. The proxy drops the connection: Light at once.
    func cloudFallback() -> Outcome {
        run {
            defer { proxy.behaviour = .stub }
            proxy.behaviour = .delay(4)
            let slow = try dictate("ru-filler-1", mode: .clean)
            try requireLight(slow, fallback: .timeout)
            guard slow.cloud, slow.processingSeconds <= 3.5 else {
                throw Verdict.fail(String(format: "the timeout fallback took %.1f s (deadline 3 s)", slow.processingSeconds))
            }
            proxy.behaviour = .drop
            let offline = try dictate("en-filler-1", mode: .formal)
            try requireLight(offline, fallback: .offline)
            return .measured(String(
                format: "timeout → Light after %.1f s, dropped connection → Light after %.1f s",
                slow.processingSeconds, offline.processingSeconds
            ))
        }
    }

    /// Clean, Formal and Translate on the filler fixture of every language, with the recorded answers (or live
    /// with `E2E_LLM=live`): no fallback, the language kept (Translate: English), no hesitations or fillers,
    /// the self-correction resolved, and Clean close to the manifest's `clean` text.
    func cloudModes() -> Outcome {
        run {
            try useRecordedOrLiveAnswers()
            var notes: [String] = []
            for id in Self.fillerFixtures {
                for mode in [Mode.clean, .formal, .translate] {
                    let delivery = try dictate(id, mode: mode)
                    try requireCloudAnswer(delivery)
                    if mode == .clean, let rate = try cleanErrorRate(delivery) {
                        notes.append(String(format: "\(delivery.fixture.language.rawValue) clean %.0f %%", rate * 100))
                    }
                }
            }
            return .measured((live ? "live, recorded; " : "replayed; ") + notes.joined(separator: ", "))
        }
    }

    /// ru-long-1 (10 s of speech) in Clean: from handing over the audio to the text ≤ 2.5 s. In replay the
    /// LLM's share is the latency recorded live.
    func cleanLatency() -> Outcome {
        run {
            try useRecordedOrLiveAnswers()
            let delivery = try dictate("ru-long-1", mode: .clean)
            guard delivery.applied == .clean else {
                throw Verdict.fail("ru-long-1 fell back to Light: \(String(describing: delivery.fallback))")
            }
            let note = String(
                format: "%.2f s from the audio to the text (LLM %.2f s, %@)",
                delivery.seconds, delivery.processingSeconds, live ? "live" : "recorded latency"
            )
            guard delivery.seconds <= Self.maximumCleanLatency else {
                throw Verdict.fail(note + String(format: ", limit %.1f s", Self.maximumCleanLatency))
            }
            return .measured(note)
        }
    }

    // MARK: Helpers

    private func useRecordedOrLiveAnswers() throws {
        if live {
            guard let liveKey else {
                throw Verdict.blocked(
                    "E2E_LLM=live needs an Anthropic API key: ANTHROPIC_API_KEY or the Keychain item (menu → Set API key…)"
                )
            }
            proxy.behaviour = .record(apiKey: liveKey)
            return
        }
        guard proxy.recordedAnswers > 0 else {
            throw Verdict.blocked(
                "no recorded LLM answers (e2e/cassettes/llm.json): run `E2E_LLM=live make e2e` once with an API key"
            )
        }
        proxy.behaviour = .replay
    }

    private func requireCloudAnswer(_ delivery: Delivery) throws {
        let id = "\(delivery.fixture.id) \(delivery.mode.rawValue)"
        guard delivery.applied == delivery.mode, delivery.fallback == nil, delivery.cloud else {
            let miss = proxy.misses.last.map { " — no recorded answer for \($0): re-record with `E2E_LLM=live make e2e`" } ?? ""
            throw Verdict.fail("\(id): fell back to Light (\(String(describing: delivery.fallback)))\(miss)")
        }
        let output: Language = delivery.mode == .translate ? .en : delivery.language
        guard Script.dominant(in: delivery.text) == Script(output) else {
            throw Verdict.fail("\(id): \"\(delivery.text)\" is not in \(output.displayName)")
        }
        let words = Self.words(of: delivery.text)
        if let left = words.first(where: { LightRules.isHesitation($0) || (Self.fillers[output] ?? []).contains($0) }) {
            throw Verdict.fail("\(id): the filler \"\(left)\" is left in \"\(delivery.text)\"")
        }
        if let correction = Self.corrections[output] {
            let text = delivery.text.lowercased()
            guard !text.contains(correction.dropped), text.contains(correction.kept) else {
                throw Verdict.fail("\(id): the self-correction is not resolved in \"\(delivery.text)\"")
            }
        }
    }

    private func cleanErrorRate(_ delivery: Delivery) throws -> Double? {
        guard let reference = delivery.fixture.clean else { return nil }
        let rate = TextMetrics.cer(reference: reference, hypothesis: delivery.text, language: delivery.fixture.language)
        guard rate <= Self.maximumCleanErrorRate else {
            throw Verdict.fail(String(
                format: "\(delivery.fixture.id) clean: \"\(delivery.text)\" is off by %.0f %% from \"\(reference)\"", rate * 100
            ))
        }
        return rate
    }
}
