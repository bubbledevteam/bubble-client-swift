//
//  AlarmTimeInputRangeCell.swift
//  BubbleClientUI
//
//  Created by Bjørn Inge Berg on 12/04/2019.
//  Copyright © 2019 Mark Wilson. All rights reserved.
//

import Foundation


import UIKit


protocol mmTextFieldViewCellCellDelegate2: class {
    func mmTextFieldViewCellDidUpdateValue(_ cell: mmTextFieldViewCell2, value: String?)
}


class mmTextFieldViewCell2: UITableViewCell, UITextFieldDelegate {
    
    
    
    weak var delegate: mmTextFieldViewCellCellDelegate2?
    
    
    // MARK: Outlets
    
    @IBOutlet weak var iconImageView: UIImageView!
    
    @IBOutlet weak var titleLabel: UILabel!
    

    
    @IBAction func didStartEditing(_ sender: Any) {
        print("did start editing textfield cell")
        //textInput!.becomeFirstResponder()
        //textInput!.selectAll(nil)
    }
    @IBAction func didStopEditing(_ sender: Any) {
        print("did stop editing textfield cell")
        //textInput!.resignFirstResponder()
        delegate?.mmTextFieldViewCellDidUpdateValue(self, value: textInput?.text)
    }
    
    public var isEnabled : Bool {
        get {
            return titleLabel!.isEnabled && textInput!.isEnabled
        }
        set {
            titleLabel!.isEnabled = newValue
            textInput!.isEnabled = newValue
            
        }
    }
    
    @IBOutlet weak var textInput: UITextField?
    
    
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style:style, reuseIdentifier: reuseIdentifier)
        print("here1")
    }
    
    required init?(coder aDecoder: NSCoder) {
        NSLog("dabear:: required init")
        super.init(coder: aDecoder)
        print("here2")
        textInput?.keyboardType = .numberPad
       
        
        
    }
    
    
    
    
}
