import SwiftUI

struct LayerPanelView: View {
    @ObservedObject var stack: LayerStack

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(stack.layers.enumerated().reversed()), id: \.element.id) { i, layer in
                    LayerRowView(
                        layer: layer,
                        isActive: i == stack.activeIndex,
                        onSelect:  { stack.setActive(i) },
                        onToggle:  { stack.toggleVisibility(at: i) },
                        onOpacity: { stack.setOpacity($0, at: i) },
                        onDelete:  { stack.deleteLayer(at: i) }
                    )
                    .listRowBackground(
                        i == stack.activeIndex
                            ? Color.accentColor.opacity(0.12)
                            : Color.clear
                    )
                }
                .onMove { source, dest in
                    // List is displayed reversed so we invert the move
                    let count = stack.layers.count
                    let realSource = IndexSet(source.map { count - 1 - $0 })
                    let realDest   = count - dest
                    stack.move(from: realSource, to: realDest)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Layers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        stack.addLayer()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Layer row

private struct LayerRowView: View {
    let layer: CanvasLayer
    let isActive: Bool
    let onSelect:  () -> Void
    let onToggle:  () -> Void
    let onOpacity: (Float) -> Void
    let onDelete:  () -> Void

    @State private var showOpacity = false
    @State private var localOpacity: Float

    init(layer: CanvasLayer, isActive: Bool,
         onSelect: @escaping () -> Void, onToggle: @escaping () -> Void,
         onOpacity: @escaping (Float) -> Void, onDelete: @escaping () -> Void) {
        self.layer     = layer
        self.isActive  = isActive
        self.onSelect  = onSelect
        self.onToggle  = onToggle
        self.onOpacity = onOpacity
        self.onDelete  = onDelete
        _localOpacity  = State(initialValue: layer.opacity)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Layer thumbnail placeholder (real thumbnails Sprint 6+)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )

                // Name + opacity label
                VStack(alignment: .leading, spacing: 2) {
                    Text(layer.name)
                        .font(.body)
                    Text("\(Int(localOpacity * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Visibility eye
                Button(action: onToggle) {
                    Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                        .foregroundStyle(layer.isVisible ? .primary : .tertiary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelect() }
            .onLongPressGesture { withAnimation { showOpacity.toggle() } }

            // Inline opacity slider (revealed on long press)
            if showOpacity {
                HStack(spacing: 8) {
                    Image(systemName: "circle.lefthalf.filled")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Slider(value: Binding(
                        get: { Double(localOpacity) },
                        set: { v in
                            localOpacity = Float(v)
                            onOpacity(localOpacity)
                        }
                    ), in: 0.05...1)
                    Text("\(Int(localOpacity * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.vertical, 6)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
