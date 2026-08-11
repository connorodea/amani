import Foundation

@MainActor
protocol ActivationTrigger: AnyObject {
    var id: String { get }
    func start(onActivate: @escaping () -> Void)
    func stop()
}
