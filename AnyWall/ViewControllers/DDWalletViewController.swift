//
//  DDWalletViewController.swift
//  DoneDid
//

import UIKit
import SNIWrapperKit
import SirqulBase
import SirqulSDK

class DDWalletViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var walletTableView: UITableView!

    private var walletItems: [OfferResponse] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await loadWalletItems() }
    }

    // MARK: - Async helpers

    private func loadWalletItems() async {
        do {
			let response = try await SNIWrapper.shared.searchWalletOffers(with: SNIWrapper.accountIdValue, keyword: nil, retailerId: nil, retailerLocationId: nil, offerType: kOfferTypeNULL, type: kSpecialOfferTypeNULL, sortField: kOfferTransactionApiMapNULL, audienceTypes: nil, start: 0, limit: 1000, redeemed: false, reservationsOnly: false, activeOnly: true)
            walletItems = response?.items ?? []
            walletTableView.reloadData()
        } catch {
            // no-op
        }
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return walletItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let offer = walletItems[indexPath.row]
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
        let offer = walletItems[indexPath.row]
        guard let odvc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "DDOfferDetailViewController") as? DDOfferDetailViewController else { return }
        odvc.configure(offer: offer, isFromWallet: true)
        navigationController?.pushViewController(odvc, animated: true)
    }
}
