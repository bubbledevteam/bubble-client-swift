//
//  NotificationHelper.swift
//  BubbleClient
//
//  Created by Bjørn Inge Berg on 30/05/2019.
//  Copyright © 2019 Mark Wilson. All rights reserved.
//

import Foundation
import UserNotifications
import HealthKit
import LoopKit
import AudioToolbox

class NotificationHelper {
    
    private enum Identifiers: String {
        case glucocoseNotifications = "no.bjorninge.Bubble.glucose-notification"
        case noSensorDetected = "no.bjorninge.Bubble.nosensordetected-notification"
        case bluetoothDisconnect = "no.bjorninge.Bubble.bluetoothdisconnect-notification"
        case sensorChange = "no.bjorninge.Bubble.sensorchange-notification"
        case invalidSensor = "no.bjorninge.Bubble.invalidsensor-notification"
        case lowBattery = "no.bjorninge.Bubble.lowbattery-notification"
        case sensorExpire = "no.bjorninge.Bubble.SensorExpire-notification"
    }
    
    private static var glucoseFormatterMgdl: QuantityFormatter = {
        let formatter = QuantityFormatter()
        formatter.setPreferredNumberFormatter(for: HKUnit.milligramsPerDeciliter)
        return formatter
    }()
    
    private static var glucoseFormatterMmol: QuantityFormatter = {
        let formatter = QuantityFormatter()
        formatter.setPreferredNumberFormatter(for: HKUnit.millimolesPerLiter)
        return formatter
    }()
    
    public static func vibrateIfNeeded(count: Int = 3) {
        if UserDefaults.standard.mmGlucoseAlarmsVibrate {
            vibrate(count: count)
        }
    }
    private static func vibrate(count: Int) {
        guard count >= 0 else {
            return
        }
        
        AudioServicesPlaySystemSoundWithCompletion(kSystemSoundID_Vibrate) {
            vibrate(count: count - 1)
        }
    }
    
    
    static func ensureCanSendNotification(_ completion: @escaping (_ canSend: Bool) -> Void ) -> Void{
        completion(false)
//        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
//            if #available(iOSApplicationExtension 12.0, *) {
//                guard (settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional) else {
//                    NSLog("dabear:: ensureCanSendNotification failed, authorization denied")
//                    completion(false)
//                    return
//                    
//                }
//            } else {
//                // Fallback on earlier versions
//                guard (settings.authorizationStatus == .authorized ) else {
//                    NSLog("dabear:: ensureCanSendNotification failed, authorization denied")
//                    completion(false)
//                    return
//                    
//                }
//            }
//            NSLog("dabear:: sending notification was allowed")
//            completion(true)
//        }
    }
    
    
    private static var glucoseNotifyCalledCount = 0
    public static func sendGlucoseNotitifcationIfNeeded(glucose: GlucoseData, oldValue: GlucoseData?){
        glucoseNotifyCalledCount &+= 1
        
        
        let shouldSendGlucoseAlternatingTimes = glucoseNotifyCalledCount != 0 && UserDefaults.standard.mmNotifyEveryXTimes != 0
        
        let shouldSend = UserDefaults.standard.mmAlwaysDisplayGlucose || (shouldSendGlucoseAlternatingTimes && glucoseNotifyCalledCount % UserDefaults.standard.mmNotifyEveryXTimes == 0)
        
        let schedules = UserDefaults.standard.glucoseSchedules
        
        
        let alarm = schedules?.getActiveAlarms(glucose.glucoseLevelRaw) ?? GlucoseScheduleAlarmResult.none
        let isSnoozed = GlucoseScheduleList.isSnoozed()
        
        NSLog("dabear:: glucose alarmtype is \(alarm)")
        // We always send glucose notifications when alarm is active,
        // even if glucose notifications are disabled in the UI
        
        if shouldSend || alarm.isAlarming() {
            sendGlucoseNotitifcation(glucose: glucose, oldValue: oldValue, alarm: alarm, isSnoozed: isSnoozed)
        } else {
            NSLog("dabear:: not sending glucose, shouldSend and alarmIsActive was false")
            return
        }
        
    }
    
    
    
    
    static private func sendGlucoseNotitifcation(glucose: GlucoseData, oldValue: GlucoseData?, alarm : GlucoseScheduleAlarmResult = .none, isSnoozed: Bool = false){
        
        
        guard let glucoseUnit = UserDefaults.standard.mmGlucoseUnit, glucoseUnit == HKUnit.milligramsPerDeciliter || glucoseUnit == HKUnit.millimolesPerLiter else {
            NSLog("dabear:: glucose unit was not recognized, aborting notification")
            return
        }
        
        // TODO: handle alarm
        
        ensureCanSendNotification { (ensured) in
            
            guard (ensured) else {
                NSLog("dabear:: not sending sending glucose notification")
                return
            }
            NSLog("dabear:: sending glucose notification")
            
            
            guard glucoseUnit == HKUnit.milligramsPerDeciliter || glucoseUnit == HKUnit.millimolesPerLiter else {
                NSLog("dabear:: glucose unit was not recognized, aborting notification")
                return
            }
            
            let formatter = (glucoseUnit == HKUnit.milligramsPerDeciliter ? glucoseFormatterMgdl : glucoseFormatterMmol)
            
            guard let formatted = formatter.string(from: glucose.quantity, for: glucoseUnit) else {
                NSLog("dabear:: glucose unit formatter unsuccessful, aborting notification")
                return
            }
            let content = UNMutableNotificationContent()
            
            switch alarm {
            case .none:
                content.title = "New Reading \(formatted)"
            case .low:
                if isSnoozed {
                     content.title = "LOWALERT (Snoozed) \(formatted)"
                } else {
                    content.title = "LOWALERT \(formatted)"
                    content.sound = .default
                    vibrateIfNeeded()
                }
                
            case .high:
            
                if isSnoozed {
                    content.title = "HIGHALERT (Snoozed)! \(formatted)"
                } else {
                    content.title = "HIGHALERT! \(formatted)"
                    content.sound = .default
                    vibrateIfNeeded()
                    
                }
                
            }
            
            content.body = "Glucose: \(formatted)"
            
           
            
            if let oldValue = oldValue {
                
                
                //these are just calculations so I can use the convenience of the glucoseformatter
                var diff = glucose.glucoseLevelRaw - oldValue.glucoseLevelRaw
                
                if diff == 0 {
                    content.body += ", + 0"
                } else {
                    let sign = diff < 0 ? "-" : "+"
                    diff = abs(diff)
                    
                    let asObj = LibreGlucose(unsmoothedGlucose: diff, glucoseDouble: diff, trend: 0, timestamp: Date(), collector: nil)
                    if let formattedDiff = formatter.string(from: asObj.quantity, for: glucoseUnit) {
                        content.body += ", " + sign + formattedDiff
                    }
                }
        
                
            }
            
            if let trend = glucose.trendType?.localizedDescription {
                content.body += ", \(trend)"
            }
            
            let center = UNUserNotificationCenter.current()
            //content.sound = UNNotificationSound.
            let request = UNNotificationRequest(identifier: Identifiers.glucocoseNotifications.rawValue, content: content, trigger: nil)
            
            // Required since ios12+ have started to cache/group notifications
            center.removeDeliveredNotifications(withIdentifiers: [Identifiers.glucocoseNotifications.rawValue])
            center.removePendingNotificationRequests(withIdentifiers: [Identifiers.glucocoseNotifications.rawValue])
            
            center.add(request) { (error) in
                if let error = error {
                    NSLog("dabear:: unable to add glucose notification: \(error.localizedDescription)")
                }
            }
            
        }
    }
    
    
    public static func sendSensorNotDetectedNotificationIfNeeded(noSensor: Bool) {
        guard UserDefaults.standard.mmAlertNoSensorDetected  && noSensor else {
            NSLog("not sending noSensorDetected notification")
            return
        }
        
        sendSensorNotDetectedNotification()
        
    }
    
    public static func sendBluetoothPowerOffNotification() {
        
        ensureCanSendNotification { (ensured) in
            
            guard (ensured) else {
                NSLog("dabear:: not sending noSensorDetected notification")
                return
            }
            NSLog("dabear:: sending noSensorDetected")
            
            let content = UNMutableNotificationContent()
            content.title = "Bluetooth Power Off"
            content.body = "Please turn on Bluetooth"
            
            let center = UNUserNotificationCenter.current()
            
            
            
            //content.sound = UNNotificationSound.
            let request = UNNotificationRequest(identifier: Identifiers.noSensorDetected.rawValue, content: content, trigger: nil)
            
            center.add(request) { (error) in
                if let error = error {
                    NSLog("dabear:: unable to add no sensordetected-notification: \(error.localizedDescription)")
                }
            }
            
        }
    }
    
    public static func sendDisconnectNotification() {
        
        ensureCanSendNotification { (ensured) in
            
            guard (ensured) else {
                NSLog("dabear:: not sending noSensorDetected notification")
                return
            }
            NSLog("dabear:: sending disconnectNotification")
            
            let content = UNMutableNotificationContent()
            content.title = "Bluetooth Disconnect"
            content.body = "Please connect the bubble"
            
            let center = UNUserNotificationCenter.current()
            
            
            
            //content.sound = UNNotificationSound.
            let request = UNNotificationRequest(identifier: Identifiers.bluetoothDisconnect.rawValue, content: content, trigger: nil)
            
            center.add(request) { (error) in
                if let error = error {
                    NSLog("dabear:: unable to add no sensordetected-notification: \(error.localizedDescription)")
                }
            }
            
        }
    }
    
    private static func sendSensorNotDetectedNotification() {
        
        ensureCanSendNotification { (ensured) in
            
            guard (ensured) else {
                NSLog("dabear:: not sending noSensorDetected notification")
                return
            }
            NSLog("dabear:: sending noSensorDetected")
          
            let content = UNMutableNotificationContent()
            content.title = "No Sensor Detected"
            content.body = "This might be an intermittent problem, but please check that your Bubble is tightly secured over your sensor"
            
            let center = UNUserNotificationCenter.current()
            
           
            
            //content.sound = UNNotificationSound.
            let request = UNNotificationRequest(identifier: Identifiers.noSensorDetected.rawValue, content: content, trigger: nil)
            
            center.add(request) { (error) in
                if let error = error {
                    NSLog("dabear:: unable to add no sensordetected-notification: \(error.localizedDescription)")
                }
            }
            
        }
    }
    
    
    
    public static func sendSensorChangeNotificationIfNeeded(hasChanged: Bool) {
        guard UserDefaults.standard.mmAlertNewSensorDetected && hasChanged else {
            NSLog("not sending sendSensorChange notification ")
            return
        }
        sendSensorChangeNotification()
        
    }
    
    private static func sendSensorChangeNotification() {
        ensureCanSendNotification { (ensured) in
            
            guard (ensured) else {
                NSLog("dabear:: not sending sensorChangeNotification notification")
                return
            }
            NSLog("dabear:: sending sensorChangeNotification")
            
            let content = UNMutableNotificationContent()
            content.title = "New Sensor Detected"
            content.body = "Please wait up to 30 minutes before glucose readings are available!"
            
            
            
            
            //content.sound = UNNotificationSound.
            let request = UNNotificationRequest(identifier: Identifiers.sensorChange.rawValue, content: content, trigger: nil)
            
            UNUserNotificationCenter.current().add(request) { (error) in
                if let error = error {
                    NSLog("dabear:: unable to add sensorChange notification: \(error.localizedDescription)")
                }
            }
            
        }
    }
    
    
    
    
    public static func sendInvalidSensorNotificationIfNeeded(sensorData: SensorData) {
        let isValid = sensorData.isLikelyLibre1 && (sensorData.state == .starting || sensorData.state == .ready)
        
        guard UserDefaults.standard.mmAlertInvalidSensorDetected && !isValid else{
            NSLog("not sending invalidSensorDetected notification")
            return
        }
        
        sendInvalidSensorNotification(sensorData: sensorData)
    }
    
    
    
    
    
    private static func sendInvalidSensorNotification(sensorData: SensorData) {
        
        ensureCanSendNotification { (ensured) in
            
            guard (ensured) else {
                NSLog("dabear:: not sending InvalidSensorNotification notification")
                return
            }
        
            NSLog("dabear:: sending InvalidSensorNotification")
            
            let content = UNMutableNotificationContent()
            content.title = "Invalid Sensor Detected"
            
            if !sensorData.isLikelyLibre1 {
                content.body = "Detected sensor seems not to be a libre 1 sensor!"
            } else if !(sensorData.state == .starting || sensorData.state == .ready){
                content.body = "Detected sensor is invalid: \(sensorData.state.description)"
            }
           
            
            content.sound = .default
            
            //content.sound = UNNotificationSound.
            let request = UNNotificationRequest(identifier: Identifiers.invalidSensor.rawValue, content: content, trigger: nil)
            
            UNUserNotificationCenter.current().add(request) { (error) in
                if let error = error {
                    NSLog("dabear:: unable to add invalidsensor notification: \(error.localizedDescription)")
                }
            }
            
        }
    }
    
    
    
    private static var lastBatteryWarning : Date?
    public static func sendLowBatteryNotificationIfNeeded(device: Bubble) {
        
        guard UserDefaults.standard.mmAlertLowBatteryWarning else {
            NSLog("mmAlertLowBatteryWarning toggle was not enabled, not sending low notification")
            return
        }
        
        guard device.battery <= 30 else {
            NSLog("device battery is \(device.batteryString), not sending low notification")
            return
        }
        
        let now  = Date()
        //only once per mins minute
        let mins =  60.0 * 120
        if let earlier = lastBatteryWarning {
            let earlierplus = earlier.addingTimeInterval(mins)
            if earlierplus < now {
                sendLowBatteryNotification(batteryPercentage: device.batteryString)
                lastBatteryWarning = now
            } else {
                NSLog("Device battery is running low, but lastBatteryWarning Notification was sent less than 45 minutes ago, aborting. earlierplus: \(earlierplus), now: \(now)")
            }
        } else {
            sendLowBatteryNotification(batteryPercentage: device.batteryString)
            lastBatteryWarning = now
        }
        
        
    }
    
    private static func sendLowBatteryNotification(batteryPercentage: String){
        ensureCanSendNotification { (ensured) in
            
            guard (ensured) else {
                NSLog("dabear:: not sending LowBattery notification")
                return
            }
            NSLog("dabear:: sending LowBattery notification")
            
            
            
            
            let content = UNMutableNotificationContent()
            content.title = "Low Battery"
            content.body = "Battery is running low (\(batteryPercentage)), consider charging your Bubble device as soon as possible"
            
            content.sound = .default
            
            //content.sound = UNNotificationSound.
            let request = UNNotificationRequest(identifier: Identifiers.lowBattery.rawValue, content: content, trigger: nil)
            
            UNUserNotificationCenter.current().add(request) { (error) in
                if let error = error {
                    NSLog("dabear:: unable to add lowbattery notification: \(error.localizedDescription)")
                }
            }
            
        }
    }
    
    
    private static var lastSensorExpireAlert : Date?
    public static func sendSensorExpireAlertIfNeeded(sensorData: SensorData) {
        
        guard UserDefaults.standard.mmAlertWillSoonExpire else {
            NSLog("mmAlertWillSoonExpire toggle was not enabled, not sending expiresoon alarm")
            return
        }
        
        guard sensorData.minutesSinceStart >= 19440 else {
            NSLog("sensor start was less than 13,5 days in the past, not sending notification: \(sensorData.minutesSinceStart) minutes / \(sensorData.humanReadableSensorAge)")
            return
        }
        
       
        let now  = Date()
        //only once per 6 hours
        let min45 = 60.0  * 60 * 6
        if let earlier = lastSensorExpireAlert {
            if earlier.addingTimeInterval(min45) < now {
                sendSensorExpireAlert(sensorData: sensorData)
                lastSensorExpireAlert = now
            } else {
                NSLog("Sensor is soon expiring, but lastSensorExpireAlert was sent less than 6 hours ago, so aborting")
            }
        } else {
            sendSensorExpireAlert(sensorData: sensorData)
            lastSensorExpireAlert = now
        }
        
        
    }
    
    private static func sendSensorExpireAlert(sensorData: SensorData){
        
        ensureCanSendNotification { (ensured) in
            
            guard (ensured) else {
                NSLog("dabear:: not sending SensorExpireAlert notification")
                return
            }
            NSLog("dabear:: sending SensorExpireAlert notification")

            
            let content = UNMutableNotificationContent()
            content.title = "Sensor Ending Soon"
            content.body = "Current Sensor is Ending soon! Sensor Age: \(sensorData.humanReadableSensorAge)"
            
            //content.sound = .default
            
            //content.sound = UNNotificationSound.
            let request = UNNotificationRequest(identifier: Identifiers.sensorExpire.rawValue, content: content, trigger: nil)
            
            UNUserNotificationCenter.current().add(request) { (error) in
                if let error = error {
                    NSLog("dabear:: unable to add SensorExpire notification: \(error.localizedDescription)")
                }
            }
            
        }
    }
    
    
    
    
}
