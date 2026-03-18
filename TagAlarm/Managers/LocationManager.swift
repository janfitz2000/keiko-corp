import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject {
    @Published var location: CLLocation?
    @Published var placemark: CLPlacemark?
    @Published var authStatus: CLAuthorizationStatus = .notDetermined

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startTracking() {
        manager.startUpdatingLocation()
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
    }

    var addressString: String {
        guard let p = placemark else { return "Locating..." }
        return [p.name, p.locality].compactMap { $0 }.joined(separator: ", ")
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        location = loc

        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, _ in
            self?.placemark = placemarks?.first
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authStatus = manager.authorizationStatus
        if authStatus == .authorizedWhenInUse || authStatus == .authorizedAlways {
            startTracking()
        }
    }
}
