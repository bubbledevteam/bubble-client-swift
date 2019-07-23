//
//  CollectionExtensions.swift
//  BubbleClientUI
//
//  Created by Bjørn Inge Berg on 26/03/2019.
//  Copyright © 2019 Mark Wilson. All rights reserved.
//

import Foundation

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Array {
    
    mutating public func safeIndexAt(_ index: Int, default defaultValue: @autoclosure () -> Element) -> Element? {
        guard index >= 0, index < endIndex else {
            
            var val : Element? = nil
            while !indices.contains(index) {
                val = defaultValue()
                if let val = val {
                    self.append(val)
                } else {
                    //unsafe to continue as this might be a never ending loop
                    break
                }
                
            }
            
            
            
            return val
        }
        
        return self[index]
    }
}

