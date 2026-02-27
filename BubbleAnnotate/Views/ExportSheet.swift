import SwiftUI
import UniformTypeIdentifiers

struct ExportSheet: View {
    @ObservedObject var exportEngine: ExportEngine
    let currentSettings: ExportSettings
    let onExport: () -> Void
    let onCancel: () -> Void

    @State private var isExporting = false

    init(exportEngine: ExportEngine, currentSettings: ExportSettings, onExport: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.exportEngine = exportEngine
        self.currentSettings = currentSettings
        self.onExport = onExport
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Export Video").font(.headline)

            Text("Exports at the original video size.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            progressSection

            HStack {
                Button("Cancel") { onCancel() }
                    .disabled(isExporting && exportEngine.progress.progress > 0 && !exportEngine.progress.isComplete)
                Spacer()
                if !isExporting {
                    Button("Export") {
                        isExporting = true
                        onExport()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .frame(width: 360)
        .onAppear {
            isExporting = false
            exportEngine.resetProgress()
        }
    }

    @ViewBuilder
    private var progressSection: some View {
        if let error = exportEngine.progress.error {
            Text(error.localizedDescription)
                .foregroundStyle(.red)
                .font(.caption)
                .multilineTextAlignment(.center)
        } else if isExporting {
            VStack(spacing: 8) {
                if exportEngine.progress.progress > 0 {
                    ProgressView(value: Double(exportEngine.progress.progress))
                        .progressViewStyle(.linear)
                    Text("\(Int(exportEngine.progress.progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                        .progressViewStyle(.linear)
                    Text("Preparing…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if exportEngine.progress.progress > 0 && !exportEngine.progress.isComplete {
                    Button("Cancel Export") { exportEngine.cancelExport() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                }
            }
        }
    }
}
