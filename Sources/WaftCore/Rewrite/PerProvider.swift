package struct PerProvider<Value> {
    package let claude: Value
    package let openAI: Value

    package init(claude: Value, openAI: Value) {
        self.claude = claude
        self.openAI = openAI
    }

    package subscript(_ provider: CloudProvider) -> Value {
        switch provider {
        case .claude: claude
        case .openAI: openAI
        }
    }
}

extension PerProvider: Sendable where Value: Sendable {}
