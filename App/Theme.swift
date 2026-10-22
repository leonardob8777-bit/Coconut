// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI

/// A neutral canvas lets each wallpaper supply its own color.
enum Theme {
    static let accent = Color.primary
    static let cardRadius: CGFloat = 24
    static let gutter: CGFloat = 24
    static let canvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.065, green: 0.069, blue: 0.065, alpha: 1)
            : UIColor(red: 0.969, green: 0.965, blue: 0.949, alpha: 1)
    })
    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.115, alpha: 1) : UIColor(white: 1, alpha: 0.72)
    })
    static let ink = Color(uiColor: .label)
    static let inverseInk = Color(uiColor: .systemBackground)
    static let hairline = Color.primary.opacity(0.09)
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .default, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(Theme.inverseInk)
            .background(Theme.ink, in: Capsule())
            .opacity(enabled ? (configuration.isPressed ? 0.76 : 1) : 0.35)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .foregroundStyle(.primary)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
            .opacity(enabled ? (configuration.isPressed ? 0.65 : 1) : 0.35)
    }
}

struct CardBackground: ViewModifier {
    var padding: CGFloat = 18
    func body(content: Content) -> some View {
        content.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

extension View {
    func card(padding: CGFloat = 18) -> some View { modifier(CardBackground(padding: padding)) }

    @ViewBuilder func coconutGlass() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .capsule)
        } else {
            self.background(.regularMaterial, in: Capsule())
        }
    }
}

struct IconTile: View {
    let systemName: String
    var tint: Color = Theme.accent
    var size: CGFloat = 36
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.44, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(Theme.hairline.opacity(0.6), in: RoundedRectangle(cornerRadius: size * 0.3))
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 11, weight: .semibold)).tracking(1.5)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatusBadge: View {
    let text: String
    let tint: Color
    var body: some View {
        Text(text).font(.caption.weight(.medium)).foregroundStyle(tint)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(tint.opacity(0.08), in: Capsule())
    }
}

struct QuietEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 30, weight: .ultraLight))
                .frame(width: 76, height: 76).background(Theme.surface, in: Circle())
            Text(title).font(.title3.weight(.semibold))
            Text(L.message(message)).font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).lineSpacing(3)
        }
        .padding(32).frame(maxWidth: .infinity)
    }
}

enum Format {
    static func bytes(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: value, countStyle: .file)
    }
}
