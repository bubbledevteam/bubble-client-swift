//
//  GlucoseNotificationsSettingsTableViewController.swift
//  BubbleClientUI
//
//  Created by Bjørn Inge Berg on 07/05/2019.
//  Copyright © 2019 Mark Wilson. All rights reserved.
//
import UIKit
import LoopKitUI
import LoopKit

import HealthKit
import BubbleClient

public class CalibrationEditTableViewController: UITableViewController , mmTextFieldViewCellCellDelegate2 {
    
    public var cgmManager: BubbleClientManager?
    
    
    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("CalibrationEditTableViewController will now disappear")
        disappearDelegate?.onDisappear()
    }
    
    public weak var disappearDelegate : SubViewControllerWillDisappear? = nil
   
    
  
    private var newParams : DerivedAlgorithmParameters?
    

    
    public init(cgmManager: BubbleClientManager?) {
        self.cgmManager = cgmManager
        super.init(style: .grouped)
        
        newParams = cgmManager?.keychain.getLibreCalibrationData()
        
        // for testing only
        
         /*newParams = DerivedAlgorithmParameters(slope_slope: 0.0, slope_offset:0.0, offset_slope: 0.0, offset_offset: 0.0, isValidForFooterWithReverseCRCs: 1234, extraSlope: 1.0, extraOffset: 0.0)*/
        
        
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(AlarmTimeInputRangeCell.nib(), forCellReuseIdentifier: AlarmTimeInputRangeCell.className)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "UITableViewCell")
        
        tableView.register(GlucoseAlarmInputCell.nib(), forCellReuseIdentifier: GlucoseAlarmInputCell.className)
        
        tableView.register(TextFieldTableViewCell.nib(), forCellReuseIdentifier: TextFieldTableViewCell.className)
        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)
        tableView.register(SegmentViewCell.nib(), forCellReuseIdentifier: SegmentViewCell.className)
        
        tableView.register(mmSwitchTableViewCell.nib(), forCellReuseIdentifier: mmSwitchTableViewCell.className)
        
        tableView.register(mmTextFieldViewCell2.nib(), forCellReuseIdentifier: mmTextFieldViewCell2.className)
        self.tableView.rowHeight = 44;
    }
    
    private enum CalibrationDataInfoRow: Int {
        case slopeslope
        case slopeoffset
        case offsetslope
        case offsetoffset
        case extraoffset
        case extraslope
        case isValidForFooterWithCRCs
        
        
        
        static let count = 7
    }
    
    private enum Section: Int {
        case CalibrationDataInfoRow
        case sync
    }
    
    
    public override func numberOfSections(in tableView: UITableView) -> Int {
        //dynamic number of schedules + sync row
        return 2
        
    }
    
    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .CalibrationDataInfoRow:
            return CalibrationDataInfoRow.count
        case .sync:
            return 1
        }
    }
    /*
    weak var slopeslopece: mmTextFieldViewCell2?
    weak var slopeslopeCell: mmTextFieldViewCell2?
    weak var slopeoffsetCell: mmTextFieldViewCell2?
    weak var offsetslopeCell: mmTextFieldViewCell2?
    weak var offsetoffsetCell: mmTextFieldViewCell2?
    weak var isValidForFooterWithCRCsCell: mmTextFieldViewCell2?
    */
    
    func mmTextFieldViewCellDidUpdateValue(_ cell: mmTextFieldViewCell2, value: String?) {
        if let value = value, let numVal = Double(value) {
            
            
            
            switch CalibrationDataInfoRow(rawValue: cell.tag)! {
            case .isValidForFooterWithCRCs:
                //this should not happen as crc can not change
                
                print("isValidForFooterWithCRCs was updated: \(numVal)")
            case .slopeslope:
                newParams?.slope_slope = numVal
                print("slopeslope was updated: \(numVal)")
            case .slopeoffset:
                newParams?.slope_offset = numVal
                print("slopeoffset was updated: \(numVal)")
            case .offsetslope:
                newParams?.offset_slope = numVal
                print("offsetslope was updated: \(numVal)")
            case .offsetoffset:
                newParams?.offset_offset = numVal
                print("offsetoffset was updated: \(numVal)")
            case .extraoffset:
                newParams?.extraOffset = numVal
                print("extraoffset was updated: \(numVal)")
            case .extraslope:
                newParams?.extraSlope = numVal
                print("extraslope was updated: \(numVal)")
            }
            
        }
    }
    
    
    
    
    
    
    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        
        if indexPath.section == Section.sync.rawValue {
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell
            
            cell.textLabel?.text = NSLocalizedString("Save calibrations", comment: "The title for Save calibration")
            return cell
        }
        
        
        
        
        
        
        switch CalibrationDataInfoRow(rawValue: indexPath.row)! {
        case .offsetoffset:
            let cell = (tableView.dequeueReusableCell(withIdentifier: mmTextFieldViewCell2.className, for: indexPath) as! mmTextFieldViewCell2)
            cell.tag = indexPath.row
            cell.textInput?.text = String(newParams?.offset_offset ?? 0)
            cell.titleLabel.text = NSLocalizedString("offsetoffset", comment: "The title text for offsetoffset calibration setting")
            cell.delegate = self
            
            return cell
            
        case .offsetslope:
            let cell = (tableView.dequeueReusableCell(withIdentifier: mmTextFieldViewCell2.className, for: indexPath) as! mmTextFieldViewCell2)
            cell.tag = indexPath.row
            cell.textInput?.text = String(newParams?.offset_slope ?? 0)
            cell.titleLabel.text = NSLocalizedString("offsetslope", comment: "The title text for offsetslope calibration setting")
            cell.delegate = self
            
            return cell
        case .slopeoffset:
            let cell = (tableView.dequeueReusableCell(withIdentifier: mmTextFieldViewCell2.className, for: indexPath) as! mmTextFieldViewCell2)
            cell.tag = indexPath.row
            cell.textInput?.text = String(newParams?.slope_offset ?? 0)
            cell.titleLabel.text = NSLocalizedString("slopeoffset", comment: "The title text for slopeoffset calibration setting")
            cell.delegate = self
            return cell
        case .slopeslope:
            let cell = (tableView.dequeueReusableCell(withIdentifier: mmTextFieldViewCell2.className, for: indexPath) as! mmTextFieldViewCell2)
            
            cell.tag = indexPath.row
            cell.textInput?.text = String(newParams?.slope_slope ?? 0)
            cell.titleLabel.text = NSLocalizedString("slopeslope", comment: "The title text for slopeslope calibration setting")
            cell.delegate = self
            return cell
            
        case .isValidForFooterWithCRCs:
            let cell = (tableView.dequeueReusableCell(withIdentifier: mmTextFieldViewCell2.className, for: indexPath) as! mmTextFieldViewCell2)
            
            cell.tag = indexPath.row
          
            cell.textInput?.text = String(newParams?.isValidForFooterWithReverseCRCs ?? 0)
            
            cell.titleLabel.text = NSLocalizedString("IsValidForFooter", comment: "The title for the footer crc checksum linking these calibration values to this particular sensor")
            cell.delegate = self
            cell.isEnabled = false
            return cell
        case .extraoffset:
            let cell = (tableView.dequeueReusableCell(withIdentifier: mmTextFieldViewCell2.className, for: indexPath) as! mmTextFieldViewCell2)
            
            cell.tag = indexPath.row
            cell.textInput?.text = String(newParams?.extraOffset ?? 0)
            cell.titleLabel.text = NSLocalizedString("extraOffset", comment: "The title text for extra offset calibration setting")
            cell.delegate = self
            return cell
        case .extraslope:
            let cell = (tableView.dequeueReusableCell(withIdentifier: mmTextFieldViewCell2.className, for: indexPath) as! mmTextFieldViewCell2)
            
            cell.tag = indexPath.row
            cell.textInput?.text = String(newParams?.extraSlope ?? 0)
            cell.titleLabel.text = NSLocalizedString("extraSlope", comment: "The title text for extra slope calibration setting")
            cell.delegate = self
            return cell
        }
    }
    
    public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == Section.sync.rawValue {
            return nil
        }
        return NSLocalizedString("Calibrations edit mode", comment: "The title text for the Notification settings")
            
       
    }
    
    public override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return nil
        
    }
    
    public override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        switch  Section(rawValue: indexPath.section)!{
        case .CalibrationDataInfoRow:
            switch CalibrationDataInfoRow(rawValue: indexPath.row)! {
                
            case .slopeslope:
                print("slopeslope clicked")
            case .slopeoffset:
                print("slopeoffset clicked")
                
            case .offsetslope:
                print("offsetslope clicked")
            case .offsetoffset:
                print("offsetoffset clicked")
            case .isValidForFooterWithCRCs:
                print("isValidForFooterWithCRCs clicked")
            case .extraoffset:
                print("extraoffset clicked")
            case .extraslope:
                print("extraslope clicked")
            }
        case .sync:
            print("calibration save clicked")
            var isSaved  = false
            let controller : UIAlertController
            
            if let params = newParams {
                do {
                    try self.cgmManager?.keychain.setLibreCalibrationData(params)
                    isSaved = true
                } catch {
                    print("error: \(error.localizedDescription)")
                }
            }
            
            if isSaved {
                controller = OKAlertController("Calibrations saved!", title: "ok")
            } else {
                controller = ErrorAlertController("Calibrations could not be saved, Check that footer crc is non-zero and that all values have sane defaults", title: "calibration error")
            }
            
            
            self.present(controller, animated: false)
           
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}



