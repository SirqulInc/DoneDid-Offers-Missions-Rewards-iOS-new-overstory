//
//  DDWallPostCreateViewController.swift
//  DoneDid
//

import UIKit
import SNIWrapperKit
import SirqulBase
import SirqulSDK

class DDWallPostCreateViewController: UIViewController {

    @IBOutlet var textView: UITextView!
    var characterCount: UILabel!
    @IBOutlet var postButton: UIBarButtonItem!

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        let countLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 154, height: 21))
        countLabel.backgroundColor = .clear
        countLabel.textColor = .darkGray
        countLabel.shadowColor = UIColor(white: 0, alpha: 0.7)
        countLabel.shadowOffset = CGSize(width: 0, height: -1)
        countLabel.text = "0/140"
        self.characterCount = countLabel
        textView.inputAccessoryView = countLabel
        textView.textColor = .black
        textView.backgroundColor = .white

        NotificationCenter.default.addObserver(self, selector: #selector(textInputChanged(_:)), name: UITextField.textDidChangeNotification, object: textView)
        updateCharacterCount(textView)
        _ = checkCharacterCount(textView)

        textView.becomeFirstResponder()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: textView)
    }

    // MARK: - IBActions

    @IBAction func cancelPost(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func postPost(_ sender: Any) {
        textView.resignFirstResponder()
        updateCharacterCount(textView)
        guard checkCharacterCount(textView) else {
            textView.becomeFirstResponder()
            return
        }
        Task { await performPost() }
    }

    // MARK: - Async network helpers

    private func performPost() async {
        guard let appDelegate = UIApplication.shared.delegate as? DDAppDelegate else { return }
        guard let accountId = SNIWrapper.accountIdValue else { return }
        let title = textView.text ?? ""
        do {
			_ = try await SNIWrapper.shared.createAlbum(with: accountId, title: title, permissions: .default, visibility: kVisibilityPUBLIC, location: appDelegate.currentLocation, approvalStatus: kApprovalStatusNULL)
            NotificationCenter.default.post(name: NSNotification.Name(DDConstants.postCreatedNotification), object: nil)
            navigationController?.popViewController(animated: true)
        } catch {
            let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default))
            present(alert, animated: true)
        }
    }

    // MARK: - Text helpers

    @objc private func textInputChanged(_ note: Notification) {
        if let tv = note.object as? UITextView {
            updateCharacterCount(tv)
            _ = checkCharacterCount(tv)
        }
    }

    private func updateCharacterCount(_ aTextView: UITextView) {
        let count = aTextView.text.count
        characterCount.text = "\(count)/140"
        if count > Int(DDConstants.wallPostMaximumCharacterCount) || count == 0 {
            characterCount.font = UIFont.boldSystemFont(ofSize: characterCount.font.pointSize)
        } else {
            characterCount.font = UIFont.systemFont(ofSize: characterCount.font.pointSize)
        }
    }

    @discardableResult
    private func checkCharacterCount(_ aTextView: UITextView) -> Bool {
        let count = aTextView.text.count
        if count > Int(DDConstants.wallPostMaximumCharacterCount) || count == 0 {
            postButton.isEnabled = false
            return false
        } else {
            postButton.isEnabled = true
            return true
        }
    }
}
