//
//  DDQRCodeViewController.swift
//  DoneDid
//

import UIKit
import SNIWrapperKit
import SirqulSDK

class DDQRCodeViewController: UIViewController {

    @IBOutlet var qrCodeImageView: UIImageView!
    @IBOutlet var scanButton: UIButton!

    var offer: [String: Any] = [:]

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        scanButton.setTitle("Merchant can't scan?", for: .normal)
        if SNIHelper.check(offer as [AnyHashable: Any], objectForKey: "qrCodeUrl"),
           let urlStr = offer["qrCodeUrl"] as? String,
           let url = URL(string: urlStr) {
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self = self, let data = data else { return }
                DispatchQueue.main.async {
                    self.qrCodeImageView.image = UIImage(data: data)
                }
            }.resume()
        }
    }

    @IBAction func scanPressed(_ sender: Any) {
        guard let sbvc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "DDScanBarcodeViewController") as? DDScanBarcodeViewController else { return }
        sbvc.scanType = .offerRedeem
        sbvc.offer = offer as NSDictionary
        navigationController?.pushViewController(sbvc, animated: true)
    }
}
