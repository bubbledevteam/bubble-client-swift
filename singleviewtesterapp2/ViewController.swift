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
//        os_log("dabear: iphone view did load %@", log: .default, type: .default, "yes")
//        let client = BubbleClient(username: "test", password: "test2", spikeServer: "sdfas")
//        
//        client.fetchLast(3) { (error, glucose) in
//            os_log("dabear: iphonefetchlast", type: .default)
//            os_log("dabear: iphone err: %@", log: .default, type: .default, "\(error)")
//            
//            if let glucose = glucose {
//                os_log("dabear: iphone glucose %@", log: .default, type: .default, "\(glucose)")
//                
//            }
//        }
        os_log("dabear: connecting to glucose source %@", log: .default, type: .default, "yes")
        //self.glucoseController = BloodSugarController()
        //var service = BubbleService()
        //var client = BubbleProxy()
        
//        let manager = BubbleClientManager()
        test()
    }
    
    func test() {
        let data = "145cd818030000000000000000000000000000000000000099f50d120505c8785900f704c86c5900ec04c8605900e504c8585900d204c8585900ee04c8685900db04c8845900c104c8a45900ad04c8b059009d04c8a859008d04c8c059007f04c8ec59007104c8bc59001f05c89459001a05c8a059001105c89c59008f02c8245a005d03c83059002104c8085a00f604c87059006805c83059000705c8a05900fb04c8c059006c05c8e45900a905c87c5900dd05c81059006306c83c58009b06c8d458003606c8c458000206c87c58009205c8d858002105c8b859004305c8bc59001d05c89459009705c85859009f05c8485900e505c87459005706c8a85900a206c8a05900ac06c80859006806c8445800c105c8705800fb04c80059003a04c8bc5900b703c86459004f03c8881980ec02c8885900a302c8b45800fe4d0000d6c9000814094751140796805a00eda60ca51ac8043b296a".hexadecimal ?? Data()
        
        
//        let p = LibreDerivedAlgorithmParameters.init(slope_slope: 0.00299491, slope_offset: 1.117e-05, offset_slope: 0.00334372, offset_offset: -20.37522493, isValidForFooterWithReverseCRCs: 1, extraSlope: 0, extraOffset: 1)
        
//        slopeslope: 1.4525993883792041e-05,
//        slopeoffset: -0.0007645259938837704,
//        offsetoffset: -14.553516819572021,
//        offsetSlope: 0.0005168195718654872,
//        isValidForFooterWithReverseCRCs: 1,
//        version: 2
        
        let p = LibreDerivedAlgorithmParameters.init(slope_slope: 1.4525993883792041e-05, slope_offset: -0.0007645259938837704, offset_slope: 0.0005168195718654872, offset_offset: -14.553516819572021, isValidForFooterWithReverseCRCs: 1, extraSlope: 1, extraOffset: 0)
        
        let list = LibreOOPClient.oopParams(libreData: [UInt8](data), params: p)
        for glucose in list {
            print(glucose.description)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

