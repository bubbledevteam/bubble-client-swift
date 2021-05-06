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

public protocol SubViewControllerWillDisappear: AnyObject {
    func onDisappear() -> Void
}

public class BubbleClientSettingsViewController: UITableViewController, SubViewControllerWillDisappear, CompletionNotifying { //, CompletionNotifying{
    //public weak var completionDelegate: CompletionDelegate?
    public var completionDelegate: CompletionDelegate?
    public func onDisappear() {
        // this is being called only from alarm, calibration and notifications ui
        // when they disappear
        // the idea is to reload certain gui elements that may have changed
        self.tableView.reloadData()
    }
    
    private let isDemoMode = false
    public var cgmManager: BubbleClientManager?
    
    private let displayGlucoseUnitObservable: DisplayGlucoseUnitObservable

    private var glucoseUnit: HKUnit {
        displayGlucoseUnitObservable.displayGlucoseUnit
    }

    public let allowsDeletion: Bool

    public init(cgmManager: BubbleClientManager, displayGlucoseUnitObservable: DisplayGlucoseUnitObservable, allowsDeletion: Bool) {
        self.cgmManager = cgmManager
        self.displayGlucoseUnitObservable = displayGlucoseUnitObservable
        
        //only override savedglucose unit if we haven't saved this locally before
        if UserDefaults.standard.mmGlucoseUnit == nil {
            UserDefaults.standard.mmGlucoseUnit = displayGlucoseUnitObservable.displayGlucoseUnit
        }
        
        self.allowsDeletion = allowsDeletion

        super.init(style: .grouped)
        self.cgmManager?.reloadData = {
            [weak self] in
            DispatchQueue.main.async {
                self?.tableView?.reloadData()
            }
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func tableView(_ tableView: UITableView, heightForRowAt index: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
        
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        cgmManager?.retrievePeripherals()
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()

        title = cgmManager?.localizedTitle

        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44

        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 55

        tableView.register(SettingsTableViewCell.self, forCellReuseIdentifier: SettingsTableViewCell.className)
        tableView.register(TextButtonTableViewCell.self, forCellReuseIdentifier: TextButtonTableViewCell.className)
        tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: SwitchTableViewCell.className)
        
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
    
    @objc private func dosingEnabledChanged(_ sender: UISwitch) {
        cgmManager?.useFilter = sender.isOn
        cgmManager?.delegateQueue.async {
            if let cgmManager = self.cgmManager {
                cgmManager.cgmManagerDelegate?
                .cgmManagerDidUpdateState(cgmManager)
            }
        }
        tableView.reloadData()
    }
    

    // MARK: - UITableViewDataSource

    private enum Section: Int {
        case device
        case latestReading
        case kalman
        case share
        case libre2Direct
        case delete
        static let count = 6
    }

    override public func numberOfSections(in tableView: UITableView) -> Int {
        return allowsDeletion ? Section.count : Section.count - 1
    }
    
    private enum Share: Int {
        case openApp
        case shareLog
        static let count = 2
    }

    private enum LatestReadingRow: Int {
        case glucose
        case date
        case trend
        static let count = 3
    }

    override public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .latestReading:
            return LatestReadingRow.count
        case .delete:
            return 1
        case .share:
            return Share.count
        case .device:
            return 1
        case .kalman:
            return 1
        case .libre2Direct:
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

    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section)! {
        case .device:
            let cell = tableView.dequeueReusableCell(withIdentifier: SettingsTableViewCell.className, for: indexPath) as! SettingsTableViewCell
            cell.textLabel?.text = "Bubble"
            if let cgmManager = cgmManager {
                cell.detailTextLabel?.text = "\(cgmManager.battery)  \(cgmManager.connectionState)"
            } else {
                cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
            }
            return cell
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

                if let date = glucose?.timeStamp {
                    cell.detailTextLabel?.text = dateFormatter.string(from: date)
                } else {
                    cell.detailTextLabel?.text = SettingsTableViewCell.NoValueString
                }
            case .trend:
                cell.textLabel?.text = NSLocalizedString("Trend", comment: "Title describing glucose trend")

                cell.detailTextLabel?.text = glucose?.trendType?.localizedDescription ?? SettingsTableViewCell.NoValueString
            }

            return cell
        case .delete:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath) as! TextButtonTableViewCell

            cell.textLabel?.text = NSLocalizedString("Delete CGM", comment: "Title text for the button to remove a CGM from Loop")
            cell.textLabel?.textAlignment = .center
            cell.tintColor = .delete
            cell.isEnabled = true
            return cell
        case .share:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath)
            switch Share(rawValue: indexPath.row)! {
            case .openApp:
                cell.textLabel?.text = LocalizedString("Open App", comment: "Button title to open CGM app")
            case .shareLog:
                cell.textLabel?.text = LocalizedString("Share Logs", comment: "Button title to Share Logs")
            }
            

            return cell
        case .kalman:
            let switchCell = tableView.dequeueReusableCell(withIdentifier: SwitchTableViewCell.className, for: indexPath) as! SwitchTableViewCell

            switchCell.selectionStyle = .none
            switchCell.switch?.isOn = cgmManager?.useFilter ?? false
            switchCell.textLabel?.text = NSLocalizedString("Use glucose filter", comment: "Switch title to Use glucose filter")

            switchCell.switch?.addTarget(self, action: #selector(dosingEnabledChanged(_:)), for: .valueChanged)

            return switchCell
            
        case .libre2Direct:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextButtonTableViewCell.className, for: indexPath)
            cell.textLabel?.text = LocalizedString("Libre2 Direct", comment: "Button title to open CGM app")
            return cell
        }
    }

    public override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .latestReading:
            return NSLocalizedString("Latest Reading", comment: "Section title for latest glucose reading")
        case .delete:
            return nil
        case .share:
            return nil
        case .device:
            return nil
        case .kalman:
            return NSLocalizedString("Use Kalman filter to smooth out a sensor noise.", comment: "Section title for Use glucose filter")
        case .libre2Direct:
            return nil
        }
    }

    public override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section)! {
        case .latestReading:
            tableView.deselectRow(at: indexPath, animated: true)
        case .delete:
            let confirmVC = UIAlertController(cgmDeletionHandler: {
                self.cgmManager?.disconnect()
                self.cgmManager?.notifyDelegateOfDeletion {
                    DispatchQueue.main.async {
                        self.complete()
                    }
                }
            })

            present(confirmVC, animated: true) {
                tableView.deselectRow(at: indexPath, animated: true)
            }
        case .share:
            switch Share(rawValue: indexPath.row)! {
            case .openApp:
                if let appURL = cgmManager?.appURL {
                    UIApplication.shared.open(appURL)
                }
            case .shareLog:
                
                guard let logs = cgmManager?.todayLogs, !logs.isEmpty else { return }
                let path: String = NSHomeDirectory() + "/Documents/loopLog.txt"
                let url = URL.init(fileURLWithPath: path)
                if let data = logs.data(using: .utf8) {
                    do {
                        try data.write(to: url)
                        let vc = UIActivityViewController.init(activityItems: [url], applicationActivities: nil)
                        present(vc, animated: true, completion: nil)
                    } catch {}
                }
            }
        case .device:
            tableView.deselectRow(at: indexPath, animated: true)
        case .kalman:
            return
        case .libre2Direct:
            cgmManager?.nfcManager.action(request: .readLibre2CalibrationInfo)
            break
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
    
    convenience init(cgmDisconnectHandler handler: @escaping () -> Void) {
        self.init(
            title: nil,
            message: NSLocalizedString("Are you sure you want to disconnect this CGM?", comment: "Confirmation message for disconnect a CGM"),
            preferredStyle: .actionSheet
        )
        
        addAction(UIAlertAction(
            title: NSLocalizedString("Disconnect", comment: "Button title to Disconnect CGM"),
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
