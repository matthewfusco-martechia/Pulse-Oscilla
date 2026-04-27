import Observation

@MainActor
@Observable
final class AppEnvironment {
    let connection = BridgeConnection()
}

