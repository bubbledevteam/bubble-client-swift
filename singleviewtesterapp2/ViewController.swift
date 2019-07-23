//
//  ViewController.swift
//  singleviewtesterapp2
//
//  Created by Bjørn Inge Berg on 04.10.2018.
//  Copyright © 2018 Mark Wilson. All rights reserved.
//

import UIKit
import os
import BubbleClient
class ViewController: UIViewController {
    //public var glucoseController: BloodSugarController?
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        os_log("dabear: iphone view did load %@", log: .default, type: .default, "yes")
        /*let client = BubbleClient(username: "test", password: "test2", spikeServer: KnownSpikeServers.LOCAL_SPIKE)
        
        client.fetchLast(3) { (error, glucose) in
            os_log("dabear: iphonefetchlast", type: .default)
            os_log("dabear: iphone err: %@", log: .default, type: .default, "\(error)")
            
            if let glucose = glucose {
                os_log("dabear: iphone glucose %@", log: .default, type: .default, "\(glucose)")
                
            }
        }*/
        os_log("dabear: connecting to glucose source %@", log: .default, type: .default, "yes")
        //self.glucoseController = BloodSugarController()
        //var service = BubbleService()
        //var client = BubbleProxy()
        
        
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

