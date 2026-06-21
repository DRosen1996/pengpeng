import CoreLocation
import Foundation

enum Geohash {
    private static let base32 = Array("0123456789bcdefghjkmnpqrstuvwxyz")

    static func encode(latitude: Double, longitude: Double, precision: Int) -> String {
        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var hash = ""
        var bit = 0
        var ch = 0
        var even = true

        while hash.count < precision {
            if even {
                let mid = (lonRange.0 + lonRange.1) / 2
                if longitude >= mid {
                    ch |= 1 << (4 - bit)
                    lonRange.0 = mid
                } else {
                    lonRange.1 = mid
                }
            } else {
                let mid = (latRange.0 + latRange.1) / 2
                if latitude >= mid {
                    ch |= 1 << (4 - bit)
                    latRange.0 = mid
                } else {
                    latRange.1 = mid
                }
            }

            even.toggle()
            bit += 1

            if bit == 5 {
                hash.append(base32[ch])
                bit = 0
                ch = 0
            }
        }

        return hash
    }

    static func decodeCenter(_ hash: String) -> (latitude: Double, longitude: Double)? {
        let normalized = hash.lowercased()
        guard !normalized.isEmpty else { return nil }

        var latRange = (-90.0, 90.0)
        var lonRange = (-180.0, 180.0)
        var even = true

        for char in normalized {
            guard let index = base32.firstIndex(of: char) else { return nil }
            var value = index

            for bitIndex in (0..<5).reversed() {
                let bit = (value >> bitIndex) & 1
                if even {
                    let mid = (lonRange.0 + lonRange.1) / 2
                    if bit == 1 {
                        lonRange.0 = mid
                    } else {
                        lonRange.1 = mid
                    }
                } else {
                    let mid = (latRange.0 + latRange.1) / 2
                    if bit == 1 {
                        latRange.0 = mid
                    } else {
                        latRange.1 = mid
                    }
                }
                even.toggle()
            }
        }

        return (
            latitude: (latRange.0 + latRange.1) / 2,
            longitude: (lonRange.0 + lonRange.1) / 2
        )
    }

    static func decodeCoordinate(_ hash: String) -> CLLocationCoordinate2D? {
        guard let center = decodeCenter(hash) else { return nil }
        return CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude)
    }
}
