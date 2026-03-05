//
//  DDWelcomeViewController.swift
//  DoneDid
//

import UIKit

class DDWelcomeViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Transition methods

    @IBAction func loginButtonSelected(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Auth", bundle: nil)
        let loginViewController = storyboard.instantiateViewController(withIdentifier: "DDLoginViewController")
        navigationController?.pushViewController(loginViewController, animated: true)
    }

    @IBAction func createButtonSelected(_ sender: Any) {
        let storyboard = UIStoryboard(name: "Auth", bundle: nil)
        let newUserViewController = storyboard.instantiateViewController(withIdentifier: "DDNewUserViewController")
        navigationController?.pushViewController(newUserViewController, animated: true)
    }

    @IBAction func gotoSirqul(_ sender: Any) {
        if let url = URL(string: "https://www.sirqul.com/") {
            UIApplication.shared.openURL(url)
        }
    }
}
