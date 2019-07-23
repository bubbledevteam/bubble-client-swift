//
//  main.swift
//  clitester
//
//  Created by Bjørn Inge Berg on 03.10.2018.
//  Copyright © 2018 Mark Wilson. All rights reserved.
//

import Foundation
import os.log

print("Hello, World!")
/*
let client = BubbleClient(username: "test", password: "test2", shareServer: "https://bjorningedia5shareserver.herokuapp.com")
client.fetchLast(3) { (err, glucose) in
    os_log("dabear: fetchlast", type: .default)
    os_log("dabear: mac err: %@", log: .default, type: .default, "\(err)")
    
    if let glucose = glucose {
       os_log("dabear: mac glucose %@", log: .default, type: .default, "\(glucose)")
        
    }
    
    
}
os_log("dabear: macmaindidload", type: .default)
*/
//This semaphore wait is neccessary when running as a mac os cli program. Consider removing this in a GUI app
//it kinda works like python's input() or raw_input() in a cli program, except it doesn't accept input, ofcourse..
let sema = DispatchSemaphore( value: 0 )
sema.wait()
