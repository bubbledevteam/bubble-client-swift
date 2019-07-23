//
//  SnoozeView.swift
//  BubbleClientUI
//
//  Created by Bjørn Inge Berg on 04/06/2019.
//  Copyright © 2019 Mark Wilson. All rights reserved.
//

import UIKit
class View: UIView {
    
    init() {
        super.init(frame: .zero)
        
        self.initialize()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.initialize()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        self.initialize()
    }
    
    func initialize() {
        self.translatesAutoresizingMaskIntoConstraints = false
    }
}

class SnoozeView: View, UIPickerViewDataSource, UIPickerViewDelegate {

    
    
    
    // this is going to be our container object
    @IBOutlet weak var containerView: UIView!
    
    
    @IBOutlet weak var snoozeDescription: UITextField!
    
    @IBOutlet weak var snoozePicker: UIPickerView!
    
    @IBOutlet weak var snoozeButton: UIButton!
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 3
    }
    
  
    func pickerView(_ pickerView: UIPickerView,
                    titleForRow row: Int,
                    forComponent component: Int) -> String? {
        
        // Return a string from the array for this row.
        //return data[row]
        return "row: \(row), component \(component)"
    }
    
    
    override func initialize() {
        super.initialize()
        
        // first: load the view hierarchy to get proper outlets
        /*let name = String(describing: type(of: self))
        let nib = UINib(nibName: name, bundle: .main)
        nib.instantiate(withOwner: self, options: nil)*/
        let nib = SnoozeView.nib()
        print("nib is \(nib)")
        nib.instantiate(withOwner: self, options: nil)
        
        // next: append the container to our view
        self.addSubview(self.containerView)
        self.containerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.containerView.topAnchor.constraint(equalTo: self.topAnchor),
            self.containerView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            self.containerView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            self.containerView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            ])
        
        
        //snoozeButton.frame.size = CGSize(width: self.frame.width, height: self.frame.height)
        snoozeButton.setTitle("Test1", for: .normal)
        snoozePicker.dataSource = self
        snoozePicker.delegate = self
        snoozePicker.layer.cornerRadius = 4
        snoozePicker.layer.borderWidth = 1
        
    }
    

    
}

extension UIView
{
    func fixInView(_ container: UIView!) -> Void{
        self.translatesAutoresizingMaskIntoConstraints = false;
        self.frame = container.frame;
        container.addSubview(self);
        NSLayoutConstraint(item: self, attribute: .leading, relatedBy: .equal, toItem: container, attribute: .leading, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .trailing, relatedBy: .equal, toItem: container, attribute: .trailing, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .top, relatedBy: .equal, toItem: container, attribute: .top, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .bottom, relatedBy: .equal, toItem: container, attribute: .bottom, multiplier: 1.0, constant: 0).isActive = true
    }
}
