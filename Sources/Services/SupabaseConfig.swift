import Foundation

public enum SupabaseConfig: Sendable {
    public static let projectURL: String = "https://hiloeceyeyrzbiecnuvc.supabase.co"
    public static let anonKey: String = "sb_publishable_pM6JK32bWLKcnUoO57Yrqg_lCPt7f2U"

    public static var authURL: String { "\(projectURL)/auth/v1" }
    public static var restURL: String { "\(projectURL)/rest/v1" }
    public static var realtimeURL: String { "\(projectURL)/realtime/v1" }

    public static let apiKeyHeader = "apikey"
    public static let bearerHeader = "Authorization"
}
