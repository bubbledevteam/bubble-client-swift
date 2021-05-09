//
//  BubbleClientPlugin.swift
//  BubbleClientPlugin
//
//  Created by yan on 2021/5/9.
//  Copyright © 2021 Mark Wilson. All rights reserved.
//

import Foundation
import LoopKitUI
import BubbleClient
import BubbleClientUI
import os.log

class BubbleClientPlugin: NSObject, LoopUIPlugin {
    
    private let log = OSLog(category: "BubbleClientPlugin")
    
    public var pumpManagerType: PumpManagerUI.Type? {
        return nil
    }
    
    public var cgmManagerType: CGMManagerUI.Type? {
        return BubbleClientManager.self
    }
    
    override init() {
        super.init()
        log.default("BubbleClientPlugin Instantiated")
    }
}

