// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

/// A code-drawn device shell; wallpaper pixels keep their original aspect ratio.
struct PhonePreviewFrame<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let inset = width * 0.027
            let radius = width * 0.145
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Color(white: 0.07).gradient)
                content()
                    .clipShape(RoundedRectangle(cornerRadius: radius - inset, style: .continuous))
                    .padding(inset)
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.08), .black, .white.opacity(0.18)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: width * 0.009)
                RoundedRectangle(cornerRadius: radius - width * 0.012, style: .continuous)
                    .strokeBorder(.black, lineWidth: width * 0.008).padding(width * 0.012)
                VStack {
                    Capsule().fill(.black)
                        .frame(width: width * 0.28, height: width * 0.077)
                        .overlay(alignment: .trailing) {
                            Circle().fill(Color(red: 0.06, green: 0.08, blue: 0.12))
                                .frame(width: width * 0.024).padding(.trailing, width * 0.022)
                        }
                        .padding(.top, width * 0.055)
                    Spacer()
                    Capsule().fill(.white.opacity(0.8))
                        .frame(width: width * 0.32, height: width * 0.011)
                        .padding(.bottom, width * 0.052)
                }.allowsHitTesting(false).accessibilityHidden(true)
            }
            .overlay(alignment: .leading) {
                VStack(spacing: width * 0.035) {
                    Capsule().fill(Color(white: 0.3)).frame(width: 2, height: width * 0.055)
                    Capsule().fill(Color(white: 0.3)).frame(width: 2, height: width * 0.105)
                    Capsule().fill(Color(white: 0.3)).frame(width: 2, height: width * 0.105)
                }.offset(x: -1, y: -geometry.size.height * 0.19)
            }
            .overlay(alignment: .trailing) {
                Capsule().fill(Color(white: 0.3)).frame(width: 2, height: width * 0.16)
                    .offset(x: 1, y: -geometry.size.height * 0.13)
            }
        }
        .aspectRatio(0.477, contentMode: .fit)
        .shadow(color: .black.opacity(0.2), radius: 25, x: 0, y: 18)
    }
}

/// Material progressively covers the device, leaving a clear centre.
struct PreviewMist: View {
    var body: some View {
        Rectangle().fill(.ultraThinMaterial)
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0),
                                         .init(color: .clear, location: 0.22),
                                         .init(color: .clear, location: 0.48),
                                         .init(color: .black.opacity(0.8), location: 0.82),
                                         .init(color: .black, location: 1)], startPoint: .top, endPoint: .bottom))
            .blur(radius: 12)
            .allowsHitTesting(false)
    }
}

/// Artwork supplies only a quiet wash of colour behind the device.
struct WallpaperAtmosphere: View {
    let url: URL?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        GeometryReader { geometry in
            if !reduceTransparency {
                WallpaperArtwork(url: url)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(1.15)
                    .blur(radius: 26, opaque: false)
                    .saturation(0.85)
                    .opacity(0.58)
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

