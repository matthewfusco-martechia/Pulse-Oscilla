import SwiftUI

enum WorkspaceGlassPreference {
    static let storageKey = "pulseOscilla.useLiquidGlass"
}

enum GlassPreference {
    static let storageKey = WorkspaceGlassPreference.storageKey

    static var isSupported: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }
}

enum AdaptiveGlassStyle {
    case regular
}

private struct WorkspaceGlassModifier<S: Shape>: ViewModifier {
    @AppStorage(WorkspaceGlassPreference.storageKey) private var glassEnabled = true

    let tint: Color
    let stroke: Color
    let shape: S
    let interactive: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), glassEnabled {
            if interactive {
                content
                    .glassEffect(.regular.interactive(), in: shape)
                    .background(tint, in: shape)
                    .overlay(shape.stroke(stroke, lineWidth: 1))
            } else {
                content
                    .glassEffect(.regular, in: shape)
                    .background(tint, in: shape)
                    .overlay(shape.stroke(stroke, lineWidth: 1))
            }
        } else {
            content
                .background(.thinMaterial, in: shape)
                .background(tint, in: shape)
                .overlay(shape.stroke(stroke, lineWidth: 1))
        }
    }
}

private struct AdaptiveGlassModifier<S: Shape>: ViewModifier {
    @AppStorage(WorkspaceGlassPreference.storageKey) private var glassEnabled = true

    let regularStyle: Bool
    let shape: S

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), glassEnabled {
            if regularStyle {
                content.glassEffect(.regular, in: shape)
            } else {
                content.glassEffect(in: shape)
            }
        } else {
            content.background(.thinMaterial, in: shape)
        }
    }
}

private struct AdaptiveNavigationBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

private struct AdaptiveToolbarItemModifier<S: Shape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        content
    }
}

extension View {
    func workspaceGlass<S: Shape>(
        tint: Color = Color(.secondarySystemBackground).opacity(0.10),
        stroke: Color = Color(.separator).opacity(0.08),
        in shape: S,
        interactive: Bool = false
    ) -> some View {
        modifier(WorkspaceGlassModifier(tint: tint, stroke: stroke, shape: shape, interactive: interactive))
    }

    func workspaceGlass(
        cornerRadius: CGFloat,
        tint: Color = Color(.secondarySystemBackground).opacity(0.10),
        stroke: Color = Color(.separator).opacity(0.08),
        interactive: Bool = false
    ) -> some View {
        workspaceGlass(
            tint: tint,
            stroke: stroke,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
            interactive: interactive
        )
    }

    func adaptiveGlass(_ style: AdaptiveGlassStyle, in shape: some Shape) -> some View {
        modifier(AdaptiveGlassModifier(regularStyle: style == .regular, shape: shape))
    }

    func adaptiveGlass(in shape: some Shape) -> some View {
        modifier(AdaptiveGlassModifier(regularStyle: false, shape: shape))
    }

    func adaptiveNavigationBar() -> some View {
        modifier(AdaptiveNavigationBarModifier())
    }

    func adaptiveToolbarItem(in shape: some Shape) -> some View {
        modifier(AdaptiveToolbarItemModifier(shape: shape))
    }
}

struct WorkspaceChatBackground: View {
    var body: some View {
        Color(.systemBackground)
        .ignoresSafeArea()
    }
}
