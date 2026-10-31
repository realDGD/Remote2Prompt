import VoiRemoteCore
import SwiftUI

/// Independently drawn from the RC003 key geometry; no vendor logo or photo assets.
struct RemoteDiagram: View {
    @Binding var selection: RemoteButton?
    let active: Set<RemoteButton>
    let voiceHeld: Bool
    var onSelection: () -> Void = {}
    private let dark = Color(white: 0.20)

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                key(.power, "power", light: true, size: 42)
                Spacer()
                key(nil, "mic", light: true, size: 42)
            }
            .padding(.horizontal, 4)
            ZStack {
                Circle().fill(LinearGradient(colors: [Color(white: 0.24), Color(white: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().stroke(Color.black.opacity(0.4), lineWidth: 2)
                direction(.up, start: -135, dot: CGPoint(x: 74, y: 7))
                direction(.right, start: -45, dot: CGPoint(x: 141, y: 74))
                direction(.down, start: 45, dot: CGPoint(x: 74, y: 141))
                direction(.left, start: 135, dot: CGPoint(x: 7, y: 74))
                key(.select, nil, size: 70)
            }.frame(width: 148, height: 148)
            HStack(alignment: .top, spacing: 27) {
                VStack(spacing: 0) {
                    key(.back, "arrow.uturn.backward").frame(height: 56)
                    key(.home, "house").frame(height: 56)
                    key(.menu, "line.3.horizontal").frame(height: 56)
                }
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        volume(.volumeUp, "plus")
                        Divider().overlay(Color.white.opacity(0.08))
                        volume(.volumeDown, "minus")
                    }
                    .frame(width: 48, height: 112)
                    .background(LinearGradient(colors: [Color(white: 0.27), Color(white: 0.15)], startPoint: .top, endPoint: .bottom), in: Capsule())
                    .overlay(Capsule().stroke(Color.black.opacity(0.5)))
                    key(.tv, "tv").frame(height: 56)
                }
            }
            Spacer(minLength: 45)
        }
        .padding(.horizontal, 16).padding(.top, 24).padding(.bottom, 24)
        .frame(width: 186, height: 690)
        .background(LinearGradient(stops: [.init(color: Color(white: 0.60), location: 0), .init(color: Color(white: 0.92), location: 0.05), .init(color: Color(white: 0.78), location: 0.18), .init(color: Color(white: 0.84), location: 0.85), .init(color: Color(white: 0.55), location: 1)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.black.opacity(0.25)))
    }

    private func key(_ button: RemoteButton?, _ symbol: String?, light: Bool = false, size: CGFloat = 48) -> some View {
        let pressed = button.map { active.contains($0) } ?? voiceHeld
        return Button { selection = button; onSelection() } label: {
            ZStack {
                Circle().fill(light ? Color(white: 0.85) : dark)
                if button == .tv {
                    Text("TV").font(.system(size: 10, weight: .semibold)).padding(.horizontal, 3).padding(.vertical, 1)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color(white: 0.7), lineWidth: 1.3)).foregroundStyle(Color(white: 0.7))
                } else if let symbol { Image(systemName: symbol).font(.system(size: 19, weight: .regular)).foregroundStyle(light ? Color(white: 0.30) : Color(white: 0.72)) }
                Circle().stroke(pressed ? .green : selection == button ? Color.accentColor : Color(white: light ? 0.54 : 0.46), lineWidth: pressed || selection == button ? 2 : 1)
            }.frame(width: size, height: size)
        }
        .buttonStyle(.plain).accessibilityLabel("选择\(button?.title ?? "语音")键")
        .accessibilityValue(pressed ? "按住中" : selection == button ? "已选择" : "")
        .help(button?.title ?? "语音键")
    }

    private func direction(_ button: RemoteButton, start: Double, dot: CGPoint) -> some View {
        let selected = selection == button
        return Button { selection = button; onSelection() } label: {
            ZStack {
                RingSector(start: start).fill(active.contains(button) ? Color.green.opacity(0.5) : selected ? Color.accentColor.opacity(0.35) : .clear)
                Circle().fill(Color.black.opacity(0.5)).frame(width: 2, height: 2).position(dot)
            }.frame(width: 148, height: 148).contentShape(RingSector(start: start))
        }
        .buttonStyle(.plain).accessibilityLabel("选择\(button.title)键").help(button.title)
    }

    private func volume(_ button: RemoteButton, _ symbol: String) -> some View {
        Button { selection = button; onSelection() } label: {
            Image(systemName: symbol).font(.system(size: 20)).foregroundStyle(Color(white: 0.7))
                .frame(width: 48, height: 55)
                .background(active.contains(button) ? Color.green.opacity(0.4) : selection == button ? Color.accentColor.opacity(0.3) : .clear)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel("选择\(button.title)键")
    }
}

private struct RingSector: Shape {
    let start: Double
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: .degrees(start), endAngle: .degrees(start + 90), clockwise: false)
        path.addArc(center: center, radius: 39, startAngle: .degrees(start + 90), endAngle: .degrees(start), clockwise: true)
        path.closeSubpath()
        return path
    }
}
