//
//  DDSearchRadius.swift
//  DoneDid
//

import MapKit

class DDSearchRadius: NSObject, MKOverlay {

    var coordinate: CLLocationCoordinate2D
    var radius: CLLocationDistance
    var boundingMapRect: MKMapRect {
		return MKMapRect.world
    }

    init(coordinate: CLLocationCoordinate2D, radius: CLLocationDistance) {
        self.coordinate = coordinate
        self.radius = radius
        super.init()
    }
}
