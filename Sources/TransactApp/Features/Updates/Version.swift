import Foundation

struct Version: Codable, Comparable, Sendable {
    let mayor: Int
    let minor: Int
    let patch: Int

    init(mayor: Int = 0, minor: Int = 0, patch: Int = 0) {
        self.mayor = mayor
        self.minor = minor
        self.patch = patch
    }

    init(_ string: String) throws {
        let partes = string.split(separator: ".", omittingEmptySubsequences: false)
        guard partes.count == 3,
              let m = Int(partes[0]),
              let mn = Int(partes[1]),
              let p = Int(partes[2])
        else { throw VersionError.invalid(string) }
        mayor = m
        minor = mn
        patch = p
    }

    static func < (lhs: Version, rhs: Version) -> Bool {
        if lhs.mayor != rhs.mayor { return lhs.mayor < rhs.mayor }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }
}

enum VersionError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self {
        case .invalid(let v): "Versión inválida: \(v)"
        }
    }
}
