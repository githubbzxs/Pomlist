import SwiftUI

struct MainTabView: View {
    @ObservedObject var serviceHub: PLServiceHub

    var body: some View {
        TodayCanvasView(serviceHub: serviceHub)
    }
}
