//
//  DDLoginViewController.swift
//  DoneDid
//

import UIKit
import SNIWrapperKit
import SirqulSDK

class DDLoginViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet var doneButton: UIBarButtonItem!
    @IBOutlet var usernameField: UITextField!
    @IBOutlet var passwordField: UITextField!

    private var activityView: DDActivityView?

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
		NotificationCenter.default.addObserver(self, selector: #selector(textInputChanged(_:)), name: UITextField.textDidChangeNotification, object: usernameField)
        NotificationCenter.default.addObserver(self, selector: #selector(textInputChanged(_:)), name: UITextField.textDidChangeNotification, object: passwordField)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        doneButton.isEnabled = false
        usernameField.textColor = .black
        passwordField.textColor = .black
        usernameField.attributedPlaceholder = NSAttributedString(string: usernameField.placeholder ?? "", attributes: [.foregroundColor: UIColor.gray])
        passwordField.attributedPlaceholder = NSAttributedString(string: passwordField.placeholder ?? "", attributes: [.foregroundColor: UIColor.gray])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        usernameField.becomeFirstResponder()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: usernameField)
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: passwordField)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    // MARK: - IBActions

    @IBAction func cancel(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func done(_ sender: Any) {
        usernameField.resignFirstResponder()
        passwordField.resignFirstResponder()
        processFieldEntries()
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == usernameField {
            passwordField.becomeFirstResponder()
        }
        if textField == passwordField {
            passwordField.resignFirstResponder()
            processFieldEntries()
        }
        return true
    }

    // MARK: - Private

    private func shouldEnableDoneButton() -> Bool {
        guard let username = usernameField.text, !username.isEmpty,
              let password = passwordField.text, !password.isEmpty else {
            return false
        }
        return true
    }

    @objc private func textInputChanged(_ note: Notification) {
        doneButton.isEnabled = shouldEnableDoneButton()
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? UIView.AnimationOptions.curveEaseInOut.rawValue
        view.transform = .identity
        let keyboardTop = keyboardFrame.origin.y
        let fieldFrame = passwordField.convert(passwordField.bounds, to: nil)
        let fieldBottom = fieldFrame.maxY
        let padding: CGFloat = 20
        let overlap = fieldBottom + padding - keyboardTop
        if overlap > 0 {
            UIView.animate(withDuration: duration, delay: 0, options: UIView.AnimationOptions(rawValue: curveRaw)) {
                self.view.transform = CGAffineTransform(translationX: 0, y: -overlap)
            }
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? UIView.AnimationOptions.curveEaseInOut.rawValue
        UIView.animate(withDuration: duration, delay: 0, options: UIView.AnimationOptions(rawValue: curveRaw)) {
            self.view.transform = .identity
        }
    }

    private func processFieldEntries() {
        let username = usernameField.text ?? ""
        let password = passwordField.text ?? ""
        var errorText = "No "
        var textError = false

        if username.isEmpty || password.isEmpty {
            textError = true
            if password.isEmpty { passwordField.becomeFirstResponder() }
            if username.isEmpty { usernameField.becomeFirstResponder() }
        }
        if username.isEmpty {
            textError = true
            errorText += "username"
        }
        if password.isEmpty {
            textError = true
            if username.isEmpty { errorText += " or " }
            errorText += "password"
        }
        if textError {
            errorText += " entered"
            let alert = UIAlertController(title: errorText, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default))
            present(alert, animated: true)
            return
        }

        doneButton.isEnabled = false

        let av = DDActivityView(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height))
        av.label.text = "Logging in"
        av.label.font = UIFont.boldSystemFont(ofSize: 20)
        av.activityIndicator.startAnimating()
        av.layoutSubviews()
        view.addSubview(av)
        activityView = av

        Task { await performLogin(username: username, password: password) }
    }

    // MARK: - Async network helpers

    private func performLogin(username: String, password: String) async {
        do {
            let response = try await SNIWrapper.shared.login(withUserName: username, password: password)

            if let accountId = response?.loginAccountId {
                UserDefaults.standard.set(accountId, forKey: "accountId")
            }
            UserDefaults.standard.set(true, forKey: "loggedIn")

            activityView?.activityIndicator.stopAnimating()
            activityView?.removeFromSuperview()

            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let wallViewController = storyboard.instantiateViewController(withIdentifier: "DDWallViewController")
            let navController = UINavigationController(rootViewController: wallViewController)
            navController.isNavigationBarHidden = false
            guard let appDelegate = UIApplication.shared.delegate as? DDAppDelegate else { return }
            appDelegate.viewController = navController
            appDelegate.window?.rootViewController = navController
        } catch {
            activityView?.activityIndicator.stopAnimating()
            activityView?.removeFromSuperview()
            doneButton.isEnabled = shouldEnableDoneButton()

            let title = error.localizedDescription
            let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default))
            present(alert, animated: true)
            usernameField.becomeFirstResponder()
        }
    }
}
