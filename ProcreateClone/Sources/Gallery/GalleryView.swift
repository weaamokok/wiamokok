import SwiftUI

struct GalleryView: View {
    @State private var openCanvas = false

    var body: some View {
        NavigationStack {
            VStack {
                Text("Your Artworks")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 60)

                Spacer()

                Button {
                    openCanvas = true
                } label: {
                    Label("New Drawing", systemImage: "plus.circle.fill")
                        .font(.title3)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }

                Spacer()
            }
            .navigationTitle("Wia Draw")
            .fullScreenCover(isPresented: $openCanvas) {
                CanvasContainerView()
            }
        }
    }
}
