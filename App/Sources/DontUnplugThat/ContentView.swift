import DontUnplugThatShared
import SwiftUI

struct ContentView: View {
    @State var guide = FixtureGuide.make()
    @State var selectedDisplayNumber = 1

    var selectedComponentIndex: Int? {
        guide.components.firstIndex { component in
            component.displayNumber == selectedDisplayNumber
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                    AppHeaderView(componentCount: guide.components.count)
                    GuideTitleEditorView(title: $guide.title)
                    SetupCanvasView(
                        components: guide.components,
                        selectedDisplayNumber: $selectedDisplayNumber
                    )
                    ComponentStripView(
                        components: guide.components,
                        selectedDisplayNumber: $selectedDisplayNumber
                    )

                    if let selectedComponentIndex {
                        InstructionEditorView(component: $guide.components[selectedComponentIndex])
                    }
                }
                .padding(AppTheme.pagePadding)
            }
            .background(AppTheme.pageBackground)
            .navigationTitle("Don't Unplug That")
        }
        .tint(AppTheme.accent)
    }
}

#Preview {
    ContentView()
}
