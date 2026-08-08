import SwiftUI

enum ConflictResolution {
    case useCloud
    case overwriteCloud
    case saveAsNew
}

struct GuideConflictView: View {
    let conflict: LocalGuideConflict
    let isDisabled: Bool
    let resolve: (ConflictResolution) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.compactSpacing) {
            Text(conflict.kind == .deleted ? "Deleted on another device" : "Changed on another device")
                .font(.headline)
                .foregroundStyle(AppTheme.warning)
            Text("Choose which copy to keep. We never merge equipment guidance automatically.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Use cloud") { resolve(.useCloud) }
                    .buttonStyle(.bordered)
                    .disabled(isDisabled)
                Button("Overwrite") { resolve(.overwriteCloud) }
                    .buttonStyle(.bordered)
                    .disabled(isDisabled || conflict.current == nil)
                Button("Save as new") { resolve(.saveAsNew) }
                    .buttonStyle(.borderedProminent)
                    .disabled(isDisabled)
            }
        }
    }
}
