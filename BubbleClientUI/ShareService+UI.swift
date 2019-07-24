//
//  ShareService+UI.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import LoopKitUI
import BubbleClient

public enum LibreOOPWebAzzure: String {
    case LibreOOPWebAzzure="https://libreoopweb.azurewebsites.net"
    
    
}

extension BubbleService: ServiceAuthenticationUI {
    public var credentialFormFields: [ServiceCredential] {
        return [

            ServiceCredential(
                title: NSLocalizedString("Password", comment: "The title of the Spike password credential"),
                isSecret: true,
                keyboardType: .asciiCapable
            ),
            ServiceCredential(
                title: NSLocalizedString("AutoCalibrationSite", comment: "The title of the auto calibration server URL credential"),
                isSecret: false,
                options: [
                    (title: NSLocalizedString("LibreOOPWeb", comment: "LibreOOPWeb server option"),
                     value: LibreOOPWebAzzure.LibreOOPWebAzzure.rawValue)
                    
                ]
            )
        ]
    }
}
