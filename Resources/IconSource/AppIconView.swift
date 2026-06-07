import SwiftUI

public struct AppIconView: View {
    public init() {}

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 224, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.424, green: 0.557, blue: 0.749),
                            Color(red: 0.290, green: 0.416, blue: 0.588),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Image(systemName: "wallet.bifold")
                .font(.system(size: 600, weight: .medium))
                .foregroundColor(.white)
        }
    }
}
