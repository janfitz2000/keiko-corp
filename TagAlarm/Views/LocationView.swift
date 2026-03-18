import SwiftUI
import MapKit

struct LocationView: View {
    @EnvironmentObject var locationManager: LocationManager

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                mapView

                // Address card
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "location.fill")
                            .foregroundStyle(.blue)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(locationManager.addressString)
                                .font(.subheadline.bold())

                            if let loc = locationManager.location {
                                Text(String(format: "%.4f, %.4f", loc.coordinate.latitude, loc.coordinate.longitude))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
            .navigationTitle("Location")
            .onAppear {
                locationManager.requestPermission()
            }
        }
    }

    @ViewBuilder
    private var mapView: some View {
        if let location = locationManager.location {
            Map(initialPosition: .camera(MapCamera(
                centerCoordinate: location.coordinate,
                distance: 500
            ))) {
                UserAnnotation()
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
        } else {
            VStack(spacing: 16) {
                ProgressView()
                Text(statusText)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)

                if locationManager.authStatus == .denied || locationManager.authStatus == .restricted {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var statusText: String {
        switch locationManager.authStatus {
        case .notDetermined:
            return "Requesting location access..."
        case .denied, .restricted:
            return "Location access denied. Enable in Settings."
        case .authorizedWhenInUse, .authorizedAlways:
            return "Getting your location..."
        @unknown default:
            return "Loading..."
        }
    }
}
