package enum HUDContent: Equatable, Sendable {
    case hidden
    case listening(badge: String?, isHandsFree: Bool)
    case working(String)
    case message(HUDMessage)
}
