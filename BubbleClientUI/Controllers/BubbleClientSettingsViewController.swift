//
//  MiaomiaoClientSettingsViewController.swift
//  Loop
//
//  Copyright © 2018 LoopKit Authors. All rights reserved.
//

import UIKit
import HealthKit
import LoopKit
import LoopKitUI
import BubbleClient



public class BubbleClientSettingsViewController: UITableViewController, SubViewControllerWillDisappear { //, CompletionNotifying{
    //public weak var completionDelegate: CompletionDelegate?
    
    public func onDisappear() {
        // this is being called only from alarm, calibration and notifications ui
        // when they disappear
        // the idea is to reload certain gui elements that may have changed
        self.tableView.reloadData()
    }
    
    private let isDemoMode = false
    public var cgmManager: BubbleClientManager?

    public let glucoseUnit: HKUnit

    public let allowsDeletion: Bool

    public init(cgmManager: BubbleClientManager, glucoseUnit: HKUnit, allowsDeletion: Bool) {
        self.cgmManager = cgmManager
        self.glucoseUnit = glucoseUnit
        
        //only override savedglucose unit if we haven't saved this locally before
        if UserDefaults.standard.mmGlucoseUnit == nil {
            UserDefaults.standard.mmGlucoseUnit = glucoseUnit
        }
        
        self.allowsDeletion = allowsDeletion

        super.init(style: .grouped)
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func tableView(_ tableView: UITableView, heightForRowAt index: IndexPath) -> CGFloat {
        switch Section(rawValue: index.section)! {
        case .snooze:
            switch GlucoseScheduleList.getActiveAlarms() {
            case .none:
                return UITableViewAutomaticDimension
            default:
                return 100
            }
            
            
        default:
            return UITableViewAutomaticDimension
            
        }
        
    }
    override public func viewDidLoad() {
        super.viewDidLoad()

        title = cgmManager?.localizedTitle

        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.estimatedRowHeight = 44

        tableView.sectionHeaderHeight = UITableViewAutomaticDimension
        tableView.estimatedSectionHeaderHeight = 55

        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.className)
        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)
        
        let button = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped(_:)))
        self.navigationItem.setRightBarButton(button, animated: false)
    }
    
    @objc func doneTapped(_ sender: Any) {
        complete()
    }
    
    private func complete() {
        if let nav = navigationController as? SettingsNavigationViewController {
            nav.notifyComplete()
        }
    }
    

    // MARK: - UITableViewDataSource

    private enum Section: Int {
        case snooze
        case latestReading
        case sensorInfo
        case latestBridgeInfo
        case advanced
        
        case delete

        static let count = 6
    }

    override public func numberOfSections(in tableView: UITableView) -> Int {
        return allowsDeletion ? Section.count : Section.count - 1
    }

    private enum LatestReadingRow: Int {
        case glucose
        case date
        case trend
        case footerChecksum
        static let count = 4
    }
    
    private enum LatestSensorInfoRow: Int {
        case sensorAge
        case sensorState
        case sensorSerialNumber
        
        static let count = 3
    }
    
    private enum LatestBridgeInfoRow: Int {
        
        case battery
        case hardware
        case firmware
        case connectionState
        
        static let count = 4
    }
    
    private enum LatestCalibrationDataInfoRow: Int {
        case slopeslope
        case slopeoffset
        case offsetslope
        case offsetoffset
        case extraSlope
        case extraOffset
        
        case isValidForFooterWithCRCs
        
        
        case edit
        
        static let count = 0
    }
    
    private enum AdvancedSettingsRow: Int {
        case alarms
        case glucoseNotifications
        case dangermode
        static let count = 2
    }

    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .latestReading:
            return LatestReadingRow.count
        case .sensorInfo:
            return LatestSensorInfoRow.count
        case .delete:
            return 1
        case .latestBridgeInfo:
            return LatestBridgeInfoRow.count
            
        case .advanced:
            return AdvancedSettingsRow.count
        case .snooze:
            return 1
        }
    }

    private lazy var glucoseFormatter: QuantityFormatter = {
        let formatter = QuantityFormatter()
        formatter.setPreferredNumberFormatter(for: glucoseUnit)
        return formatter
    }()

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .long
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
    
    private func dangerModeActivation(_ isOk: Bool, controller: UIAlertController) {
        if isOk, let textfield = (controller.textFields?[safe: 0]), let text = textfield.text {
            if let bundleSeed = bundleSeedID() {
                
                let controller: UIAlertController
                if text.trimmingCharacters(in: .whitespaces).lowercased() == bundleSeed.lowercased() {
                    UserDefaults.standard.dangerModeActivated = true
                    controller = OKAlertController("Danger mode activated! You can now edit calibrations!", title: "Danger mode successful")
                } else {
                    controller = ErrorAlertController("Danger mode could not be activated, check that your team identifier matches", title: "Danger mode unsuccessful")
                    
                }
//                let dangerCellIndex = IndexPath(row: AdvancedSettingsRow.dangermode.rawValue, section: Section.advanced.rawValue)
                
                
//
//                let editCellIndex = IndexPath(row:  LatestCalibrationDataInfoRow.edit.rawValue, section: Section.latestCalibrationData.rawValue)
//
//                self.tableView.reloadRows(at: [dangerCellIndex, editCellIndex],with: .none)
//
//                self.presentStatus(controller)
                
                
                
            }
            
        }
    }

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .latestReading:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath) as! SettingsTableViewCell
            let glucose = cgmManager?.latestBackfill

            switch LatestReadingRow(rawValue: indexPath.row)! {
            case .glucose:
                cell.textLabel?.text = NSLocalizedString("Glucose", comment: "Title describing glucose value")

                if let quantity = glucose?.quantity, let formatted = glucoseFormatter.string(from: quantity, for: glucoseUnit) {
                    cell.detailTextLabel?.text = formatted
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
            case .date:
                cell.textLabel?.text = NSLocalizedString("Date", comment: "Title describing glucose date")

                if let date = glucose?.timestamp {
                    cell.detailTextLabel?.text = dateFormatter.string(from: date)
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
            case .trend:
                cell.textLabel?.text = NSLocalizedString("Trend", comment: "Title describing glucose trend")

                cell.detailTextLabel?.text = glucose?.trendType?.localizedDescription ?? SettingsTableViewCell.NoValueString
           
            case .footerChecksum:
                cell.textLabel?.text = NSLocalizedString("Sensor Footer checksum", comment: "Title describing Sensor footer reverse checksum")
                
                
                cell.detailTextLabel?.text = isDemoMode ? "demo123" : cgmManager?.sensorFooterChecksums
            }

            return cell
        case .delete:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell

            cell.textLabel?.text = NSLocalizedString("Delete CGM", comment: "Title text for the button to remove a CGM from Loop")
            cell.textLabel?.textAlignment = .center
            cell.tintColor = .delete
            cell.isEnabled = true
            return cell
        case .latestBridgeInfo:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath) as! SettingsTableViewCell
            
            
            switch LatestBridgeInfoRow(rawValue: indexPath.row)! {
            case .battery:
                cell.textLabel?.text = NSLocalizedString("Battery", comment: "Title describing bridge battery info")
                
                
                cell.detailTextLabel?.text = cgmManager?.battery
                
            case .firmware:
                cell.textLabel?.text = NSLocalizedString("Firmware", comment: "Title describing bridge firmware info")
                
                
                cell.detailTextLabel?.text = cgmManager?.firmwareVersion
                
            case .hardware:
                cell.textLabel?.text = NSLocalizedString("Hardware", comment: "Title describing bridge hardware info")
                
                cell.detailTextLabel?.text = cgmManager?.hardwareVersion
            case .connectionState:
                cell.textLabel?.text = NSLocalizedString("Connection State", comment: "Title Bridge connection state")
                
                cell.detailTextLabel?.text = cgmManager?.connectionState
            }
            
            return cell
//        case .latestCalibrationData:
//            var cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath)
//
//            let data = cgmManager?.calibrationData
//            /*
//             case slopeslope
//             case slopeoffset
//             case offsetslope
//             case offsetoffset
//             extraSlope
//             extraOffset
//             */
//            switch LatestCalibrationDataInfoRow(rawValue: indexPath.row)! {
//
//            case .slopeslope:
//                cell.textLabel?.text = NSLocalizedString("Slope_slope", comment: "Title describing calibrationdata slopeslope")
//
//                if let data=data{
//                    cell.detailTextLabel?.text = "\(data.slope_slope.scientificStyle)"
//                } else {
//                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
//                }
//            case .slopeoffset:
//                cell.textLabel?.text = NSLocalizedString("Slope_offset", comment: "Title describing calibrationdata slopeoffset")
//
//                if let data=data{
//                    cell.detailTextLabel?.text = "\(data.slope_offset.scientificStyle)"
//                } else {
//                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
//                }
//            case .offsetslope:
//                cell.textLabel?.text = NSLocalizedString("Offset_slope", comment: "Title describing calibrationdata offsetslope")
//
//                if let data=data{
//                    cell.detailTextLabel?.text = "\(data.offset_slope.scientificStyle)"
//                } else {
//                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
//                }
//            case .offsetoffset:
//                cell.textLabel?.text = NSLocalizedString("Offset_offset", comment: "Title describing calibrationdata offsetoffset")
//
//                if let data=data{
//                    cell.detailTextLabel?.text = "\(data.offset_offset.fourDecimals)"
//                } else {
//                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
//                }
//
//            case .isValidForFooterWithCRCs:
//                cell.textLabel?.text = NSLocalizedString("Valid For Footer", comment: "Title describing calibrationdata validity")
//
//                if let data=data{
//                    cell.detailTextLabel?.text = isDemoMode ? "demo123"  : "\(data.isValidForFooterWithReverseCRCs)"
//                } else {
//                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
//                }
//            case .edit:
//                cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath)
//
//                cell.textLabel?.text = NSLocalizedString("Edit Calibrations", comment: "Title describing calibrationdata edit button")
//
//                cell.textLabel?.textColor = UIColor.blue
//                if UserDefaults.standard.dangerModeActivated{
//
//                    cell.detailTextLabel?.text = "Available"
//                    cell.accessoryType = .disclosureIndicator
//                } else {
//
//                    cell.detailTextLabel?.text = "Unavailable"
//                }
//            case .extraSlope:
//                cell.textLabel?.text = NSLocalizedString("Extra_slope", comment: "Title describing calibrationdata extra slope")
//
//                if let data=data{
//                    cell.detailTextLabel?.text = "\(data.extraSlope)"
//                } else {
//                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
//                }
//            case .extraOffset:
//                cell.textLabel?.text = NSLocalizedString("Extra_offset", comment: "Title describing calibrationdata extra offset")
//
//                if let data=data{
//                    cell.detailTextLabel?.text = "\(data.extraOffset)"
//                } else {
//                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
//                }
//            }
//            return cell
        case .sensorInfo:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath) as! SettingsTableViewCell
            
            
            switch LatestSensorInfoRow(rawValue: indexPath.row)! {
            case .sensorState:
                cell.textLabel?.text = NSLocalizedString("Sensor State", comment: "Title describing sensor state")
                
                cell.detailTextLabel?.text = cgmManager?.sensorStateDescription
            case .sensorAge:
                cell.textLabel?.text = NSLocalizedString("Sensor Age", comment: "Title describing sensor Age")
                
                cell.detailTextLabel?.text = cgmManager?.sensorAge
                
            case .sensorSerialNumber:
                cell.textLabel?.text = NSLocalizedString("Sensor Serial", comment: "Title describing sensor serial")
                
                cell.detailTextLabel?.text = isDemoMode ? "0M007DEMO1" :cgmManager?.sensorSerialNumber
                
                
                
                
            }
            return cell
        case .advanced:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath) as! SettingsTableViewCell
            
            switch AdvancedSettingsRow(rawValue: indexPath.row)! {
            case .alarms:
                cell.textLabel?.text = NSLocalizedString("Alarms", comment: "Title describing sensor Gluocse Alarms")
                let schedules = UserDefaults.standard.enabledSchedules?.count ?? 0
                let totalSchedules = max(UserDefaults.standard.glucoseSchedules?.schedules.count ?? 0, GlucoseScheduleList.minimumSchedulesCount) 
                
                cell.detailTextLabel?.text = "enabled: \(schedules) / \(totalSchedules)"
                cell.accessoryType = .disclosureIndicator
            case .glucoseNotifications:
                cell.textLabel?.text = NSLocalizedString("Notifications", comment: "Title describing  Notifications Setup")
                
                let allToggles = UserDefaults.standard.allNotificationToggles
                let positives = allToggles.filter( { $0}).count
                
                cell.detailTextLabel?.text = "enabled: \(positives) / \(allToggles.count)"
                cell.accessoryType = .disclosureIndicator
            case .dangermode:
                cell.textLabel?.text = NSLocalizedString("Danger mode", comment: "Title describing  Advanced dangerous settings button")
                
                
                if UserDefaults.standard.dangerModeActivated {
                    cell.detailTextLabel?.text = "Activated"
                } else {
                    cell.detailTextLabel?.text = "Deactivated"
                }
                
            }
            
            
            return cell
        case .snooze:
            //let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath) as! SettingsTableViewCell
            let cell = UITableViewCell(style: UITableViewCellStyle.default, reuseIdentifier: "DefaultCell")
            
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.text = NSLocalizedString("Snooze Alerts", comment: "Title of cell to snooze active alarms")
            
            //cell.textLabel?.text = NSLocalizedString("Snooze Alert", comment: "Title of cell to snooze active alarms")
            //cell.textLabel?.textAlignment = .center
            
            //cell.detailTextLabel?.text =  ""
            //cell.accessoryType = .none
            return cell
        }
    }

    public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .snooze:
            return nil
        case .sensorInfo:
            return NSLocalizedString("Sensor Info", comment: "Section title for latest sensor info")
        case .latestReading:
            return NSLocalizedString("Latest Reading", comment: "Section title for latest glucose reading")
        case .delete:
            return nil
        case .latestBridgeInfo:
            return NSLocalizedString("Latest Bridge info", comment: "Section title for latest bridge info")
//        case .latestCalibrationData:
//            return NSLocalizedString("Latest Autocalibration Parameters", comment: "Section title for latest bridge info")
//
        case .advanced:
            return NSLocalizedString("Advanced", comment: "Advanced Section")
        
        }
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .latestReading:
            tableView.deselectRow(at: indexPath, animated: true)
        case .delete:
            let confirmVC = UIAlertController(cgmDeletionHandler: {
                NSLog("dabear:: confirmed: cgmmanagerwantsdeletion")
                if let cgmManager = self.cgmManager {
                    cgmManager.disconnect()
                    cgmManager.cgmManagerDelegate?.cgmManagerWantsDeletion(cgmManager)
                    
                    self.cgmManager = nil
                    
                    
                    
                }
                
                self.complete()
            })

            present(confirmVC, animated: true) {
                tableView.deselectRow(at: indexPath, animated: true)
            }
        case .latestBridgeInfo:
            tableView.deselectRow(at: indexPath, animated: true)
//        case .latestCalibrationData:
//
//            if LatestCalibrationDataInfoRow(rawValue: indexPath.row)! == .edit {
//                if UserDefaults.standard.dangerModeActivated {
//                    //ok
//                    print("user can edit calibrations")
//                    let controller = CalibrationEditTableViewController(cgmManager: self.cgmManager)
//                    controller.disappearDelegate = self
//                    self.show(controller, sender: self)
//                } else {
//                    self.presentStatus(OKAlertController("Could not access calibration settings, danger mode was not activated!", title: "No can do!"))
//                }
//                tableView.deselectRow(at: indexPath, animated: true)
//                return
//            }
//
//            let confirmVC = UIAlertController(calibrateHandler:  {
//
//                if let cgmManager = self.cgmManager {
//
//                    guard let (accessToken, url) =  cgmManager.keychain.getAutoCalibrateWebCredentials() else {
//                        NSLog("dabear:: could not calibrate, accesstoken or url was nil")
//                        self.presentStatus(OKAlertController(LibreError.invalidAutoCalibrationCredentials.errorDescription, title: "Error"))
//
//                        return
//                    }
//
//                    guard let data = cgmManager.lastValidSensorData else {
//                        NSLog("No sensordata was present, unable to recalibrate!")
//                        self.presentStatus(OKAlertController(LibreError.noSensorData.errorDescription, title: "Error"))
//
//                        return
//                    }
//
//                    calibrateSensor(accessToken: accessToken, site: url.absoluteString, sensordata: data) { [weak self] (calibrationparams)  in
//                        guard let params = calibrationparams else {
//                            NSLog("dabear:: could not calibrate sensor, check libreoopweb permissions and internet connection")
//                            self?.presentStatus(OKAlertController(LibreError.noCalibrationData.errorDescription, title: "Error"))
//
//                            return
//                        }
//
//                        do {
//                            try self?.cgmManager?.keychain.setLibreCalibrationData(params)
//                        } catch {
//                            NSLog("dabear:: could not save calibrationdata")
//                            self?.presentStatus(OKAlertController(LibreError.invalidCalibrationData.errorDescription, title: "Error"))
//                            return
//                        }
//
//                        self?.presentStatus(OKAlertController("Calibration success!", title: "Success"))
//
//
//
//                    }
//
//
//
//                }
//
//
//            })
//
//            present(confirmVC, animated: true) {
//                tableView.deselectRow(at: indexPath, animated: true)
//
//            }
//
//
        case .sensorInfo:
            tableView.deselectRow(at: indexPath, animated: true)
            switch LatestSensorInfoRow.init(rawValue: indexPath.row)! {
            case .sensorState:
                let vc = BubbleClientSearchViewController()
                vc.cgmManager = cgmManager
                navigationController?.pushViewController(vc, animated: true)
                break
            case .sensorAge:
                break
            case .sensorSerialNumber:
                break
            }
        case .advanced:
            tableView.deselectRow(at: indexPath, animated: true)
            
            
            
            switch AdvancedSettingsRow(rawValue: indexPath.row)! {
            case .alarms:
                let controller = AlarmSettingsTableViewController(glucoseUnit: self.glucoseUnit)
                controller.disappearDelegate = self
                show(controller, sender: nil)
            case .glucoseNotifications:
                let controller = NotificationsSettingsTableViewController(glucoseUnit: self.glucoseUnit)
                controller.disappearDelegate = self
                show(controller, sender: nil)
            case .dangermode:
                if UserDefaults.standard.dangerModeActivated {
                    UserDefaults.standard.dangerModeActivated = false
//                    let dangerCellIndex = IndexPath(row: AdvancedSettingsRow.dangermode.rawValue, section: Section.advanced.rawValue)
//                    let editCellIndex = IndexPath(row:  LatestCalibrationDataInfoRow.edit.rawValue, section: Section.latestCalibrationData.rawValue)
//                    self.tableView.reloadRows(at: [dangerCellIndex, editCellIndex], with: .none)
                    
                } else {
                    let team = bundleSeedID() ?? "Unknown???!"
                    let msg = "To activate dangermode, please input your team identifier. It is important that you take an active choice here, so don't copy/paste but type it in correctly. Your team identifer is: \(team)"
                    
                    let controller = InputAlertController(msg, title: "Activate danger mode", inputPlaceholder: "Enter your team identifer") { [weak self] (isOk, controller) in
                        self?.dangerModeActivation(isOk, controller: controller)
                        
                    }
                    self.presentStatus(controller)
                }
            }
            
            
            
            
        case .snooze:
            print("Snooze called")
            let controller = SnoozeTableViewController()
            show(controller, sender: nil)
            tableView.deselectRow(at: indexPath, animated: true)
        }
    }
    
    func presentStatus(_ controller: UIAlertController) {
        self.present(controller, animated: true) {
            NSLog("calibrationstatus shown")
        }
    }
}




private extension UIAlertController {
    
    convenience init(cgmDeletionHandler handler: @escaping () -> Void) {
        self.init(
            title: nil,
            message: NSLocalizedString("Are you sure you want to delete this CGM?", comment: "Confirmation message for deleting a CGM"),
            preferredStyle: .actionSheet
        )
        
        addAction(UIAlertAction(
            title: NSLocalizedString("Delete CGM", comment: "Button title to delete CGM"),
            style: .destructive,
            handler: { (_) in
                handler()
        }
        ))
        
        let cancel = NSLocalizedString("Cancel", comment: "The title of the cancel action in an action sheet")
        addAction(UIAlertAction(title: cancel, style: .cancel, handler: nil))
    }
    convenience init(calibrateHandler handler: @escaping () -> Void) {
        self.init(
            title: nil,
            message: NSLocalizedString("Are you sure you want to recalibrate this sensor?", comment: "Confirmation message for recalibrate sensor"),
            preferredStyle: .actionSheet
        )
        
        addAction(UIAlertAction(
            title: NSLocalizedString("Recalibrate", comment: "Button title to recalibrate"),
            style: .destructive,
            handler: { (_) in
                handler()
        }
        ))
        
        let cancel = NSLocalizedString("Cancel", comment: "The title of the cancel action in an action sheet")
        addAction(UIAlertAction(title: cancel, style: .cancel, handler: nil))
    }
}
