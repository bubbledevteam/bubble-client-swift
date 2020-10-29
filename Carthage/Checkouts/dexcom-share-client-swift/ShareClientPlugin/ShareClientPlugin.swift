//
//  ShareClientPlugin.swift
//  ShareClientPlugin
//
//  Created by Nathaniel Hamming on 2019-12-19.
//  Copyright © 2019 Mark Wilson. All rights reserved.
//

import Foundation
import LoopKitUI
import ShareClient
import ShareClientUI
import os.log

class ShareClientPlugin: NSObject, LoopUIPlugin {
    
    private let log = OSLog(category: "ShareClientPlugin")
    
    public var pumpManagerType: PumpManagerUI.Type? {
        return nil
    }
    
    public var cgmManagerType: CGMManagerUI.Type? {
        return ShareClientManager.self
    }
    
    override init() {
        super.init()
        log.default("ShareClientPlugin Instantiated")
    }
}
