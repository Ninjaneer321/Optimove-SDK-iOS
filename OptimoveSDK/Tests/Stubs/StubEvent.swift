// Copiright 2019 Optimove

@testable import OptimoveSDK

final class StubEvent: OptimoveEvent {

    struct Constnats {
        static let name = "stub_name"
        static let key = "stub_key"
        static let value = "stub_value"
    }

    var name: String = Constnats.name
    var parameters: [String: Any] = [
        Constnats.key: Constnats.value
    ]

    func isStubEvent(_ event: RealtimeEvent) -> Bool {
        return (event.context[Constnats.key] as? String) == Constnats.value
    }
}
