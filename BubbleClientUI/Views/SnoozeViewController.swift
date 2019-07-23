//
//  SnoozeViewController.swift
//  BubbleClientUI
//
//  Created by Bjørn Inge Berg on 04/06/2019.
//  Copyright © 2019 Mark Wilson. All rights reserved.
//

import Foundation
import UIKit

class SnoozeViewController: UIViewController {
   
    
    weak var customView: SnoozeView!
    
    override func loadView() {
        super.loadView()
        
        let customView = SnoozeView()
        self.view.addSubview(customView)
        NSLayoutConstraint.activate([
            customView.topAnchor.constraint(equalTo: self.view.topAnchor),
            customView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            customView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            customView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            ])
        self.customView = customView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        customView.snoozeButton.setTitle("2Test2", for: .normal)
        //self.customView.textLabel.text = "Lorem ipsum"
    }
}

