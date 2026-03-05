//
//  DDConstants.swift
//  DoneDid
//

import Foundation

struct DDConstants {
    static let wallPostMaximumCharacterCount: UInt = 140
    static let feetToMeters: Double = 0.3048
    static let feetToMiles: Double = 5280.0
    static let wallPostMaximumSearchDistance: Double = 100.0
    static let metersInAKilometer: Double = 1000.0
    static let wallPostsSearch: UInt = 20

    // Notification keys
    static let filterDistanceKey = "filterDistance"
    static let locationKey = "location"

    // Notification names
    static let filterDistanceChangeNotification = "kPAWFilterDistanceChangeNotification"
    static let locationChangeNotification = "kPAWLocationChangeNotification"
    static let postCreatedNotification = "kPAWPostCreatedNotification"

    // UI strings
    static let wallCantViewPost = "Can't view post! Get closer."

    // Sirqul keys
    static let sirqulAppKey: String = "7ee9b708cf7567b7dd6f31dfa0c94161"
    static let sirqulPrivateKey: String = "8e6c8f6dd051102e01413150e05b9f653db5f7ed"
}
