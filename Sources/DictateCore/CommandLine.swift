import Foundation

/// Value following `flag` in `arguments` (`--state-file /tmp/x` gives `/tmp/x`), or `nil`
/// if the flag is absent or is the last argument.
public func argumentValue(after flag: String, in arguments: [String] = CommandLine.arguments) -> String? {
    guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
        return nil
    }
    return arguments[index + 1]
}
