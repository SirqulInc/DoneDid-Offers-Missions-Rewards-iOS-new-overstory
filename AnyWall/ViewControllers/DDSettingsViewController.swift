//
//  DDSettingsViewController.swift
//  DoneDid
//

import UIKit
import CoreLocation
import SNIWrapperKit
import SirqulBase

private enum SettingsSection: Int {
    case distance = 0
    case logout
    case count
}

private enum DistanceRow: Int {
    case feet250 = 0
    case feet1000
    case feet4000
    case count
}

private enum LogoutButton: Int {
    case logout = 0
    case cancel
}

private let logoutSectionRowCount: Int = 1

class DDSettingsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet var tableView: UITableView!

    var filterDistance: CLLocationAccuracy {
        get { return _filterDistance }
        set {
            guard let appDelegate = UIApplication.shared.delegate as? DDAppDelegate else { return }
            appDelegate.filterDistance = newValue
            _filterDistance = newValue
        }
    }
    private var _filterDistance: CLLocationAccuracy = 0

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        if let appDelegate = UIApplication.shared.delegate as? DDAppDelegate {
            _filterDistance = appDelegate.filterDistance
        }
    }

    // MARK: - Private helpers

    private func distanceLabel(for indexPath: IndexPath) -> String {
        switch DistanceRow(rawValue: indexPath.row) {
        case .feet250?: return "250 feet"
        case .feet1000?: return "1000 feet"
        case .feet4000?: return "4000 feet"
        default: return "The universe"
        }
    }

    private func distanceForCell(at indexPath: IndexPath) -> CLLocationAccuracy {
        switch DistanceRow(rawValue: indexPath.row) {
        case .feet250?: return 250
        case .feet1000?: return 1000
        case .feet4000?: return 4000
        default: return 10000 * DDConstants.feetToMiles
        }
    }

    @IBAction func done(_ sender: Any) {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return SettingsSection.count.rawValue
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch SettingsSection(rawValue: section) {
        case .distance?: return DistanceRow.count.rawValue
        case .logout?: return logoutSectionRowCount
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = "SettingsTableView"
        if indexPath.section == SettingsSection.distance.rawValue {
            let cell = tableView.dequeueReusableCell(withIdentifier: identifier) ?? UITableViewCell(style: .default, reuseIdentifier: identifier)
            cell.backgroundColor = .white
            cell.textLabel?.textColor = .black
            cell.textLabel?.text = distanceLabel(for: indexPath)
            let filterDistanceInFeet = filterDistance * (1 / DDConstants.feetToMeters)
            let distForCell = distanceForCell(at: indexPath)
            cell.accessoryType = abs(distForCell - filterDistanceInFeet) < 0.001 ? .checkmark : .none
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: identifier) ?? UITableViewCell(style: .default, reuseIdentifier: identifier)
            cell.backgroundColor = .white
            cell.textLabel?.textColor = .black
            cell.textLabel?.text = "Log out of DoneDid"
            cell.textLabel?.textAlignment = .center
            return cell
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch SettingsSection(rawValue: section) {
        case .distance?: return "Search Distance"
        default: return ""
        }
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = .darkGray
        }
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == SettingsSection.distance.rawValue {
            tableView.deselectRow(at: indexPath, animated: true)
            guard let selectedCell = tableView.cellForRow(at: indexPath),
                  selectedCell.accessoryType != .checkmark else { return }

            for cell in tableView.visibleCells {
                cell.accessoryType = .none
            }
            selectedCell.accessoryType = .checkmark
            filterDistance = distanceForCell(at: indexPath) * DDConstants.feetToMeters

        } else if indexPath.section == SettingsSection.logout.rawValue {
            tableView.deselectRow(at: indexPath, animated: true)
            let alert = UIAlertController(title: "Log out of DoneDid?", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Log out", style: .destructive) { [weak self] _ in
                Task { await self?.performLogout() }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            present(alert, animated: true)
        }
    }

    private func performLogout() async {
        do {
            _ = try await logoutRequest()
        } catch {
            // no-op
        }
        UserDefaults.standard.set(false, forKey: "loggedIn")
        guard let appDelegate = UIApplication.shared.delegate as? DDAppDelegate else { return }
        appDelegate.presentWelcomeViewController()
    }

    private func logoutRequest() async throws -> SirqulResponse? {
		guard let accountId = SNIWrapper.accountIdValue else { throw SDKError.authErr }
		return try await SNIWrapper.shared.logout(with: accountId)
    }
}
