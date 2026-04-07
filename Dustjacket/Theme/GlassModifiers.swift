import SwiftUI

// MARK: - Liquid Glass View Modifiers
//
// iOS 26 Liquid Glass API reference:
// - .glassEffect(.regular)              → standard glass on navigation surfaces
// - .glassEffect(.regular.interactive()) → touch-responsive glass (filter pills, buttons)
// - .glassEffect(.clear)                → high transparency for media backgrounds
// - .glassEffect(.identity)             → conditional disable (no effect)
// - .buttonStyle(.glass)                → translucent secondary action buttons
// - .buttonStyle(.glassProminent)       → opaque primary action buttons
// - GlassEffectContainer { }            → groups multiple glass elements
//
// Rules:
// - Glass is ONLY for the navigation layer floating above content
// - Tab bar + nav bar get glass automatically with iOS 26 recompile
// - Filter pills and floating buttons use .glassEffect(.regular.interactive())
// - Book cards, covers, and content NEVER get glass
//
// These modifiers will be applied when building with Xcode 26 beta.
// Until then, they provide styled fallbacks.

struct GlassFilterPill: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? AnyShapeStyle(DustjacketTheme.accent.opacity(0.2))
                    : AnyShapeStyle(.ultraThinMaterial)
            )
            .foregroundStyle(isSelected ? DustjacketTheme.accent : .secondary)
            .clipShape(Capsule())
        // When targeting iOS 26:
        // .glassEffect(.regular.interactive())
    }
}

struct GlassFloatingButton: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .shadow(radius: 4, y: 2)
        // When targeting iOS 26:
        // .glassEffect(.regular.interactive())
        // or .buttonStyle(.glassProminent)
    }
}

extension View {
    func glassFilterPill(isSelected: Bool) -> some View {
        modifier(GlassFilterPill(isSelected: isSelected))
    }

    func glassFloatingButton() -> some View {
        modifier(GlassFloatingButton())
    }
}
