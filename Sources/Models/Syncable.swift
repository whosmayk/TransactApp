import Foundation

public enum SyncStatus: Int, Codable, Sendable {
    case pending = 0
    case synced = 1
    case conflict = 2
}

public protocol Syncable: Sendable {
    var uuid: String { get set }
    var updatedAt: Date { get set }
    var isDeleted: Bool { get set }
}

extension Syncable {
    public static func generarUUID() -> String {
        UUID().uuidString.lowercased()
    }

    public static var ahoraMillis: Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
