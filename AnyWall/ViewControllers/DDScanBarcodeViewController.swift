//
//  DDScanBarcodeViewController.swift
//  DoneDid
//

import UIKit
import AVFoundation
import SNIWrapperKit
import SirqulSDK

@objc enum ScanType: Int {
    case any
    case offerRedeem
}

@objc protocol ScanBarcodeDelegate: NSObjectProtocol {
    func barcodeScanned(withDetails details: [String: Any])
}

class DDScanBarcodeViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    weak var delegate: ScanBarcodeDelegate?
    var offer: NSDictionary?
    var scanType: ScanType = .any

    private var captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var captured: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        checkCameraPermissionAndSetup()
    }

    private func checkCameraPermissionAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCaptureSession()
                    } else {
                        self?.showCameraDeniedAlert()
                    }
                }
            }
        case .denied, .restricted:
            showCameraDeniedAlert()
        @unknown default:
            showCameraDeniedAlert()
        }
    }

    private func setupCaptureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        captureSession.addInput(input)
        let metadataOutput = AVCaptureMetadataOutput()
        captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: .main)
        metadataOutput.metadataObjectTypes = [.qr, .ean8, .ean13, .pdf417, .code128, .code39, .code93, .upce, .aztec, .dataMatrix]
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    private func showCameraDeniedAlert() {
        let alert = UIAlertController(title: "Camera Access Required", message: "Please enable camera access in Settings to scan barcodes.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        present(alert, animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if captured {
            captured = false
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession.stopRunning()
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !captured,
              let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let text = metadataObject.stringValue else { return }
        captured = true
        captureSession.stopRunning()

        if scanType == .offerRedeem {
            guard let data = text.data(using: .utf8),
                  let resultDict = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
                captured = false
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    self?.captureSession.startRunning()
                }
                return
            }

            let qrRetailerLocationId = (resultDict["locationId"] as? NSNumber)?.intValue ?? 0
            var valid = false

            if let offerDict = offer,
               SNIHelper.check(offerDict as? [AnyHashable: Any], objectForKey: "location"),
               let location = offerDict["location"] as? [String: Any],
               SNIHelper.check(location as [AnyHashable: Any], objectForKey: "retailerLocationId") {
                let offerRLId = (location["retailerLocationId"] as? NSNumber)?.intValue ?? 0
                if offerRLId == qrRetailerLocationId && qrRetailerLocationId != 0 {
                    valid = true
                    let alert = UIAlertController(title: "Confirmation", message: "Redeem now?", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
                        self?.captured = false
                        DispatchQueue.global(qos: .userInitiated).async {
                            self?.captureSession.startRunning()
                        }
                    })
                    alert.addAction(UIAlertAction(title: "Redeem", style: .default) { [weak self] _ in
                        self?.redeemOffer()
                    })
                    present(alert, animated: true)
                }
            }

            if !valid {
                let alert = UIAlertController(title: "Sorry", message: "Offers do not match", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                    self?.captured = false
                    DispatchQueue.global(qos: .userInitiated).async {
                        self?.captureSession.startRunning()
                    }
                })
                present(alert, animated: true)
            }
        }
    }

    private func redeemOffer() {
        Task { await performRedeem() }
    }

    // MARK: - Async network helpers

    private func redeemVoucherRequest(transactionId: Int) async throws {
        try await SNIWrapper.shared.updateVoucherStatus(accountId: SNIWrapper.shared.accountId, transactionId: transactionId, status: 2)
    }

    private func performRedeem() async {
        guard let transactionId = (offer?["transactionId"] as? NSNumber)?.intValue else { return }
        do {
            try await redeemVoucherRequest(transactionId: transactionId)
            let alert = UIAlertController(title: "Success", message: "Offer redeemed.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            navigationController?.popViewController(animated: true)
        } catch {
            // no-op
            let alert = UIAlertController(title: "", message: "Coming soon.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}
