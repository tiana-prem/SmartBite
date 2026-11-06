import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            CameraView()
                .tabItem { Label("Scan", systemImage: "camera") }
            NavigationStack {
                IngredientsView(images: [])
            }
            .tabItem { Label("Ingredients", systemImage: "carrot") }
        }
        .tint(Color(red: 0.10, green: 0.29, blue: 0.22))
    }
}

#Preview { ContentView() }
