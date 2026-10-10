package struct Rewriters: Sendable {
    package let cloud: PerProvider<any TextRewriter>
    package let localServer: any TextRewriter
    package let apple: any TextRewriter

    package init(cloud: PerProvider<any TextRewriter>, localServer: any TextRewriter, apple: any TextRewriter) {
        self.cloud = cloud
        self.localServer = localServer
        self.apple = apple
    }

    package subscript(_ provider: ModelProvider) -> any TextRewriter {
        switch provider {
        case .apple: apple
        case .localServer: localServer
        case let .cloud(provider): cloud[provider]
        }
    }
}
