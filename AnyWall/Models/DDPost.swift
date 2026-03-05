//
//  DDPost.swift
//  DoneDid
//

import Foundation
import MapKit
import SNIWrapperKit
import SirqulSDK
import SirqulBase

class DDPost: NSObject, MKAnnotation {

    // MARK: - MKAnnotation
    var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?

    // MARK: - Properties
    var animatesDrop: Bool = false
    var pinColor: UIColor = .red
    var objectId: Int = 0
    var tag: Int = 0
    var offer: Bool = false

    // MARK: - Initializers

    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.animatesDrop = false
        super.init()
    }

    convenience init(album: AlbumFullResponse) {
        let coord = CLLocationCoordinate2DMake(album.latitude ?? 0, album.longitude ?? 0)
        self.init(coordinate: coord, title: album.title, subtitle: album.owner?.display)
        self.objectId = album.albumId
    }

    convenience init(offerResponse: OfferResponse) {
        let coord = CLLocationCoordinate2DMake(offerResponse.latitude ?? 0, offerResponse.longitude ?? 0)
        self.init(coordinate: coord, title: offerResponse.offerName, subtitle: offerResponse.locationName)
        self.objectId = offerResponse.offerId
    }

    // MARK: - Methods

    func equalToPost(_ aPost: DDPost) -> Bool {
        if aPost.title != self.title { return false }
        if aPost.subtitle != self.subtitle { return false }
        if aPost.coordinate.latitude != self.coordinate.latitude { return false }
        if aPost.coordinate.longitude != self.coordinate.longitude { return false }
        return true
    }

    func setTitleAndSubtitleOutsideDistance(_ outside: Bool) {
        if outside {
            self.subtitle = nil
            self.title = DDConstants.wallCantViewPost
            self.pinColor = .red
        } else {
            self.pinColor = .green
        }
    }
}
