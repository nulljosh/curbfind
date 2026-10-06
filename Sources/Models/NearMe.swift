import CoreLocation

/// One-shot device location for "Near me". The coordinates never leave the device:
/// the nearest city is worked out locally from Craigslist's area directory.
@MainActor
final class NearMe: NSObject, CLLocationManagerDelegate {
    enum Failure: LocalizedError {
        case denied, unavailable
        var errorDescription: String? {
            switch self {
            case .denied: return "Location is off for Curbfind. Pick a city instead."
            case .unavailable: return "Couldn't find your location."
            }
        }
    }

    private let manager = CLLocationManager()
    private var pending: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func locate() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { cont in
            pending = cont
            switch manager.authorizationStatus {
            case .denied, .restricted: finish(.failure(Failure.denied))
            case .notDetermined: manager.requestWhenInUseAuthorization()
            default: manager.requestLocation()
            }
        }
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        pending?.resume(with: result)
        pending = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        let status = m.authorizationStatus
        Task { @MainActor in
            guard pending != nil else { return }
            switch status {
            case .denied, .restricted: finish(.failure(Failure.denied))
            case .notDetermined: break
            default: manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let loc = locs.last else { return }
        Task { @MainActor in finish(.success(loc)) }
    }

    nonisolated func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in finish(.failure(Failure.unavailable)) }
    }
}
