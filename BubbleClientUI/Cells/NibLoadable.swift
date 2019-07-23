//
//  NibLoadable.swift
//  BubbleClientUI
//
//  Created by Bjørn Inge Berg on 11/04/2019.
//  Copyright © 2019 Mark Wilson. All rights reserved.
//

import UIKit
import LoopKitUI

protocol NibLoadable: IdentifiableClass {
    static func nib() -> UINib
}


extension NibLoadable {
    static func nib() -> UINib {
        return UINib(nibName: className, bundle: Bundle(for: self))
    }
}

extension TextFieldTableViewCell: NibLoadable { }

extension AlarmTimeInputRangeCell: NibLoadable { }
extension GlucoseAlarmInputCell: NibLoadable {}
extension SegmentViewCell: NibLoadable {}
extension mmSwitchTableViewCell: NibLoadable {}
extension mmTextFieldViewCell: NibLoadable {}
extension mmTextFieldViewCell2: NibLoadable {}
extension SnoozeView: NibLoadable {}
