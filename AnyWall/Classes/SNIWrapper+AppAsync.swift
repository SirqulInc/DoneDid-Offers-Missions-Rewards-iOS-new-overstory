//
//  SNIWrapper+AppAsync.swift
//  DoneDid
//

import Foundation
import CoreLocation
import SNIWrapperKit
import SirqulSDK
import SirqulBase

extension SNIWrapper {

    // Used by DDScanBarcodeViewController
    func updateVoucherStatus(accountId: NSNumber?, transactionId: Int, status: Int) async throws {
        let sni = newInterface()
        let _: [AnyHashable: Any]? = try await withCheckedThrowingContinuation { continuation in
            sni.completionBlock = { result in continuation.resume(returning: result) }
            sni.failureBlock = { error in continuation.resume(throwing: SDKError.custom(error)) }
            sni.updateVoucherStatus(withAccountId: accountId, andOfferTransactionId: NSNumber(value: transactionId), andStatus: NSNumber(value: status))
        }
    }

    // Used by DDPictureMissionViewController
    func addAlbumWithMedia(accountId: NSNumber?, title: String, media: Data, description: String?, visibility: Visibility) async throws -> [AnyHashable: Any]? {
        let sni = newInterface()
        return try await withCheckedThrowingContinuation { continuation in
            sni.completionBlock = { result in continuation.resume(returning: result) }
            sni.failureBlock = { error in continuation.resume(throwing: SDKError.custom(error)) }
            sni.addAlbum(withAccountId: accountId, andTitle: title, andMedia: media, andAttachedMedia: nil, andAttachedMediaIsVideo: nil, andAttachedMediaURL: nil, andCoverAssetNullable: nil, andStartDate: 0, andEndDate: 0, andTags: nil, andDescription: nil, andPublicRead: NSNumber(value: true), andpublicWrite: NSNumber(value: false), andPublicDelete: NSNumber(value: false), andPublicAdd: NSNumber(value: false), andLocation: nil, andLocationDescription: description, andAlbumType: nil, andVisibility: visibility, andIncludeCoverInAssetList: NSNumber(value: true), andAnonymous: nil)
        }
    }

    // Used by DDPictureMissionViewController
    func updateAssetCaption(accountId: NSNumber?, assetId: Int, albumId: Int, caption: String?) async throws {
        let sni = newInterface()
        let _: [AnyHashable: Any]? = try await withCheckedThrowingContinuation { continuation in
            sni.completionBlock = { result in continuation.resume(returning: result) }
            sni.failureBlock = { error in continuation.resume(throwing: SDKError.custom(error)) }
            sni.updateAsset(withAccountId: accountId, andAssetId: NSNumber(value: assetId), andAlbumId: NSNumber(value: albumId), andAttachedAssetId: nil, andVersionCode: nil, andVersionName: nil, andMetaData: nil, andCaption: caption, andLocationDescription: nil, andLocation: nil, andSearchTags: nil, andAppKey: nil, andMedia: nil, andMediaUrl: nil, andMediaString: nil, andMediaFileName: nil, andMediaContentType: nil, andMediaHeight: nil, andMediaWidth: nil, andAttachedMedia: nil, andAttachedMediaUrl: nil, andAttachedMediaString: nil, andAttachedFileName: nil, andAttachedContentType: nil, andAttachedMediaHeight: nil, andAttachedMediaWidth: nil)
        }
    }

    // Used by DDPictureMissionViewController
    func createNoteForAsset(accountId: NSNumber?, assetId: Int, albumId: Int) async throws {
        let sni = newInterface()
        let _: [AnyHashable: Any]? = try await withCheckedThrowingContinuation { continuation in
            sni.completionBlock = { result in continuation.resume(returning: result) }
            sni.failureBlock = { error in continuation.resume(throwing: SDKError.custom(error)) }
            sni.createNote(withAccountId: accountId, andNotableType: kNotableTypeASSET, andNotableId: NSNumber(value: assetId), andComment: nil, andAssetIds: nil, andTags: nil, andPermissionableType: kPermissionableTypeALBUM, andPermissionableId: NSNumber(value: albumId), andAppKey: DDConstants.sirqulAppKey, andLocationDescription: nil, andLocation: nil)
        }
    }

    // Used by DDPictureMissionViewController
    func updateMissionInvite(accountId: NSNumber?, missionId: Int, albumId: Int) async throws -> [AnyHashable: Any]? {
        let sni = newInterface()
        return try await withCheckedThrowingContinuation { continuation in
            sni.completionBlock = { result in continuation.resume(returning: result) }
            sni.failureBlock = { error in continuation.resume(throwing: SDKError.custom(error)) }
            sni.updateMissionInvite(withAccountId: accountId, andMissionId: NSNumber(value: missionId), andMissionInviteId: nil, andMissionInviteStatus: kMissionInviteStatusPENDING_REVIEW, andPermissionableType: kPermissionableTypeALBUM, andPermissionableId: NSNumber(value: albumId), andIncludeGameData: nil)
        }
    }

    // Used by DDOfferDetailViewController
    func createMissionInvite(accountId: NSNumber?, missionId: NSNumber) async throws -> [AnyHashable: Any]? {
        let sni = newInterface()
        return try await withCheckedThrowingContinuation { continuation in
            sni.completionBlock = { result in continuation.resume(returning: result) }
            sni.failureBlock = { error in continuation.resume(throwing: SDKError.custom(error)) }
            sni.createMissionInvite(withAccountId: accountId, andMissionId: missionId, andPermissionableType: kPermissionableTypeNULL, andPermissionableId: nil, andIncludeGameData: nil)
        }
    }

    // Used by DDOfferDetailViewController
    func addWalletOffer(accountId: NSNumber?, offerLocationId: Int) async throws -> [AnyHashable: Any]? {
        let sni = newInterface()
        return try await withCheckedThrowingContinuation { continuation in
			sni.completionBlock = { result in continuation.resume(returning: result) }
            sni.failureBlock = { error in continuation.resume(throwing: SDKError.custom(error)) }
			sni.addWallet(withAccountId: accountId, andOfferId: nil, andOfferLocationId: NSNumber(value: offerLocationId), andUsePoints: nil, andOfferCart: nil)
        }
    }

}
