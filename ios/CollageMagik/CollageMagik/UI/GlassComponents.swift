import SwiftUI

/// A soft, slowly drifting colour field. Liquid Glass bends and refracts what is behind it, so the background gives it something to show.
struct AuroraBackground: View {
    var paused = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: paused)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let a = Float(sin(t / 5.0) * 0.07)
            let b = Float(cos(t / 6.5) * 0.07)
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5 + a, 0], [1, 0],
                    [0, 0.5 + b], [0.5 + b, 0.5 - a], [1, 0.5 - b],
                    [0, 1], [0.5 - a, 1], [1, 1],
                ],
                colors: [
                    Color(red: 0.10, green: 0.05, blue: 0.25), Color(red: 0.32, green: 0.14, blue: 0.62), Color(red: 0.07, green: 0.10, blue: 0.30),
                    Color(red: 0.45, green: 0.10, blue: 0.45), Color(red: 0.12, green: 0.06, blue: 0.22), Color(red: 0.10, green: 0.30, blue: 0.55),
                    Color(red: 0.06, green: 0.04, blue: 0.14), Color(red: 0.55, green: 0.15, blue: 0.40), Color(red: 0.05, green: 0.08, blue: 0.22),
                ]
            )
            .overlay(Color.black.opacity(0.18))
        }
    }
}

/// A small glass button with an icon and a label.
struct ChipButton: View {
    let title: String
    let symbol: String
    var isOn = false
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label(title, systemImage: symbol)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .buttonStyle(.glass)
        .tint(isOn ? Color.brand : nil)
        .controlSize(.small)
    }
}

/// A compact glass tile: icon over a tiny caption. Several fit in one row.
struct CompactTool: View {
    let title: String
    let symbol: String
    var isOn = false
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.system(size: 15, weight: .medium)).frame(height: 18)
                Text(title).font(.system(size: 10, weight: .medium)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .controlSize(.small)
        .tint(isOn ? Color.brand : (role == .destructive ? Color.red : nil))
        .accessibilityLabel(title)
    }
}

/// A one-line hint that replaces the big "unavailable" placeholders, so empty panels stay short.
struct HintRow: View {
    let symbol: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A round glass icon button.
struct GlassIconButton: View {
    let symbol: String
    let label: String
    var isOn = false
    var size: CGFloat = 32
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .frame(width: size, height: size)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.small)
        .tint(isOn ? Color.brand : nil)
        .accessibilityLabel(label)
    }
}

/// A labelled slider row.
struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double? = nil
    var format: (Double) -> String = { "\(Int($0.rounded()))" }
    var onEditing: ((Bool) -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 84, alignment: .leading)
            Group {
                if let step {
                    Slider(value: $value, in: range, step: step, onEditingChanged: { onEditing?($0) })
                } else {
                    Slider(value: $value, in: range, onEditingChanged: { onEditing?($0) })
                }
            }
            Text(format(value))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .trailing)
        }
    }
}

struct ToastView: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "exclamationmark.circle.fill")
            .font(.subheadline.weight(.medium))
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
            .padding(.horizontal, 16)
            .accessibilityAddTraits(.updatesFrequently)
    }
}
