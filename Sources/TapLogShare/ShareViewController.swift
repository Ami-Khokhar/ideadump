import UIKit
import SwiftData
import UniformTypeIdentifiers

/// Share-extension entry point (com.apple.share-services). Parses a shared text — usually
/// a bank payment SMS — and saves a pending entry the user confirms inside the app.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let text = extractTextFromContext()
        let parsed = ShareParser.parse(text)
        savePendingEntry(amount: parsed.amount, note: parsed.note)

        let message = parsed.amount.map {
            "Saved \(Money.format($0)) to TapLog — confirm it in the app."
        } ?? "No amount found. A pending entry was saved — check TapLog."

        let label = UILabel()
        label.text = message
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .body)
        label.translatesAutoresizingMaskIntoConstraints = false

        let doneButton = UIButton(type: .system)
        doneButton.setTitle("Done", for: .normal)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        doneButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(label)
        view.addSubview(doneButton)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -48),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            doneButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            doneButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
        ])
    }

    @objc private func doneTapped() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func savePendingEntry(amount: Decimal?, note: String?) {
        let container = StoreLocator.makeContainer()
        let context = container.mainContext
        let entry = Entry(
            amount: amount ?? 0,
            category: SpendCategory.defaultKey,
            note: note,
            isPending: true
        )
        context.insert(entry)
        try? context.save()
    }

    private func extractTextFromContext() -> String {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return "" }
        var text = ""
        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                guard provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) else { continue }
                let semaphore = DispatchSemaphore(value: 0)
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { result, _ in
                    if let string = result as? String {
                        text = string
                    }
                    semaphore.signal()
                }
                semaphore.wait()
            }
        }
        return text
    }
}
