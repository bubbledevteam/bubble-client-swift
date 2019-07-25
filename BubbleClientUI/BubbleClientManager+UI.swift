//
//  BubbleClientManager+UI.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import LoopKitUI
import HealthKit
import BubbleClient
import UIKit

extension BubbleClientManager: CGMManagerUI {
    public static func setupViewController() -> (UIViewController & CGMManagerSetupViewController & CompletionNotifying)? {
        return nil
    }
    
   

    public func settingsViewController(for glucoseUnit: HKUnit) -> (UIViewController & CompletionNotifying & CompletionNotifying) {
        let settings =  BubbleClientSettingsViewController(cgmManager: self, glucoseUnit: glucoseUnit, allowsDeletion: true)
        let nav = SettingsNavigationViewController(rootViewController: settings)
        return nav
    }

    public var smallImage: UIImage? {
        return UIImage.init(named: "bubble")
    }
}
