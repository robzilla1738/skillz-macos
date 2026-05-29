import SwiftUI

struct PlatformBrandIcon: View {
    let platform: AgentPlatform
    var size: CGFloat = 14
    var opacity: Double = 1

    var body: some View {
        Group {
            if let assetName = platform.brandIconAssetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: platform.symbolName)
                    .font(.system(size: size * 0.85, weight: .medium))
            }
        }
        .foregroundStyle(NotchMonochromeStyle.ink.opacity(opacity))
    }
}
