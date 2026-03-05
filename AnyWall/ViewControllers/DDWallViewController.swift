//
//  DDWallViewController.swift
//  DoneDid
//

import UIKit
import MapKit
import CoreLocation
import SNIWrapperKit
import SirqulSDK
import SirqulBase

extension SNIWrapper {
    static let shared = SNIWrapper()
}

class DDWallViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, UITableViewDataSource, UITableViewDelegate {
	let kPAWWallPostTableViewFontSize: CGFloat = 12.0
	let kPAWWallPostTableViewCellWidth: CGFloat = 230.0
	let kPAWCellPaddingTop: CGFloat = 5.0
	let kPAWCellPaddingBottom: CGFloat = 1.0
	let kPAWCellPaddingSides: CGFloat = 0.0
	let kPAWCellTextPaddingTop: CGFloat = 6.0
	let kPAWCellTextPaddingBottom: CGFloat = 5.0
	let kPAWCellTextPaddingSides: CGFloat = 5.0
	let kPAWCellUsernameHeight: CGFloat = 15.0
	let kPAWCellBkgdHeight: CGFloat = 32.0
	var kPAWCellBkgdOffset: CGFloat = 0.0
	let kPAWCellBackgroundTag: Int = 2
	let kPAWCellTextLabelTag: Int = 3
	let kPAWCellNameLabelTag: Int = 4

    @IBOutlet var mapView: MKMapView!
    @IBOutlet weak var wallTableView: UITableView!
    @IBOutlet weak var postSegmentedControl: UISegmentedControl!

    private var locationManager: CLLocationManager?
    private var searchRadius: DDSearchRadius?
    private var circleView: DDCircleView?
    private var annotations: [DDPost] = []
    private var mapPinsPlaced: Bool = false
    private var mapPannedSinceLocationUpdate: Bool = false {
        didSet { snapToLocationButton.isHidden = !mapPannedSinceLocationUpdate }
    }
    private var userInitiatedRegionChange: Bool = false
    private var selectedPost: DDPost?

    private lazy var snapToLocationButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: "location.fill", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        button.layer.cornerRadius = 22
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.3
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        button.addTarget(self, action: #selector(snapToCurrentLocation), for: .touchUpInside)
        return button
    }()
    private var allPosts: [DDPost] = []
    private var regionChangeWorkItem: DispatchWorkItem?

    private var lastNearbyDistance: CLLocationAccuracy = 0
    private var wallPosts: [AlbumFullResponse] = []
    private var allWallposts: [AlbumFullResponse] = []
    private var offers: [OfferResponse]?
    private var refreshControl: UIRefreshControl!

    private var queryCenter: CLLocation? {
        if mapPannedSinceLocationUpdate {
            return CLLocation(latitude: mapView.centerCoordinate.latitude,
                              longitude: mapView.centerCoordinate.longitude)
        }
        return (UIApplication.shared.delegate as? DDAppDelegate)?.currentLocation
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.title = "DoneDid"
    }

    // MARK: - View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
		kPAWCellBkgdOffset = kPAWCellBkgdHeight - kPAWCellUsernameHeight
        wallTableView.backgroundColor = .clear
        wallTableView.separatorStyle = .none
        wallTableView.delegate = self
        wallTableView.dataSource = self

        refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshTable), for: .valueChanged)
        wallTableView.addSubview(refreshControl)

        navigationController?.setNavigationBarHidden(false, animated: false)
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Post", style: .plain, target: self, action: #selector(postButtonSelected(_:))),
            UIBarButtonItem(title: "Favorites", style: .plain, target: self, action: #selector(favoritesPressed))
        ]
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(title: "Settings", style: .plain, target: self, action: #selector(settingsButtonSelected(_:))),
            UIBarButtonItem(title: "Wallet", style: .plain, target: self, action: #selector(walletPressed))
        ]
        navigationItem.titleView = UIImageView(image: UIImage(named: "logo"))

        NotificationCenter.default.addObserver(self, selector: #selector(distanceFilterDidChange(_:)), name: NSNotification.Name(DDConstants.filterDistanceChangeNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(locationDidChange(_:)), name: NSNotification.Name(DDConstants.locationChangeNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(postWasCreated(_:)), name: NSNotification.Name(DDConstants.postCreatedNotification), object: nil)

        mapView.region = MKCoordinateRegion(center: CLLocationCoordinate2DMake(37.332495, -122.029095), span: MKCoordinateSpan(latitudeDelta: 0.008516, longitudeDelta: 0.021801))
        mapPannedSinceLocationUpdate = false

        view.addSubview(snapToLocationButton)
        NSLayoutConstraint.activate([
            snapToLocationButton.widthAnchor.constraint(equalToConstant: 44),
            snapToLocationButton.heightAnchor.constraint(equalToConstant: 44),
            snapToLocationButton.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -16),
            snapToLocationButton.bottomAnchor.constraint(equalTo: mapView.bottomAnchor, constant: -16)
        ])

        postSegmentedControl.selectedSegmentTintColor = UIColor(red: 200/255, green: 83/255, blue: 70/255, alpha: 1)
        postSegmentedControl.backgroundColor = UIColor(white: 0.9, alpha: 1)
        postSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.darkGray], for: .normal)
        postSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        startStandardUpdates()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if locationManager?.authorizationStatus != .notDetermined {
            locationManager?.stopUpdatingLocation()
        }
    }

    deinit {
        locationManager?.stopUpdatingLocation()
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(DDConstants.filterDistanceChangeNotification), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(DDConstants.locationChangeNotification), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(DDConstants.postCreatedNotification), object: nil)
        mapPinsPlaced = false
    }

    // MARK: - Load offers

    private func loadOffers() {
        guard let appDelegate = UIApplication.shared.delegate as? DDAppDelegate,
              let center = queryCenter else { return }
        Task {
            do {
                let response = try await SNIWrapper.shared.getOffersList(with: center, searchRange: Int(appDelegate.filterDistance), keyword: nil, specialOfferTypes: [kSpecialOfferTypeNULL], offerTypes: [], start: 0, limit: 50)
                guard let response = response, response.valid == true else { return }
                offers = response.items ?? []
                placeOfferPins()
                wallTableView.reloadData()
            } catch { }
            refreshControl.endRefreshing()
        }
    }

    // MARK: - Notifications

    @objc private func distanceFilterDidChange(_ note: Notification) {
        let filterDistance = ((note.userInfo?[DDConstants.filterDistanceKey]) as? NSNumber)?.doubleValue ?? 0
        guard let appDelegate = UIApplication.shared.delegate as? DDAppDelegate else { return }
        guard let currentLocation = appDelegate.currentLocation else { return }

        if searchRadius == nil {
            let sr = DDSearchRadius(coordinate: currentLocation.coordinate, radius: appDelegate.filterDistance)
            searchRadius = sr
            mapView.addOverlay(sr)
        } else {
            searchRadius?.radius = appDelegate.filterDistance
        }
        updatePostsForLocation(queryCenter, withNearbyDistance: filterDistance)

        if !mapPannedSinceLocationUpdate {
            let newRegion = MKCoordinateRegion(center: currentLocation.coordinate, latitudinalMeters: appDelegate.filterDistance * 2, longitudinalMeters: appDelegate.filterDistance * 2)
            mapView.setRegion(newRegion, animated: true)
            mapPannedSinceLocationUpdate = false
        } else {
            let currentRegion = mapView.region
            let newRegion = MKCoordinateRegion(center: currentRegion.center, latitudinalMeters: appDelegate.filterDistance * 2, longitudinalMeters: appDelegate.filterDistance * 2)
            mapView.setRegion(newRegion, animated: true)
        }
    }

    @objc private func locationDidChange(_ note: Notification) {
        guard let appDelegate = UIApplication.shared.delegate as? DDAppDelegate else { return }
        guard let currentLocation = appDelegate.currentLocation else { return }
        if !mapPannedSinceLocationUpdate {
            let newRegion = MKCoordinateRegion(center: currentLocation.coordinate, latitudinalMeters: appDelegate.filterDistance * 2, longitudinalMeters: appDelegate.filterDistance * 2)
            mapView.setRegion(newRegion, animated: true)
        }
        if searchRadius == nil {
            let sr = DDSearchRadius(coordinate: currentLocation.coordinate, radius: appDelegate.filterDistance)
            searchRadius = sr
            mapView.addOverlay(sr)
        } else {
            searchRadius?.coordinate = currentLocation.coordinate
        }
        queryForAllPosts(nearLocation: currentLocation, withNearbyDistance: appDelegate.filterDistance)
        updatePostsForLocation(appDelegate.currentLocation, withNearbyDistance: appDelegate.filterDistance)
    }

    @objc private func postWasCreated(_ note: Notification) {
        guard let appDelegate = UIApplication.shared.delegate as? DDAppDelegate else { return }
        guard let currentLocation = appDelegate.currentLocation else { return }
        queryForAllPosts(nearLocation: currentLocation, withNearbyDistance: appDelegate.filterDistance)
    }

    // MARK: - Navigation actions

    @objc private func favoritesPressed() {
        guard let fovc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "DDFavoriteOffersViewController") as? DDFavoriteOffersViewController else { return }
        navigationController?.pushViewController(fovc, animated: true)
    }

    @objc private func walletPressed() {
        guard let wvc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "DDWalletViewController") as? DDWalletViewController else { return }
        navigationController?.pushViewController(wvc, animated: true)
    }

    @IBAction private func settingsButtonSelected(_ sender: Any) {
        guard let settingsVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "DDSettingsViewController") as? DDSettingsViewController else { return }
        navigationController?.pushViewController(settingsVC, animated: true)
    }

    @IBAction private func postButtonSelected(_ sender: Any) {
        guard let createVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "DDWallPostCreateViewController") as? DDWallPostCreateViewController else { return }
        navigationController?.pushViewController(createVC, animated: true)
    }

    // MARK: - CLLocationManager

    private func startStandardUpdates() {
        if locationManager == nil {
            locationManager = CLLocationManager()
        }
        locationManager?.delegate = self
        locationManager?.desiredAccuracy = kCLLocationAccuracyBest
        locationManager?.distanceFilter = kCLLocationAccuracyNearestTenMeters
        locationManager?.requestWhenInUseAuthorization()
        locationManager?.startUpdatingLocation()

        if let currentLocation = locationManager?.location,
           let appDelegate = UIApplication.shared.delegate as? DDAppDelegate {
            appDelegate.currentLocation = currentLocation
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorized, .authorizedWhenInUse:
            navigationItem.rightBarButtonItem?.isEnabled = true
            locationManager?.startUpdatingLocation()
        case .denied:
            let alert = UIAlertController(title: "Anywall can't access your current location.\n\nTo view nearby posts or create a post at your current location, turn on access for Anywall to your location in the Settings app under Location Services.", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default))
            present(alert, animated: true)
            navigationItem.rightBarButtonItem?.isEnabled = false
        default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }
        guard let appDelegate = UIApplication.shared.delegate as? DDAppDelegate else { return }
        appDelegate.currentLocation = newLocation

        if !mapPannedSinceLocationUpdate {
            let newRegion = MKCoordinateRegion(
                center: newLocation.coordinate,
                latitudinalMeters: appDelegate.filterDistance * 2,
                longitudinalMeters: appDelegate.filterDistance * 2
            )
            mapView.setRegion(newRegion, animated: true)
        }

        if searchRadius == nil {
            let sr = DDSearchRadius(coordinate: newLocation.coordinate, radius: appDelegate.filterDistance)
            searchRadius = sr
            mapView.addOverlay(sr)
        } else {
            searchRadius?.coordinate = newLocation.coordinate
        }

        queryForAllPosts(nearLocation: newLocation, withNearbyDistance: appDelegate.filterDistance)
        updatePostsForLocation(newLocation, withNearbyDistance: appDelegate.filterDistance)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let nsError = error as NSError
        if nsError.code == CLError.denied.rawValue {
            locationManager?.stopUpdatingLocation()
        } else if nsError.code != CLError.locationUnknown.rawValue {
            let alert = UIAlertController(title: "Error retrieving location", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .default))
            present(alert, animated: true)
        }
    }

    // MARK: - MKMapViewDelegate

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let sr = overlay as? DDSearchRadius {
            let renderer = DDCircleView(searchRadius: sr)
            renderer.fillColor = UIColor.darkGray.withAlphaComponent(0.2)
            renderer.strokeColor = UIColor.darkGray.withAlphaComponent(0.7)
            renderer.lineWidth = 2.0
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation { return nil }
        let pinIdentifier = "CustomPinAnnotation"
        if let post = annotation as? DDPost {
            var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: pinIdentifier) as? MKPinAnnotationView
            if pinView == nil {
                pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: pinIdentifier)
            } else {
                pinView?.annotation = annotation
            }
            pinView?.pinTintColor = post.offer ? .purple : post.pinColor
            pinView?.animatesDrop = post.animatesDrop
            pinView?.canShowCallout = true
            pinView?.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            let segment = postSegmentedControl.selectedSegmentIndex
            pinView?.isHidden = (segment == 0 && !post.offer) || (segment == 1 && post.offer)
            return pinView
        }
        return nil
    }

    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        guard let post = view.annotation as? DDPost else { return }
        if post.offer {
            guard let offers = offers,
                  post.tag >= 0 && post.tag < offers.count else { return }
            let offer = offers[post.tag]
            guard let odvc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "DDOfferDetailViewController") as? DDOfferDetailViewController else { return }
            odvc.configure(offer: offer, isFromWallet: false)
            navigationController?.pushViewController(odvc, animated: true)
        } else {
            mapView.selectAnnotation(post, animated: true)
        }
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        if let post = view.annotation as? DDPost {
            selectedPost = post
            // Center map on selected pin (programmatic — won't trigger refresh)
            let currentSpan = mapView.region.span
            let centeredRegion = MKCoordinateRegion(center: post.coordinate, span: currentSpan)
            mapView.setRegion(centeredRegion, animated: true)

            if post.offer {
                postSegmentedControl.selectedSegmentIndex = 0
                wallTableView.reloadData()
                syncMapPinsWithSelectedSegment()
                let rowCount = wallTableView.numberOfRows(inSection: 0)
                if post.tag >= 0 && post.tag < rowCount {
                    wallTableView.selectRow(at: IndexPath(row: post.tag, section: 0), animated: true, scrollPosition: .middle)
                }
            } else {
                postSegmentedControl.selectedSegmentIndex = 1
                wallTableView.reloadData()
                syncMapPinsWithSelectedSegment()
                if let album = album(for: post), let idx = wallPosts.firstIndex(where: { $0.albumId == album.albumId }) {
                    let rowCount = wallTableView.numberOfRows(inSection: 0)
                    if idx < rowCount {
                        wallTableView.selectRow(at: IndexPath(row: idx, section: 0), animated: true, scrollPosition: .middle)
                    }
                }
            }
        } else if view.annotation is MKUserLocation {
            guard let appDelegate = UIApplication.shared.delegate as? DDAppDelegate else { return }
            if let location = appDelegate.currentLocation {
                let newRegion = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: appDelegate.filterDistance * 2, longitudinalMeters: appDelegate.filterDistance * 2)
                self.mapView.setRegion(newRegion, animated: true)
                mapPannedSinceLocationUpdate = false
            }
        }
    }

    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        if let post = view.annotation as? DDPost {
            if selectedPost?.objectId == post.objectId && selectedPost?.offer == post.offer {
                selectedPost = nil
            }
            if let album = album(for: post), let idx = wallPosts.firstIndex(where: { $0.albumId == album.albumId }) {
                let rowCount = wallTableView.numberOfRows(inSection: 0)
                if idx < rowCount {
                    wallTableView.deselectRow(at: IndexPath(row: idx, section: 0), animated: true)
                }
            }
        }
    }

    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        // Only mark as panned for user-initiated gestures, not programmatic setRegion calls
        guard let gestureRecognizers = mapView.subviews.first?.gestureRecognizers else { return }
        for gesture in gestureRecognizers {
            if gesture.state == .began || gesture.state == .ended || gesture.state == .changed {
                mapPannedSinceLocationUpdate = true
                userInitiatedRegionChange = true
                return
            }
        }
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        guard userInitiatedRegionChange else { return }
        userInitiatedRegionChange = false
        regionChangeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self,
                  let appDelegate = UIApplication.shared.delegate as? DDAppDelegate else { return }
            let center = CLLocation(latitude: self.mapView.centerCoordinate.latitude,
                                    longitude: self.mapView.centerCoordinate.longitude)
            self.queryForAllPosts(nearLocation: center, withNearbyDistance: appDelegate.filterDistance)
            self.loadOffers()
        }
        regionChangeWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    // MARK: - Query

    private func queryForAllPosts(nearLocation currentLocation: CLLocation, withNearbyDistance nearbyDistance: CLLocationAccuracy) {
        lastNearbyDistance = nearbyDistance
        let accountId = (UserDefaults.standard.object(forKey: "accountId") as? NSNumber)?.intValue
        Task {
            do {
                let response = try await SNIWrapper.shared.searchAlbums(with: accountId, keyword: nil, filters: "PUBLIC", albumType: nil, sortField: kAlbumApiMapNULL, descending: false, start: 0, limit: 100, location: currentLocation, range: Int(nearbyDistance))
                guard let response = response, response.valid == true else { return }
                handleAlbumSearchResult(response.items ?? [])
                if offers == nil { loadOffers() }
            } catch { }
            refreshControl.endRefreshing()
        }
    }

    private func handleAlbumSearchResult(_ albums: [AlbumFullResponse]) {
        allWallposts = albums

        var newPosts: [DDPost] = []
        var allNewPosts: [DDPost] = []

        for album in albums {
            let newPost = DDPost(album: album)
            allNewPosts.append(newPost)
            let found = allPosts.contains { $0.equalToPost(newPost) }
            if !found { newPosts.append(newPost) }
        }

        let postsToRemove = allPosts.filter { current in
            !allNewPosts.contains { current.equalToPost($0) }
        }

        for newPost in newPosts {
            let objectLocation = CLLocation(latitude: newPost.coordinate.latitude, longitude: newPost.coordinate.longitude)
            let dist = queryCenter?.distance(from: objectLocation) ?? 0
            newPost.setTitleAndSubtitleOutsideDistance(dist > lastNearbyDistance)
            newPost.animatesDrop = mapPinsPlaced
        }

        mapView.removeAnnotations(postsToRemove)
        mapView.addAnnotations(newPosts)
        allPosts.append(contentsOf: newPosts)
        allPosts = allPosts.filter { post in !postsToRemove.contains { $0 === post } }

        mapPinsPlaced = true
        updatePostsForLocation(queryCenter, withNearbyDistance: lastNearbyDistance)
        syncMapPinsWithSelectedSegment()
        reselectPinIfNeeded()
    }

    private func updatePostsForLocation(_ currentLocation: CLLocation?, withNearbyDistance nearbyDistance: CLLocationAccuracy) {
        var nearbyAlbums: [AlbumFullResponse] = []
        for post in allPosts {
            let objectLocation = CLLocation(latitude: post.coordinate.latitude, longitude: post.coordinate.longitude)
            let dist = currentLocation?.distance(from: objectLocation) ?? 0
            if dist > nearbyDistance {
                post.setTitleAndSubtitleOutsideDistance(true)
                (mapView.view(for: post) as? MKPinAnnotationView)?.pinTintColor = post.pinColor
            } else {
                if let album = album(for: post) { nearbyAlbums.append(album) }
                post.setTitleAndSubtitleOutsideDistance(false)
                (mapView.view(for: post) as? MKPinAnnotationView)?.pinTintColor = post.pinColor
            }
        }
        wallPosts = nearbyAlbums
        wallTableView.reloadData()
        reselectPinIfNeeded()
    }

    @objc private func refreshTable() {
        guard let appDelegate = UIApplication.shared.delegate as? DDAppDelegate else { return }
        if let loc = appDelegate.currentLocation {
            queryForAllPosts(nearLocation: loc, withNearbyDistance: lastNearbyDistance)
        }
    }

    private func placeOfferPins() {
        guard let offers = offers else { return }

        // Build set of new offer pins
        var newOfferPosts: [DDPost] = []
        for (idx, offer) in offers.enumerated() {
            if offer.latitude != nil && offer.longitude != nil {
                let post = DDPost(offerResponse: offer)
                post.offer = true
                post.tag = idx
                newOfferPosts.append(post)
            }
        }

        // Get existing offer annotations
        let existingOfferPosts = mapView.annotations.compactMap { $0 as? DDPost }.filter { $0.offer }

        // Find pins to remove (exist on map but not in new data)
        let pinsToRemove = existingOfferPosts.filter { existing in
            !newOfferPosts.contains { $0.objectId == existing.objectId }
        }

        // Find pins to add (in new data but not on map)
        let pinsToAdd = newOfferPosts.filter { newPost in
            !existingOfferPosts.contains { $0.objectId == newPost.objectId }
        }

        // Update tags on existing pins that are staying
        for existing in existingOfferPosts {
            if let newPost = newOfferPosts.first(where: { $0.objectId == existing.objectId }) {
                existing.tag = newPost.tag
            }
        }

        mapView.removeAnnotations(pinsToRemove)
        mapView.addAnnotations(pinsToAdd)
        syncMapPinsWithSelectedSegment()
        reselectPinIfNeeded()
    }

    private func reselectPinIfNeeded() {
        guard let selected = selectedPost else { return }
        // Already selected? Nothing to do.
        if mapView.selectedAnnotations.contains(where: { ($0 as? DDPost)?.objectId == selected.objectId && ($0 as? DDPost)?.offer == selected.offer }) {
            return
        }
        // Find the pin on the map matching the selected post
        if let pinToReselect = mapView.annotations.first(where: {
            guard let post = $0 as? DDPost else { return false }
            return post.objectId == selected.objectId && post.offer == selected.offer
        }) {
            mapView.selectAnnotation(pinToReselect, animated: false)
        }
    }

    private func syncMapPinsWithSelectedSegment() {
        let segment = postSegmentedControl.selectedSegmentIndex
        for annotation in mapView.annotations {
            guard let post = annotation as? DDPost else { continue }
            let shouldHide = (segment == 0 && !post.offer) || (segment == 1 && post.offer)
            mapView.view(for: post)?.isHidden = shouldHide
        }
        // Ensure offer pins exist when switching to offers tab
        if segment == 0 {
            let hasOfferPins = mapView.annotations.contains { ($0 as? DDPost)?.offer == true }
            if !hasOfferPins {
                placeOfferPins()
            }
        }
    }

    private func album(for post: DDPost) -> AlbumFullResponse? {
        return allWallposts.first { $0.albumId == post.objectId }
    }

    private func post(for album: AlbumFullResponse) -> DDPost? {
        return allPosts.first { $0.objectId == album.albumId }
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return postSegmentedControl.selectedSegmentIndex == 0 ? (offers?.count ?? 0) : wallPosts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if postSegmentedControl.selectedSegmentIndex == 1 {
            let album = wallPosts[indexPath.row]
            let albumID = album.albumId
            let cellIsRight = album.ownerId == (UserDefaults.standard.object(forKey: "accountId") as? NSNumber)?.intValue

            let rightId = "RightCell\(albumID)"
            let leftId = "LeftCell\(albumID)"
            let identifier = cellIsRight ? rightId : leftId

            var cell = tableView.dequeueReusableCell(withIdentifier: identifier)
            if cell == nil {
                cell = UITableViewCell(style: .subtitle, reuseIdentifier: identifier)
                let imageName = cellIsRight ? "blueBubble" : "grayBubble"
                let bgImage = UIImageView(image: UIImage(named: imageName)?.resizableImage(withCapInsets: UIEdgeInsets(top: 15, left: 11, bottom: 16, right: 11)))
                bgImage.tag = kPAWCellBackgroundTag
                cell?.contentView.addSubview(bgImage)
                let textLbl = UILabel(); textLbl.tag = kPAWCellTextLabelTag; cell?.contentView.addSubview(textLbl)
                let nameLbl = UILabel(); nameLbl.tag = kPAWCellNameLabelTag; cell?.contentView.addSubview(nameLbl)
            }
            cell?.backgroundColor = .clear
            let text = album.title ?? ""
            let username = "- \(album.owner?.display ?? "")"

            if let textLbl = cell?.contentView.viewWithTag(kPAWCellTextLabelTag) as? UILabel {
                textLbl.text = text; textLbl.lineBreakMode = .byWordWrapping; textLbl.numberOfLines = 0
                textLbl.font = UIFont.systemFont(ofSize: kPAWWallPostTableViewFontSize); textLbl.textColor = .white; textLbl.backgroundColor = .clear
            }
            if let nameLbl = cell?.contentView.viewWithTag(kPAWCellNameLabelTag) as? UILabel {
                nameLbl.text = username; nameLbl.font = UIFont.systemFont(ofSize: kPAWWallPostTableViewFontSize); nameLbl.backgroundColor = .clear
                if cellIsRight {
                    nameLbl.textColor = UIColor(red: 175/255, green: 172/255, blue: 172/255, alpha: 1)
                    nameLbl.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.35); nameLbl.shadowOffset = CGSize(width: 0, height: 0.5)
                } else {
                    nameLbl.textColor = .black
                    nameLbl.shadowColor = UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.35); nameLbl.shadowOffset = CGSize(width: 0, height: 0.5)
                }
            }
            let textSize = (text as NSString).boundingRect(with: CGSize(width: kPAWWallPostTableViewCellWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: kPAWWallPostTableViewFontSize)], context: nil).size
            let nameSize = (username as NSString).boundingRect(with: CGSize(width: kPAWWallPostTableViewCellWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: kPAWWallPostTableViewFontSize)], context: nil).size
            let cellHeight = self.tableView(tableView, heightForRowAt: indexPath)
            let textWidth = max(textSize.width, nameSize.width)
            let bgImage = cell?.contentView.viewWithTag(kPAWCellBackgroundTag) as? UIImageView
            let textLbl = cell?.contentView.viewWithTag(kPAWCellTextLabelTag) as? UILabel
            let nameLbl = cell?.contentView.viewWithTag(kPAWCellNameLabelTag) as? UILabel
            if cellIsRight {
                nameLbl?.frame = CGRect(x: wallTableView.frame.size.width-textWidth-kPAWCellTextPaddingSides-kPAWCellPaddingSides, y: kPAWCellPaddingTop+kPAWCellTextPaddingTop+textSize.height, width: nameSize.width, height: nameSize.height)
                textLbl?.frame = CGRect(x: wallTableView.frame.size.width-textWidth-kPAWCellTextPaddingSides-kPAWCellPaddingSides, y: kPAWCellPaddingTop+kPAWCellTextPaddingTop, width: textSize.width, height: textSize.height)
                bgImage?.frame = CGRect(x: wallTableView.frame.size.width-textWidth-kPAWCellTextPaddingSides*2-kPAWCellPaddingSides, y: kPAWCellPaddingTop, width: textWidth+kPAWCellTextPaddingSides*2, height: cellHeight-kPAWCellPaddingTop-kPAWCellPaddingBottom)
            } else {
                nameLbl?.frame = CGRect(x: kPAWCellTextPaddingSides-kPAWCellPaddingSides, y: kPAWCellPaddingTop+kPAWCellTextPaddingTop+textSize.height, width: nameSize.width, height: nameSize.height)
                textLbl?.frame = CGRect(x: kPAWCellPaddingSides+kPAWCellTextPaddingSides, y: kPAWCellPaddingTop+kPAWCellTextPaddingTop, width: textSize.width, height: textSize.height)
                bgImage?.frame = CGRect(x: kPAWCellPaddingSides, y: kPAWCellPaddingTop, width: textWidth+kPAWCellTextPaddingSides*2, height: cellHeight-kPAWCellPaddingTop-kPAWCellPaddingBottom)
            }
            cell?.selectionStyle = .default
            return cell ?? UITableViewCell()
        } else {
            guard let offers = offers else { return UITableViewCell() }
            let offer = offers[indexPath.row]
            let theId = offer.offerId
            let cellId = "\(theId)"
            let cell = tableView.dequeueReusableCell(withIdentifier: cellId) ?? {
                let c = UITableViewCell(style: .subtitle, reuseIdentifier: cellId)
                c.backgroundColor = UIColor.white.withAlphaComponent(0.85)
                return c
            }()
            cell.textLabel?.text = offer.offerName
            cell.detailTextLabel?.text = offer.locationName
            cell.textLabel?.textColor = .black
            cell.detailTextLabel?.textColor = .black
            return cell
        }
    }

    private func loadCoverImage(for album: AlbumFullResponse, into imageView: UIImageView) {
        guard let urlString = album.coverAsset?.thumbnailURL,
              let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                imageView.image = image
            }
        }.resume()
    }

    @objc private func imagePressed(_ sender: UIButton) {
        // TODO: Handle cover image tap — navigate to full image or post detail
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if postSegmentedControl.selectedSegmentIndex == 1 {
            if indexPath.row >= wallPosts.count { return tableView.rowHeight }
            let album = wallPosts[indexPath.row]
            let text = album.title ?? ""
            let username = album.owner?.display ?? ""
            let textSize = (text as NSString).boundingRect(with: CGSize(width: kPAWWallPostTableViewCellWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: kPAWWallPostTableViewFontSize)], context: nil).size
            let nameSize = (username as NSString).boundingRect(with: CGSize(width: kPAWWallPostTableViewCellWidth, height: .greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: kPAWWallPostTableViewFontSize)], context: nil).size
            return kPAWCellPaddingTop + textSize.height + nameSize.height + kPAWCellBkgdOffset
        }
        return 44
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if postSegmentedControl.selectedSegmentIndex == 1 {
            if let p = post(for: wallPosts[indexPath.row]) {
                mapView.selectAnnotation(p, animated: true)
            }
        } else {
            if let offer = offers?[indexPath.row] {
                guard let odvc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "DDOfferDetailViewController") as? DDOfferDetailViewController else { return }
                odvc.configure(offer: offer, isFromWallet: false)
                navigationController?.pushViewController(odvc, animated: true)
            }
        }
    }

    @IBAction func segmentSwitched(_ sender: Any) {
        wallTableView.reloadData()
        syncMapPinsWithSelectedSegment()
    }

    // MARK: - Snap to Location

    @objc private func snapToCurrentLocation() {
        guard let appDelegate = UIApplication.shared.delegate as? DDAppDelegate,
              let currentLocation = appDelegate.currentLocation else { return }
        mapPannedSinceLocationUpdate = false
        let newRegion = MKCoordinateRegion(
            center: currentLocation.coordinate,
            latitudinalMeters: appDelegate.filterDistance * 2,
            longitudinalMeters: appDelegate.filterDistance * 2
        )
        mapView.setRegion(newRegion, animated: true)
        queryForAllPosts(nearLocation: currentLocation, withNearbyDistance: appDelegate.filterDistance)
        loadOffers()
    }
}
