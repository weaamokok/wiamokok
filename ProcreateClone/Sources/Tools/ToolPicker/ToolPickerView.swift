import SwiftUI

struct ToolPickerView: View {
    @Binding var activeTool: DrawingTool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(DrawingTool.allCases) { tool in
                Button {
                    activeTool = tool
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tool.icon)
                            .font(.system(size: 16, weight: activeTool == tool ? .semibold : .regular))
                            .frame(width: 36, height: 36)
                    }
                    .foregroundStyle(activeTool == tool ? Color.accentColor : .primary)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(activeTool == tool
                                  ? Color.accentColor.opacity(0.15)
                                  : Color.clear)
                    )
                }
                .animation(.spring(response: 0.2), value: activeTool)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
