#if DEBUG
import SwiftUI
import UIKit

/// Device-only experiment. Never used as a production connection flow.
struct AutomationImportProbe: View {
    @StateObject private var importer = ProbeDocumentImporter()
    var body: some View {
        VStack(spacing: 24) {
            Text("AUTOMATION IMPORT TEST").font(.headline)
            Text("Target: App Store").font(.subheadline)
            Button("Import open signal") { importer.open("App opened — start session") }
            Button("Import close signal") { importer.open("Scroll Stopper Close Test") }
            Text(importer.message).font(.footnote)
        }.padding()
    }
}

private final class ProbeDocumentImporter: NSObject, ObservableObject, UIDocumentInteractionControllerDelegate {
    @Published var message = "Imports require confirmation in Shortcuts."
    private var document: UIDocumentInteractionController?
    func open(_ name: String) {
        guard let source = Bundle.main.url(forResource: name, withExtension: "shortcut", subdirectory: "AutomationProbes"),
              let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else {
            message = "Import file or window missing."
            return
        }
        var presenter = root
        while let presented = presenter.presentedViewController { presenter = presented }
        // Hand off a writable copy; the signed application bundle is not a
        // document location. Keep the original signed bytes unchanged.
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(source.lastPathComponent)
        do {
            let data = try Data(contentsOf: source)
            try data.write(to: destination, options: .atomic)
        } catch {
            message = error.localizedDescription
            return
        }
        let controller = UIDocumentInteractionController(url: destination)
        controller.uti = "com.apple.shortcut"
        controller.delegate = self
        document = controller
        if !controller.presentOpenInMenu(from: presenter.view.bounds, in: presenter.view, animated: true) {
            message = "No app accepted the shortcut file."
        }
    }
    func documentInteractionController(_ controller: UIDocumentInteractionController, didEndSendingToApplication application: String?) {
        message = "File handed off. Check Shortcuts for the import confirmation."
    }
}
#endif
