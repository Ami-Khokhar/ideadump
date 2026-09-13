import UIKit
import SwiftData
import UniformTypeIdentifiers

/// Share-extension entry point (com.apple.share-services). Parses a shared text — usually
/// a bank payment SMS — and saves a pending entry the user confirms inside the app.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .body)
        label.translatesAutoresizingMaskIntoConstraints = false

        let doneButton = UIButton(type: .system)
        doneButton.setTitle("Done", for: .normal)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.isHidden = true

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

        // Load text asynchronously — never block the UI thread
        extractTextFromContext { [weak self] text in
            guard let self else { return }
            let parsed = ShareParser.parse(text)

            guard let amount = parsed.amount, amount > 0 else {
                DispatchQueue.main.async {
                    label.text = "Couldn't find an amount to log. Open TapLog to enter it manually."
                    doneButton.isHidden = false
                }
                return
            }

            let saved = self.savePendingEntry(amount: amount, note: parsed.note)
            DispatchQueue.main.async {
                if saved {
                    label.text = "Saved \(Money.format(amount)) to TapLog — confirm it in the app."
                } else {
                    label.text = "Failed to save. Open TapLog and log \(Money.format(amount)) manually."
                }
                doneButton.isHidden = false
            }
        }
    }

    @objc private func doneTapped() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    @discardableResult
    private func savePendingEntry(amount: Decimal, note: String?) -> Bool {
        // `makeContainer()` traps when no candidate store opens. That is the right
        // answer for the app — there is nothing to show without a store — but here
        // it kills the share sheet with no message, from inside somebody else's
        // app, while they are looking at it. Failing returns false and the caller
        // already has the label for it.
        guard let container = try? StoreLocator.container() else {
            Log.share.error("No usable store — cannot save pending entry")
            return false
        }
        let context = container.mainContext
        // Pending entries land in the neutral "Other" bucket — attribution is the
        // user's decision when they confirm it in the app.
        let entry = Entry(
            amount: amount,
            category: SpendCategory.fallbackKey,
            note: note,
            isPending: true
        )
        context.insert(entry)
        do {
            try context.save()
            return true
        } catch {
            Log.share.error("Failed to save pending entry: \(Log.describe(error), privacy: .public)")
            // Remove the orphaned in-memory object
            context.delete(entry)
            return false
        }
    }

    /// Loads shared text asynchronously via completion handler instead of a blocking semaphore.
    private func extractTextFromContext(completion: @escaping (String) -> Void) {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            completion("")
            return
        }

        var textParts: [String] = []
        let accumulationQueue = DispatchQueue(label: "dev.amteshwar.taplog.share-text-accumulation")
        let group = DispatchGroup()

        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                guard provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) else { continue }
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { result, _ in
                    if let string = result as? String {
                        accumulationQueue.sync {
                            textParts.append(string)
                        }
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: accumulationQueue) {
            let allText = textParts.joined(separator: " ")
            DispatchQueue.main.async {
                completion(allText.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }
}
