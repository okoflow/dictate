@MainActor
package protocol PermissionProvider: AnyObject {
    func status(of permission: Permission) -> PermissionStatus
    func request(_ permission: Permission) async
}
