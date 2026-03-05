//
//  DDCircleView.swift
//  DoneDid
//
//  Based upon ReminderCircleView from Apple's WWDC 2010 sample code.
//  Uses MKOverlayPathRenderer (modern replacement for deprecated MKOverlayPathView).
//

import MapKit

class DDCircleView: MKOverlayPathRenderer {

    private(set) var searchRadius: DDSearchRadius

    init(searchRadius aSearchRadius: DDSearchRadius) {
        self.searchRadius = aSearchRadius
        super.init(overlay: aSearchRadius)
        aSearchRadius.addObserver(self, forKeyPath: "coordinate", options: [], context: nil)
        aSearchRadius.addObserver(self, forKeyPath: "radius", options: [], context: nil)
    }

    deinit {
        searchRadius.removeObserver(self, forKeyPath: "coordinate")
        searchRadius.removeObserver(self, forKeyPath: "radius")
    }

    override func createPath() {
        let path = CGMutablePath()
        let center = searchRadius.coordinate
		let centerPoint = point(for: MKMapPoint(center))
        let radius = CGFloat(MKMapPointsPerMeterAtLatitude(center.latitude) * searchRadius.radius)
        path.addArc(center: centerPoint, radius: radius, startAngle: 2.0 * .pi, endAngle: 0, clockwise: true)
        self.path = path
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        invalidatePath()
    }
}
