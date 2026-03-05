//
//  DDPictureMissionViewController.swift
//  DoneDid
//

import UIKit
import AVFoundation
import Photos
import SNIWrapperKit
import SirqulSDK

class DDPictureMissionViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextFieldDelegate, UITextViewDelegate {

    @IBOutlet var pictureButton: UIButton!
    @IBOutlet var titleTextField: UITextField!
    @IBOutlet var commentTextField: UITextField!
    @IBOutlet var commentTextView: UITextView!
    @IBOutlet var pictureImageView: UIImageView!
    @IBOutlet var commentBackgroundButton: UIButton!
    @IBOutlet var titleBackgroundButton: UIButton!
    @IBOutlet var commentLabel: UILabel!
    @IBOutlet var requirementsTextView: UITextView!
    @IBOutlet var choosePhotoLabel: UILabel!

    private var takingPicture: Bool = false
    private var missionPic: UIImage?
    var mission: [String: Any] = [:]
    var gameData: [String: Any] = [:]
    private var albumId: Int = 0
    private var assetId: Int = 0
    private var missionId: Int = 0

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        missionId = (mission["missionId"] as? NSNumber)?.intValue ?? 0
        choosePhotoLabel.text = "Tap to choose photo"
        titleTextField.placeholder = "Title"
        commentLabel.text = "Comment"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Submit", style: .plain, target: self, action: #selector(submitPressed))
        title = "Submit Photo"
    }

    @IBAction func pictureButtonPressed(_ sender: Any) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Take a photo", style: .default) { [weak self] _ in
            guard let self = self else { return }
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                self.checkCameraPermissionAndPresent()
            } else {
                let errorAlert = UIAlertController(title: "Message", message: "This device cannot take photos.  Please add an existing photo from your library.", preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(errorAlert, animated: true)
            }
        })
        alert.addAction(UIAlertAction(title: "Choose from saved photos", style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.checkPhotoLibraryPermissionAndPresent()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func checkCameraPermissionAndPresent() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentCameraPicker()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.presentCameraPicker()
                    } else {
                        self?.showPermissionDeniedAlert(for: "Camera")
                    }
                }
            }
        case .denied, .restricted:
            showPermissionDeniedAlert(for: "Camera")
        @unknown default:
            showPermissionDeniedAlert(for: "Camera")
        }
    }

    private func checkPhotoLibraryPermissionAndPresent() {
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized, .limited:
            presentPhotoLibraryPicker()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { [weak self] newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized || newStatus == .limited {
                        self?.presentPhotoLibraryPicker()
                    } else {
                        self?.showPermissionDeniedAlert(for: "Photo Library")
                    }
                }
            }
        case .denied, .restricted:
            showPermissionDeniedAlert(for: "Photo Library")
        @unknown default:
            showPermissionDeniedAlert(for: "Photo Library")
        }
    }

    private func showPermissionDeniedAlert(for permission: String) {
        let alert = UIAlertController(title: "\(permission) Access Required", message: "Please enable \(permission) access in Settings.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        present(alert, animated: true)
    }

    private func presentCameraPicker() {
        takingPicture = true
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        picker.allowsEditing = true
        present(picker, animated: true)
    }

    private func presentPhotoLibraryPicker() {
        takingPicture = false
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        navigationController?.present(picker, animated: true)
    }

    // MARK: - UIImagePickerControllerDelegate

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        if let image = info[.editedImage] as? UIImage {
            pictureImageView.image = image
            missionPic = image
            if takingPicture {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            }
        }
        dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }

    // MARK: - UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        commentLabel.isHidden = !textView.text.isEmpty
    }

    // MARK: - Submit

    @objc private func submitPressed() {
        guard let pic = missionPic, !commentTextView.text.isEmpty, !(titleTextField.text?.isEmpty ?? true) else {
            let alert = UIAlertController(title: "Please fill in all fields and upload an image", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        if SNIHelper.check(gameData as [AnyHashable: Any], objectForKey: "albumId") {
            albumId = (gameData["albumId"] as? NSNumber)?.intValue ?? 0
        }

        var albumName: String
        if let t = mission["title"] as? String {
            albumName = "Submission for \"\(t)\""
        } else if let mid = mission["missionId"] as? NSNumber {
            albumName = "Mission #\(mid) submission"
        } else {
            albumName = "Mission submission"
        }

        let desc = mission["locationName"] as? String

        Task {
            do {
                // Step 1: Add album
                let albumResult = try await addAlbum(title: albumName, media: pic.pngData()!, desc: desc)
                guard let albumResult = albumResult, (albumResult["valid"] as? NSNumber)?.intValue == 1 else { return }
                albumId = (albumResult["albumId"] as? NSNumber)?.intValue ?? 0
                if let coverAsset = albumResult["coverAsset"] as? [String: Any],
                   SNIHelper.check(coverAsset as [AnyHashable: Any], objectForKey: "assetId") {
                    assetId = (coverAsset["assetId"] as? NSNumber)?.intValue ?? 0
                }

                // Step 2: Update media
                try await updateMedia(assetId: assetId, albumId: albumId, caption: titleTextField.text)

                // Step 3: Create note
                try await createNoteForAsset(assetId: assetId, albumId: albumId)

                // Step 4: Update mission invite
                let _ = try await updateMissionInvite(missionId: missionId, albumId: albumId)

                // Show success alert
                let alert = UIAlertController(title: "Pending Review", message: "Thank you for your submission!  Your photo, title, and description are currently under review.  Upon approval, you will receive a notification and your reward will be added to your wallet.", preferredStyle: .alert)
                alert.tag = 1
                alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                    self?.navigationController?.popToRootViewController(animated: true)
                })
                present(alert, animated: true)
            } catch {
                // handle error
            }
        }
    }

    // MARK: - Async network helpers

    private func addAlbum(title: String, media: Data, desc: String?) async throws -> [AnyHashable: Any]? {
        return try await SNIWrapper.shared.addAlbumWithMedia(accountId: UserDefaults.standard.object(forKey: "accountId") as? NSNumber, title: title, media: media, description: desc, visibility: kVisibilityPRIVATE)
    }

    private func updateMedia(assetId: Int, albumId: Int, caption: String?) async throws {
        try await SNIWrapper.shared.updateAssetCaption(accountId: UserDefaults.standard.object(forKey: "accountId") as? NSNumber, assetId: assetId, albumId: albumId, caption: caption)
    }

    private func createNoteForAsset(assetId: Int, albumId: Int) async throws {
        try await SNIWrapper.shared.createNoteForAsset(accountId: UserDefaults.standard.object(forKey: "accountId") as? NSNumber, assetId: assetId, albumId: albumId)
    }

    private func updateMissionInvite(missionId: Int, albumId: Int) async throws -> [AnyHashable: Any]? {
        return try await SNIWrapper.shared.updateMissionInvite(accountId: UserDefaults.standard.object(forKey: "accountId") as? NSNumber, missionId: missionId, albumId: albumId)
    }
}

extension UIAlertController {
    var tag: Int {
        get { return objc_getAssociatedObject(self, &UIAlertController.tagKey) as? Int ?? 0 }
        set { objc_setAssociatedObject(self, &UIAlertController.tagKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    private static var tagKey = "UIAlertControllerTag"
}
