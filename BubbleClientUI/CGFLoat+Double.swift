//
//  CGFLoat+Double.swift
//  BubbleClientUI
//
//  Created by Bjørn Inge Berg on 06/06/2019.
//  Copyright © 2019 Mark Wilson. All rights reserved.
//

import Foundation
import UIKit
func * (lhs:CGFloat, rhs:Double) -> Double {
    return Double(lhs) * rhs
}

func * (lhs:CGFloat, rhs:Double) -> CGFloat {
    return lhs * CGFloat(rhs)
}

func * (lhs:Double, rhs:CGFloat) -> Double {
    return lhs * Double(rhs)
}

func * (lhs:Double, rhs:CGFloat) -> CGFloat {
    return CGFloat(lhs) * rhs
}
