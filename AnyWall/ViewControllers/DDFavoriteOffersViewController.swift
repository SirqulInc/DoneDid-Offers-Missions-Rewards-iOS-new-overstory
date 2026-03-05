//
//  DDFavoriteOffersViewController.swift
//  DoneDid
//

import UIKit
import SNIWrapperKit
import SirqulSDK
import SirqulBase

class DDFavoriteOffersViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var favoritesTableView: UITableView!

    private var favorites: [OfferResponse] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = editButtonItem
        Task { await loadFavorites() }
    }

    // MARK: - Async helpers

    private func fetchFavorites() async throws -> SearchResponse<OfferResponse>? {
        // TODO: No async wrapper available for getFavorites in SNIWrapperKit yet
        throw SDKError.unknown
    }

    private func loadFavorites() async {
        do {
            let response = try await fetchFavorites()
            favorites = response?.items ?? []
            favoritesTableView.reloadData()
        } catch {
            // no-op
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return favorites.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let offer = favorites[indexPath.row]
        let theId = offer.offerLocationId != 0 ? offer.offerLocationId : offer.offerId
        let identifier = "offer-\(theId)-row-\(indexPath.row)"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier) ?? {
            let c = UITableViewCell(style: .subtitle, reuseIdentifier: identifier)
            c.selectionStyle = .none
            c.accessoryType = .disclosureIndicator
            return c
        }()
        cell.textLabel?.text = offer.offerName
        cell.detailTextLabel?.text = offer.details
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let offer = favorites[indexPath.row]
        guard let odvc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "DDOfferDetailViewController") as? DDOfferDetailViewController else { return }
        odvc.configure(offer: offer, isFromWallet: true)
        navigationController?.pushViewController(odvc, animated: true)
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

	func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let offer = favorites[indexPath.row]
        let favoritableId = offer.offerLocationId != 0 ? offer.offerLocationId : offer.offerId
        Task { let _ = try? await SNIWrapper.shared.removeFavorite(with: nil, favoritableId: favoritableId, favoritableType: "OFFER_LOCATION") }
        favorites.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        favoritesTableView.isEditing = editing
    }
}

