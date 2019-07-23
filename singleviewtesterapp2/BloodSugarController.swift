//
//  TableViewController.swift
//
//  Created by Uwe Petersen on 01.02.16.
//  Copyright © 2016 Uwe Petersen. All rights reserved.
//

import Foundation

import UIKit
import CoreBluetooth
import CoreData
import UserNotifications
import os.log

/*
{
final class BloodSugarController: BubbleManagerDelegate {

    // MARK: - Properties
    
    static let bt_log = OSLog(subsystem: "com.LibreMonitor", category: "BloodSugarController")
    
    var BubbleManager: BubbleClient!

    
    /*@IBAction func doRefresh(_ sender: UIRefreshControl) {
        if let writeCharacteristic = BubbleManager.writeCharacteristic {
            BubbleManager.peripheral?.writeValue(Data.init(bytes: [0xD3, 0x01]), for: writeCharacteristic, type: .withResponse)
            BubbleManager.rxBuffer = Data()
            BubbleManager.peripheral?.writeValue(Data.init(bytes: [0xF0]), for: writeCharacteristic, type: .withResponse)
        }
        sender.endRefreshing()
        tableView.reloadData()
    }*/
    
    // MARK: - View Controller life ciycle
    
    init() {
        self.BubbleManager = BubbleClient()
        self.BubbleManager.delegate = self

        didWantToConnect()
    
    }
    
   

   
    @objc func didWantToConnect() {
        os_log("didTapConnectButton called. BubbleManager.state is %{public}@", log: BloodSugarController.bt_log, type: .default, String(describing: BubbleManager.state))
        
        switch (BubbleManager.state) {
        case .Unassigned:
            BubbleManager.scanForBubble()
        case .Scanning:
            break
        case .Connected, .Connecting, .Notifying:
            break
        case .Disconnected, .DisconnectingDueToButtonPress:
            BubbleManager.connect()
        }
    }
    
    
    @objc func didTapConnectButton() {
        os_log("didTapConnectButton called. BubbleManager.state is %{public}@", log: BloodSugarController.bt_log, type: .default, String(describing: BubbleManager.state))
        
        switch (BubbleManager.state) {
        case .Unassigned:
            BubbleManager.scanForBubble()
        case .Scanning:
            BubbleManager.centralManager.stopScan()
            BubbleManager.state = .Disconnected
        case .Connected, .Connecting, .Notifying:
            BubbleManager.disconnectManually()
        case .Disconnected, .DisconnectingDueToButtonPress:
            BubbleManager.connect()
        }
    }
    
    
    

    
    
    
//todo: can be used for metadata later
    /*
    func configureCell(_ cell: UITableViewCell, atIndexPath indexPath: IndexPath) {
        cell.backgroundColor = UIColor.white
        cell.detailTextLabel?.textColor = UIColor.black
        cell.accessoryType = .none
        
        switch Section(rawValue: (indexPath as NSIndexPath).section)! {
        case .connectionData:
            switch (indexPath as NSIndexPath).row {
            case 0:
                cell.textLabel?.text = "Bubble status"
                cell.detailTextLabel?.text = BubbleManager.state.rawValue
                cell.backgroundColor = colorForConnectionBubbleState()
            case 1:
                cell.textLabel?.text = "Last scan:"
                if let sensorData = sensorData {
                    cell.detailTextLabel?.text = "\(dateFormatter.string(from: sensorData.date as Date)), at \(timeFormatter.string(from: sensorData.date as Date))"
                    
                    if Date().timeIntervalSince(sensorData.date as Date) > 450.0 {
                        cell.backgroundColor = UIColor.red
                    }
                }
            case 2:
                cell.textLabel?.text = "Offset / Slope:"
                cell.detailTextLabel?.text = String(format: "%.0f mg/dl, %.4f", arguments: [UserDefaults.standard.glucoseOffset, UserDefaults.standard.glucoseSlope])
                cell.accessoryType = .disclosureIndicator
            default: break
            }
        case .generalData:
            switch (indexPath as NSIndexPath).row {
            case 0:
                cell.textLabel?.text = "Hard-/Firmware"
                if let Bubble = BubbleManager.Bubble, let responseState = BubbleManager.BubbleResponseState {
                    cell.detailTextLabel?.text = Bubble.hardware + "/" + Bubble.firmware + ", Response state: " + responseState.description
                } else {
                    cell.detailTextLabel?.text = nil
                }
            case 1:
                var crcString = String()
                var color = UIColor()
                if let sensorData = sensorData {
                    crcString.append(", crcs: \(sensorData.hasValidHeaderCRC), \(sensorData.hasValidBodyCRC), \(sensorData.hasValidFooterCRC)")
                    color = colorForSensorCRCs( (sensorData.hasValidCRCs ))
                } else {
                    crcString = ", nil"
                    color = UIColor.lightGray
                }
                cell.textLabel?.text = "Sensor SN"
                cell.detailTextLabel?.text = (sensorData?.serialNumber ?? "-") + crcString + " " // + " (" + sensor.prettyUid  + ")"
                cell.backgroundColor = color
            case 2:
                cell.textLabel?.text = "Battery"
                cell.detailTextLabel?.text = BubbleManager.Bubble?.batteryString ?? ""
                if let Bubble = BubbleManager.Bubble, Bubble.battery < 40 {
                    cell.backgroundColor = UIColor.orange
                }
            case 3:
                cell.textLabel?.text = "Blocks"
                if let sennsorData = sensorData {
                    cell.detailTextLabel?.text = "Trend: \(sennsorData.nextTrendBlock), history: \(sennsorData.nextHistoryBlock), minutes: \(sennsorData.minutesSinceStart)"
                }
            case 4:
                cell.textLabel?.text = "Glucose"
                
                if let trendMeasurements = trendMeasurements {
                    let currentGlucose = trendMeasurements[0].glucose
                    let longDelta = currentGlucose - trendMeasurements[15].glucose
                    let shortDelta = (currentGlucose - trendMeasurements[8].glucose) * 2.0 * 16.0/15.0
                    let longPrediction = currentGlucose + longDelta
                    let shortPrediction = currentGlucose + shortDelta
                    cell.detailTextLabel?.text = String(format: "%0.0f, Delta: %0.0f (%0.0f), Prognosis: %0.0f (%0.0f)", arguments: [currentGlucose, longDelta, shortDelta, longPrediction, shortPrediction])
                    if longPrediction < 70.0 || shortPrediction < 70.0 || longPrediction > 180.0 || shortPrediction > 180.0 || (abs(longDelta) > 30.0 && abs(shortDelta) > 30.0) {
                        cell.detailTextLabel?.textColor = UIColor.red
                    } else {
                        cell.detailTextLabel?.textColor = UIColor.black
                    }
                }

            case 5:
                cell.textLabel?.text = "Sensor started"
                if let sennsorData = sensorData {
                    let minutes = sennsorData.minutesSinceStart
                    let days = Int( Double(minutes) / 24.0 / 60.0 )
                    let hours = Int( Double(minutes) / 60.0 ) - days*24
                    let minutesRest = minutes - days*24*60 - hours*60
                    cell.detailTextLabel?.text = String(format: "%d day(s), %d hour(s) and %d minute(s) ago", arguments: [days, hours, minutesRest])
                    cell.backgroundColor = colorForSensorAge(days: days)
                }
            case 6:
                cell.textLabel?.text = "Sensor status"
                if let sennsorData = sensorData {
                    cell.detailTextLabel?.text = sennsorData.state.description
                    cell.backgroundColor = colorForSensorState(sensorState: sennsorData.state)
                } else {
                    cell.detailTextLabel?.text = "nil"
                }
            case 7:
                cell.textLabel?.text = "OOP Glucose"

                if let sensorData = sensorData {
                    if let oopCurrentValue = oopCurrentValue {
                        cell.detailTextLabel?.text = "\(oopCurrentValue.currentBg) mg/dl, time: \(oopCurrentValue.currentTime), trend: \(oopCurrentValue.currentTrend) at \(timeFormatter.string(from: sensorData.date))"
                    }
                    if let temperatureAlgorithmParameterSet = sensorData.temperatureAlgorithmParameterSet,
                        sensorData.footerCrc != UInt16(temperatureAlgorithmParameterSet.isValidForFooterWithReverseCRCs).byteSwapped {
                        cell.detailTextLabel?.text?.append(", but parameters do not match current sensor. Get new Parameters?")
                        cell.backgroundColor = UIColor.red
                    } else {
                        cell.backgroundColor = UIColor.white
                    }
                } else {
                    cell.detailTextLabel?.text = "-"
                }
                
            default:
                cell.textLabel?.text = "Something ..."
                cell.detailTextLabel?.text = "... didn't work"
            }
        case .graphHeader:
            break
        case .graph:
            break
            
        case .trendData:
            let index = (indexPath as NSIndexPath).row
            if let measurements = trendMeasurements, index < 16 {
                let timeAsString = timeFormatter.string(from: measurements[index].date as Date)
                let dateAsString = dateFormatter.string(from: measurements[index].date as Date)
                let rawString = String(format: "%0d, %0d", measurements[index].rawGlucose, measurements[index].rawTemperature)

                cell.textLabel?.text = String(format: "%0.1f mg/dl", measurements[index].glucose)
                cell.detailTextLabel?.text = "\(timeAsString), \(rawString), \(measurements[index].byteString), \(dateAsString), \(index)"
            }

        case .historyData:
            let index = (indexPath as NSIndexPath).row
            if let measurements = historyMeasurements, index < 32 {
                let timeAsString = timeFormatter.string(from: measurements[index].date as Date)
                let dateAsString = dateFormatter.string(from: measurements[index].date as Date)
                var rawString = String(format: "%0d, %0d, %0d, %d", measurements[index].rawGlucose, measurements[index].rawTemperature, measurements[index].counter, Int(measurements[index].temperatureAlgorithmGlucose))
                
                if let oopCurrentValue = self.oopCurrentValue, oopCurrentValue.historyValues.count == 32 {
                    let theIndex = oopCurrentValue.historyValues.count - 1 - index
                    let aString = String(format: ", oop: %0d, %0d, %0d", Int(round(oopCurrentValue.historyValues[theIndex].bg)), oopCurrentValue.historyValues[theIndex].time, oopCurrentValue.historyValues[theIndex].quality)
                    rawString.append(aString)
                }
                cell.textLabel?.text = String(format: "%0.1f mg/dl", measurements[index].glucose)
                cell.detailTextLabel?.text = "\(timeAsString), \(rawString), \(measurements[index].byteString), \(dateAsString), \(index)"
            }
        }
    }*/
   
   
    
    // MARK: BubbleManagerDelegate

    func BubbleManagerPeripheralStateChanged(_ state: BubbleManagerState) {
        os_log("MiaMiao manager peripheral state changed to %{public}@", log: BloodSugarController.bt_log, type: .default, String(describing: state.rawValue))
        
        //self.navigationItem.rightBarButtonItem?.title? = connectButtonTitleForBubbleState(state)
        
        /*switch state {
        case .Unassigned, .Connecting, .Connected, .Scanning, .DisconnectingDueToButtonPress, .Disconnected:
            //NotificationManager.applicationIconBadgeNumber(value: 0) // Data not accurate any more -> remove badge icon
            //NotificationManager.scheduleBluetoothDisconnectedNotification(wait: 450)
        case .Notifying:
            //NotificationManager.removePendingBluetoothDisconnectedNotification()
        }*/
        //tableView.reloadData()
    }
    
    func BubbleManagerDidUpdateSensorAndBubble(sensorData: SensorData, Bubble: Bubble) {
        
        
        
        if sensorData.hasValidCRCs {
            
            os_log("got sensordata with valid crcs")
           
                   
                    
            
           
        } else {
            os_log("dit not get sensordata with valid crcs")
        }
        
    }
    
    
    func BubbleManagerReceivedMessage(_ messageIdentifier: UInt16, txFlags: UInt8, payloadData: Data) {
        
        let packet = BubbleResponseState.init(rawValue: txFlags)!
        
        switch packet {
        case .newSensor:
            //invalidate any saved calibration parameters
            break
        case .noSensor:
            break
            //consider notifying user here that sensor is not found
        default:
            //we don't care about the rest!
            break
        }
        
        
     }
    
    
    
   

    
    
    
    
   
    
    
}


*/



