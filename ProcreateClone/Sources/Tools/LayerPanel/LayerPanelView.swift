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
                        onSelect:    { stack.setActive(i) },
                        onToggle:    { stack.toggleVisibility(at: i) },
                        onOpacity:   { stack.setOpacity($0, at: i) },
                        onBlendMode: { stack.setBlendMode($0, at: i) },
                        onDelete:    { stack.deleteLayer(at: i) }
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
    let onSelect:    () -> Void
    let onToggle:    () -> Void
    let onOpacity:   (Float) -> Void
    let onBlendMode: (LayerBlendMode) -> Void
    let onDelete:    () -> Void

    @State private var showOptions   = false
    @State private var localOpacity: Float
    @State private var localMode:    LayerBlendMode

    init(layer: CanvasLayer, isActive: Bool,
         onSelect: @escaping () -> Void, onToggle: @escaping () -> Void,
         onOpacity: @escaping (Float) -> Void, onBlendMode: @escaping (LayerBlendMode) -> Void,
         onDelete: @escaping () -> Void) {
        self.layer       = layer
        self.isActive    = isActive
        self.onSelect    = onSelect
        self.onToggle    = onToggle
        self.onOpacity   = onOpacity
        self.onBlendMode = onBlendMode
        self.onDelete    = onDelete
        _localOpacity    = State(initialValue: layer.opacity)
        _localMode       = State(initialValue: layer.blendMode)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Layer thumbnail placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )

                // Name + blend mode + opacity label
                VStack(alignment: .leading, spacing: 2) {
                    Text(layer.name)
                        .font(.body)
                    HStack(spacing: 6) {
                        if localMode != .normal {
                            Text(localMode.displayName)
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                        }
                        Text("\(Int(localOpacity * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
            .onLongPressGesture { withAnimation { showOptions.toggle() } }

            // Inline opacity + blend mode controls (revealed on long press)
            if showOptions {
                VStack(spacing: 10) {
                    // Opacity slider
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

                    // Blend mode picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(LayerBlendMode.allCases) { mode in
                                Button {
                                    localMode = mode
                                    onBlendMode(mode)
                                } label: {
                                    Text(mode.displayName)
                                        .font(.caption.weight(localMode == mode ? .semibold : .regular))
                                        .foregroundStyle(localMode == mode ? Color.white : Color.primary)
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(
                                            Capsule().fill(localMode == mode ? Color.accentColor : Color.secondary.opacity(0.15))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
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
