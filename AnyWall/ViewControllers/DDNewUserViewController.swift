//
//  DDNewUserViewController.swift
//  DoneDid
//

import UIKit
import SNIWrapperKit
import SirqulSDK
import SirqulBase

class DDNewUserViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet var doneButton: UIBarButtonItem!
    @IBOutlet var usernameField: UITextField!
    @IBOutlet var passwordField: UITextField!
    @IBOutlet var passwordAgainField: UITextField!

    private var activityView: DDActivityView?

    // MARK: - UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
		NotificationCenter.default.addObserver(self, selector: #selector(textInputChanged(_:)), name: UITextField.textDidChangeNotification, object: usernameField)
        NotificationCenter.default.addObserver(self, selector: #selector(textInputChanged(_:)), name: UITextField.textDidChangeNotification, object: passwordField)
        NotificationCenter.default.addObserver(self, selector: #selector(textInputChanged(_:)), name: UITextField.textDidChangeNotification, object: passwordAgainField)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        doneButton.isEnabled = false
        usernameField.textColor = .black
        passwordField.textColor = .black
        passwordAgainField.textColor = .black
        usernameField.attributedPlaceholder = NSAttributedString(string: usernameField.placeholder ?? "", attributes: [.foregroundColor: UIColor.gray])
        passwordField.attributedPlaceholder = NSAttributedString(string: passwordField.placeholder ?? "", attributes: [.foregroundColor: UIColor.gray])
        passwordAgainField.attributedPlaceholder = NSAttributedString(string: passwordAgainField.placeholder ?? "", attributes: [.foregroundColor: UIColor.gray])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        usernameField.becomeFirstResponder()
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: usernameField)
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: passwordField)
        NotificationCenter.default.removeObserver(self, name: UITextField.textDidChangeNotification, object: passwordAgainField)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == usernameField {
            passwordField.becomeFirstResponder()
        } else if textField == passwordField {
            passwordAgainField.becomeFirstResponder()
        } else if textField == passwordAgainField {
            passwordAgainField.resignFirstResponder()
            processFieldEntries()
        }
        return true
    }

    // MARK: - Private

    private func shouldEnableDoneButton() -> Bool {
        guard let u = usernameField.text, !u.isEmpty,
              let p = passwordField.text, !p.isEmpty,
              let pa = passwordAgainField.text, !pa.isEmpty else {
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
        let fieldFrame = passwordAgainField.convert(passwordAgainField.bounds, to: nil)
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

    @IBAction func cancel(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func done(_ sender: Any) {
        usernameField.resignFirstResponder()
        passwordField.resignFirstResponder()
        passwordAgainField.resignFirstResponder()
        processFieldEntries()
    }

    private func processFieldEntries() {
        let username = usernameField.text ?? ""
        let password = passwordField.text ?? ""
        let passwordAgain = passwordAgainField.text ?? ""
        var errorText = "Please "
        var textError = false

        if username.isEmpty || password.isEmpty || passwordAgain.isEmpty {
            textError = true
            if passwordAgain.isEmpty { passwordAgainField.becomeFirstResponder() }
            if password.isEmpty { passwordField.becomeFirstResponder() }
            if username.isEmpty { usernameField.becomeFirstResponder() }
            if username.isEmpty { errorText += "enter a username" }
            if password.isEmpty || passwordAgain.isEmpty {
                if username.isEmpty { errorText += ", and " }
                errorText += "enter a password"
            }
        } else if password != passwordAgain {
            textError = true
            errorText += "enter the same password twice"
            passwordField.becomeFirstResponder()
        }

        if textError {
            let alert = UIAlertController(title: errorText, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default))
            present(alert, animated: true)
            return
        }

        doneButton.isEnabled = false
        let av = DDActivityView(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height))
        av.label.text = "Signing You Up"
        av.label.font = UIFont.boldSystemFont(ofSize: 20)
        av.activityIndicator.startAnimating()
        av.layoutSubviews()
        view.addSubview(av)
        activityView = av

        Task { await performSignUp(username: username, password: password) }
    }

    // MARK: - Async network helpers

    private func performSignUp(username: String, password: String) async {
        do {
            _ = try await SNIWrapper.shared.createNewAccount(withUserName: username, firstName: nil, lastName: nil, password: password, email: nil, role: kRoleMEMBER)

            let loginResponse = try await SNIWrapper.shared.login(withUserName: username, password: password)

            if let accountId = loginResponse?.loginAccountId {
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
            let alert = UIAlertController(title: error.localizedDescription, message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default))
            present(alert, animated: true)
            doneButton.isEnabled = shouldEnableDoneButton()
            activityView?.activityIndicator.stopAnimating()
            activityView?.removeFromSuperview()
            usernameField.becomeFirstResponder()
        }
    }
}
