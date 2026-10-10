package enum HUDContent: Equatable, Sendable {
    case hidden
    case listening(badge: String?)
    case working(String)
    case message(HUDMessage)
}
