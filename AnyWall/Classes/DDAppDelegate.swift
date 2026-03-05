//
//  DDAppDelegate.swift
//  DoneDid
//

import UIKit
import AppTrackingTransparency
import CoreLocation
import SNIWrapperKit
import SirqulBase

private let defaultsFilterDistanceKey = "filterDistance"
private let defaultsLocationKey = "currentLocation"

@main
class DDAppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var viewController: UIViewController?

    var filterDistance: CLLocationAccuracy {
        didSet {
            let userDefaults = UserDefaults.standard
            userDefaults.set(filterDistance, forKey: defaultsFilterDistanceKey)

            let userInfo: [String: Any] = [DDConstants.filterDistanceKey: filterDistance]
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name(DDConstants.filterDistanceChangeNotification), object: nil, userInfo: userInfo)
            }
        }
    }

    var currentLocation: CLLocation? {
        didSet {
            guard let loc = currentLocation else { return }
            let userInfo: [String: Any] = [DDConstants.locationKey: loc]
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: NSNotification.Name(DDConstants.locationChangeNotification), object: nil, userInfo: userInfo)
            }
        }
    }

    override init() {
        filterDistance = 0
        super.init()
    }

    // MARK: - UIApplicationDelegate

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
		
		let _ = SirqulLocationManager.shared.estimatedLocation()
        let userDefaults = UserDefaults.standard

        UINavigationBar.appearance().tintColor = UIColor(red: 200.0/255.0, green: 83.0/255.0, blue: 70.0/255.0, alpha: 1.0)
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.black]
        UINavigationBar.appearance().barTintColor = .white

        let savedDistance = userDefaults.double(forKey: defaultsFilterDistanceKey)
        if savedDistance != 0 {
            filterDistance = savedDistance
        } else {
            self.filterDistance = 1000 * DDConstants.feetToMeters
        }

        if userDefaults.bool(forKey: "loggedIn") {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let wallViewController = storyboard.instantiateViewController(withIdentifier: "DDWallViewController")
            let navController = UINavigationController(rootViewController: wallViewController)
            navController.isNavigationBarHidden = false
            self.viewController = navController
            self.window?.rootViewController = self.viewController
        } else {
            presentWelcomeViewController()
        }
		
		SirqulConfig.shared.settings = SirqulSettings(
			host: "https://www.sirqul.com:443/",
			appKey: DDConstants.sirqulAppKey,
			privateKey: DDConstants.sirqulPrivateKey,
			executiveAccountId: 1,
			appName: "DoneDid"
		)

        SNIWrapper.shared.submitAnalytics(with: "AppLaunched") { _ in }

        window?.overrideUserInterfaceStyle = .light
        window?.makeKeyAndVisible()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { _ in }
        }
        return true
    }

    // MARK: - DDAppDelegate

    func presentWelcomeViewController() {
        let storyboard = UIStoryboard(name: "Auth", bundle: nil)
        guard let welcomeViewController = storyboard.instantiateViewController(withIdentifier: "DDWelcomeViewController") as? DDWelcomeViewController else { return }
        welcomeViewController.title = "Welcome to DoneDid"

        let navController = UINavigationController(rootViewController: welcomeViewController)
        navController.isNavigationBarHidden = true

        self.viewController = navController
        self.window?.rootViewController = self.viewController
    }
}
