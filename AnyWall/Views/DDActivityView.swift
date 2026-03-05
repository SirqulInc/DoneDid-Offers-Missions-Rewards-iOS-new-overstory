//
//  DDActivityView.swift
//  DoneDid
//

import UIKit

private let kActivityIndicatorPadding: CGFloat = 10.0

class DDActivityView: UIView {

    var label: UILabel {
        didSet {
            oldValue.removeFromSuperview()
            addSubview(label)
        }
    }
    var activityIndicator: UIActivityIndicatorView

    override init(frame: CGRect) {
        label = UILabel(frame: .zero)
		activityIndicator = UIActivityIndicatorView(style: .large)
        super.init(frame: frame)

        label.textColor = .white
        label.backgroundColor = .clear

        backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.7)

        addSubview(label)
        addSubview(activityIndicator)
    }

    required init?(coder: NSCoder) {
        label = UILabel(frame: .zero)
        activityIndicator = UIActivityIndicatorView(style: .large)
        super.init(coder: coder)
        addSubview(label)
        addSubview(activityIndicator)
    }

    override func layoutSubviews() {
        label.sizeToFit()
        label.center = CGPoint(x: frame.size.width / 2 + 10, y: frame.size.height / 2)
        label.frame = label.frame.integral

        let indicatorX = label.frame.origin.x - (activityIndicator.frame.size.width / 2) - kActivityIndicatorPadding
        let indicatorY = label.frame.origin.y + (label.frame.size.height / 2)
        activityIndicator.center = CGPoint(x: indicatorX, y: indicatorY)
    }
}
