//
//  DDOfferDetailViewController.swift
//  DoneDid
//

import UIKit
import SNIWrapperKit
import SirqulSDK
import SirqulBase

class DDOfferDetailViewController: UIViewController {

    @IBOutlet var imagesScrollView: UIScrollView!
    @IBOutlet var textScrollView: UIScrollView!
    @IBOutlet var offerButton: UIButton!
    @IBOutlet var offerNameLabel: UILabel!
    @IBOutlet var offerDetailsLabel: UILabel!
    @IBOutlet weak var favoriteButton: UIButton!

    var typedOffer: OfferResponse?
    private var offerLocationId: Int = 0
    private var transactionId: Int = 0
    var cameFromWallet: Bool = false

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func configure(offer anOffer: OfferResponse, isFromWallet wallet: Bool) {
        self.typedOffer = anOffer
        self.cameFromWallet = wallet
        self.transactionId = anOffer.transactionId
        self.offerLocationId = anOffer.offerLocationId
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let offer = typedOffer, offer.offerLocationId != 0 {
            offerLocationId = offer.offerLocationId
            Task { await loadOfferDetails() }
        }
        setUpView(withImages: false)
        styleButtons()
    }

    // MARK: - Async network helpers

    private func loadOfferDetails() async {
        do {
            let result: OfferResponse?
            if cameFromWallet {
                result = try await fetchOfferTransaction()
            } else {
                result = try await fetchOfferDetails()
            }
            guard let result = result, result.valid == true else { return }
            typedOffer = result
            setUpView(withImages: true)
        } catch {
            print("[DDOfferDetail] Load offer details failed: \(error)")
        }
    }

    private func fetchOfferTransaction() async throws -> OfferTransactionResponse? {
        let accountId = (UserDefaults.standard.object(forKey: "accountId") as? NSNumber)?.intValue
        return try await SNIWrapper.shared.getWalletOffer(accountId: accountId, transactionId: self.transactionId)
    }

    private func fetchOfferDetails() async throws -> OfferResponse? {
        guard let accountId = SNIWrapper.accountIdValue else { return nil }
        return try await SNIWrapper.shared.getOffer(with: accountId, offerId: nil, offerLocationId: self.offerLocationId)
    }

    private func updateWalletStatus() async throws -> OfferTransactionResponse? {
        let accountId = (UserDefaults.standard.object(forKey: "accountId") as? NSNumber)?.intValue
        let _ = try await SNIWrapper.shared.updateWalletOfferStatus(accountId: accountId, transactionId: self.transactionId, status: true)
        return try await SNIWrapper.shared.getWalletOffer(accountId: accountId, transactionId: self.transactionId)
    }

    private func createMissionInvite(missionId: NSNumber) async throws -> [AnyHashable: Any]? {
        return try await SNIWrapper.shared.createMissionInvite(accountId: UserDefaults.standard.object(forKey: "accountId") as? NSNumber, missionId: missionId)
    }

    private func addWalletOffer() async throws -> [AnyHashable: Any]? {
        return try await SNIWrapper.shared.addWalletOffer(accountId: UserDefaults.standard.object(forKey: "accountId") as? NSNumber, offerLocationId: self.offerLocationId)
    }

    private func addFavoriteOffer(favoritableId: Int) async throws {
        let _: SirqulResponse? = try await SNIWrapper.shared.addFavorite(with: favoritableId, favoritableType: "OFFER_LOCATION")
    }

    private func removeFavoriteOffer(favoritableId: Int) async throws {
        let _ = try await SNIWrapper.shared.removeFavorite(with: nil, favoritableId: favoritableId, favoritableType: "OFFER_LOCATION")
    }

    // MARK: - View setup

    private var imagesHeightConstraint: NSLayoutConstraint? {
        imagesScrollView.constraints.first { $0.firstAttribute == .height }
    }

    private func setUpView(withImages showImages: Bool) {
        guard let offer = typedOffer else { return }

        if cameFromWallet {
            offerButton.setTitle("Use Now", for: .normal)
        } else if offerHasMissions() {
            offerButton.setTitle("Start Mission", for: .normal)
        } else {
            offerButton.setTitle("Save to your wallet", for: .normal)
        }

        title = offer.locationName ?? "Offer Detail"
        favoriteButton.isSelected = offer.favorite

        var thereAreImages = false
        if showImages, let images = offer.images {
            for image in images {
                if let urlStr = image.fullURL {
                    thereAreImages = true
                    loadImage(urlString: urlStr)
                }
            }
        }

        if !thereAreImages {
            imagesScrollView.isHidden = true
            imagesHeightConstraint?.constant = 0
        } else {
            imagesScrollView.isHidden = false
            imagesHeightConstraint?.constant = 160
        }

        offerNameLabel.text = offer.offerName
        offerNameLabel.numberOfLines = 0
        offerNameLabel.textColor = UIColor(red: 224/255, green: 168/255, blue: 71/255, alpha: 1)

        var detailsString = ""
        if let subTitle = offer.subTitle {
            detailsString += subTitle
        }
        if let details = offer.details {
            detailsString += "\n\n\(details)"
        }
        offerDetailsLabel.text = detailsString
        offerDetailsLabel.numberOfLines = 0
    }

    private func styleButtons() {
        let goldColor = UIColor(red: 224/255, green: 168/255, blue: 71/255, alpha: 1)
        offerButton.backgroundColor = goldColor
        offerButton.setTitleColor(.white, for: .normal)
        offerButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        offerButton.layer.cornerRadius = 8
        offerButton.clipsToBounds = true
        offerButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)

        if #available(iOS 15.0, *) {
            favoriteButton.configuration = nil
        }

        let heartConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let emptyHeart = UIImage(systemName: "heart", withConfiguration: heartConfig)?.withRenderingMode(.alwaysTemplate)
        let filledHeart = UIImage(systemName: "heart.fill", withConfiguration: heartConfig)?.withRenderingMode(.alwaysTemplate)
        favoriteButton.setImage(emptyHeart, for: .normal)
        favoriteButton.setImage(filledHeart, for: .selected)
        favoriteButton.setTitle(nil, for: .normal)
        favoriteButton.setTitle(nil, for: .selected)
        favoriteButton.setTitle(nil, for: .highlighted)
        favoriteButton.setTitle(nil, for: [.selected, .highlighted])
        favoriteButton.tintColor = goldColor
    }

    private func loadImage(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, let data = data else { return }
            DispatchQueue.main.async {
                let imageView = UIImageView(image: UIImage(data: data))
                imageView.contentMode = .scaleAspectFit
                imageView.frame = CGRect(x: self.imagesScrollView.contentSize.width, y: 0, width: self.imagesScrollView.frame.size.width, height: self.imagesScrollView.frame.size.height)
                self.imagesScrollView.addSubview(imageView)
                self.imagesScrollView.contentSize = CGSize(width: self.imagesScrollView.contentSize.width + imageView.frame.size.width, height: self.imagesScrollView.frame.size.height)
            }
        }.resume()
    }

    // MARK: - Actions

    @IBAction func offerButtonPressed(_ sender: Any) {
        guard let offer = typedOffer else { return }
        if cameFromWallet {
            let redemptionStatus = offer.redemptionStatus ?? 0
            if redemptionStatus == 0 || redemptionStatus == 1 {
                Task {
                    do {
                        let result = try await updateWalletStatus()
                        guard let result = result, result.valid == true else { return }
                        guard let qrcvc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "DDQRCodeViewController") as? DDQRCodeViewController else { return }
                        qrcvc.offer = encodeToDictionary(result) as? [String: Any] ?? [:]
                        navigationController?.pushViewController(qrcvc, animated: true)
                    } catch {
                        print("[DDOfferDetail] Update wallet status failed: \(error)")
                    }
                }
            } else if redemptionStatus == 2 {
                let alert = UIAlertController(title: "This offer has already been redeemed!", message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        } else {
            if offerHasMissions() {
                guard let fullMission = offerFullMission(),
                      let missionId = fullMission["missionId"] as? NSNumber else { return }
                Task {
                    do {
                        let result = try await createMissionInvite(missionId: missionId)
                        guard let result = result else { return }
                        if SNIHelper.check(result, objectForKey: "item"),
                           let mission = offerMissionData(),
                           let gameDataString = mission["gameData"] as? String,
                           let gameDataData = gameDataString.data(using: .utf8),
                           let gameData = try? JSONSerialization.jsonObject(with: gameDataData) as? [String: Any],
                           let type = gameData["type"] as? String {
                            if type == "photo" {
                                guard let pmvc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "DDPictureMissionViewController") as? DDPictureMissionViewController else { return }
                                pmvc.mission = result["item"] as? [String: Any] ?? [:]
                                pmvc.gameData = gameData
                                navigationController?.pushViewController(pmvc, animated: true)
                            } else {
                                let alert = UIAlertController(title: "Sorry", message: "This tutorial only supports photo missions", preferredStyle: .alert)
                                alert.addAction(UIAlertAction(title: "OK", style: .default))
                                present(alert, animated: true)
                            }
                        }
                    } catch {
                        print("[DDOfferDetail] Create mission invite failed: \(error)")
                    }
                }
            } else {
                let remaining = offer.redemptionsRemaining ?? 0
                if remaining > 0 {
                    Task {
                        do {
                            let result = try await addWalletOffer()
                            guard let result = result, SNIHelper.checkIfValid(result) else { return }
                            let alert = UIAlertController(title: "Success", message: "You have added the offer \(offer.offerName) to your wallet", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            present(alert, animated: true)
                        } catch {
                            print("[DDOfferDetail] Add wallet offer failed: \(error)")
                            let alert = UIAlertController(title: "Error", message: "Failed to add offer to wallet. Please try again.", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            present(alert, animated: true)
                        }
                    }
                } else {
                    let alert = UIAlertController(title: nil, message: "There are no more coupons to redeem.", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    present(alert, animated: true)
                }
            }
        }
    }

    @IBAction func favoritePressed(_ sender: Any) {
        guard let offer = typedOffer else { return }
        let offerLocId = offer.offerLocationId
        Task {
            do {
                if favoriteButton.isSelected {
                    try await removeFavoriteOffer(favoritableId: offerLocId)
                    favoriteButton.isSelected = false
                } else {
                    try await addFavoriteOffer(favoritableId: offerLocId)
                    favoriteButton.isSelected = true
                }
            } catch {
                print("[DDOfferDetail] Favorite toggle failed: \(error)")
            }
        }
    }

    // MARK: - Mission helpers

    private var offerDict: [String: Any] {
        encodeToDictionary(typedOffer) as? [String: Any] ?? [:]
    }

    private func offerHasMissions() -> Bool {
        let offer = offerDict
        guard SNIHelper.check(offer as [AnyHashable: Any], objectForKey: "missionListResponse"),
              let mlr = offer["missionListResponse"] as? [String: Any],
              SNIHelper.check(mlr as [AnyHashable: Any], objectForKey: "count"),
              let count = mlr["count"] as? NSNumber else { return false }
        return count.intValue > 0
    }

    private func offerMissionData() -> [String: Any]? {
        let offer = offerDict
        guard SNIHelper.check(offer as [AnyHashable: Any], objectForKey: "missionListResponse"),
              let mlr = offer["missionListResponse"] as? [String: Any],
              SNIHelper.check(mlr as [AnyHashable: Any], objectForKey: "items"),
              let items = mlr["items"] as? [[String: Any]], !items.isEmpty,
              let missionItem = items.first,
              SNIHelper.check(missionItem as [AnyHashable: Any], objectForKey: "games"),
              let games = missionItem["games"] as? [String: Any],
              SNIHelper.check(games as [AnyHashable: Any], objectForKey: "items"),
              let gameItems = games["items"] as? [[String: Any]], !gameItems.isEmpty,
              let gameItem = gameItems.first,
              SNIHelper.check(gameItem as [AnyHashable: Any], objectForKey: "packs"),
              let packs = gameItem["packs"] as? [String: Any],
              SNIHelper.check(packs as [AnyHashable: Any], objectForKey: "items"),
              let packItems = packs["items"] as? [[String: Any]], !packItems.isEmpty,
              let packItem = packItems.first,
              SNIHelper.check(packItem as [AnyHashable: Any], objectForKey: "levels"),
              let levels = packItem["levels"] as? [String: Any],
              SNIHelper.check(levels as [AnyHashable: Any], objectForKey: "items"),
              let levelItems = levels["items"] as? [[String: Any]], !levelItems.isEmpty else { return nil }
        return levelItems.first
    }

    private func offerFullMission() -> [String: Any]? {
        let offer = offerDict
        guard SNIHelper.check(offer as [AnyHashable: Any], objectForKey: "missionListResponse"),
              let mlr = offer["missionListResponse"] as? [String: Any],
              SNIHelper.check(mlr as [AnyHashable: Any], objectForKey: "items"),
              let items = mlr["items"] as? [[String: Any]], !items.isEmpty else { return nil }
        return items.first
    }

    private func encodeToDictionary<T: Encodable>(_ value: T?) -> [AnyHashable: Any]? {
        guard let value = value,
              let data = try? JSONEncoder().encode(value),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [AnyHashable: Any] else { return nil }
        return dict
    }
}
