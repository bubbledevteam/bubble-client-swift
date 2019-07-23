//
//  MiaomiaoClientManager+UI.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import LoopKitUI
import HealthKit
import MiaomiaoClient
import UIKit

extension MiaoMiaoClientManager: CGMManagerUI {
    public static func setupViewController() -> (UIViewController & CGMManagerSetupViewController & CompletionNotifying)? {
        return MiaomiaoClientSetupViewController()
    }
    
   

    public func settingsViewController(for glucoseUnit: HKUnit) -> (UIViewController & CompletionNotifying & CompletionNotifying) {
        let settings =  MiaomiaoClientSettingsViewController(cgmManager: self, glucoseUnit: glucoseUnit, allowsDeletion: true)
        let nav = SettingsNavigationViewController(rootViewController: settings)
        return nav
    }

    public var smallImage: UIImage? {
        let bundle = Bundle(for: type(of: self))
        
        return UIImage(named: "bubble", in: bundle, compatibleWith: nil)
    }
}
