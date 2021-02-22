//
//  DateExtensions.swift
//  BubbleClient
//
//  Created by Bjørn Inge Berg on 07/03/2019.
//  Copyright © 2019 Mark Wilson. All rights reserved.
//

import Foundation

public extension Date {
    func isBetween(_ date1: Date, and date2: Date) -> Bool {
        return date2 >= date1 && (date1 ... date2).contains(self)
    }
    
    func rounded(on amount: Int, _ component: Calendar.Component) -> Date {
        let cal = Calendar.current
        let value = cal.component(component, from: self)
        
        // Compute nearest multiple of amount:
        let roundedValue = lrint(Double(value) / Double(amount)) * amount
        let newDate = cal.date(byAdding: component, value: roundedValue - value, to: self)!
        
        return newDate.floorAllComponents(before: component)
    }
    
    func floorAllComponents(before component: Calendar.Component) -> Date {
        // All components to round ordered by length
        let components = [Calendar.Component.year, .month, .day, .hour, .minute, .second, .nanosecond]
        
        guard let index = components.firstIndex(of: component) else {
            fatalError("Wrong component")
        }
        
        let cal = Calendar.current
        var date = self
        
        components.suffix(from: index + 1).forEach { roundComponent in
            let value = cal.component(roundComponent, from: date) * -1
            date = cal.date(byAdding: roundComponent, value: value, to: date)!
        }
        
        return date
    }
    
    static var LocaleWantsAMPM : Bool{
        return DateFormatter.dateFormat(fromTemplate: "j", options:0, locale:NSLocale.current)!.contains("a")
    }
    
    /// returns Date in milliseconds as Int64
    func toMillisecondsAsInt64() -> Int64 {
        return Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    func localString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = .current
        dateFormatter.timeZone = .current
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return dateFormatter.string(from: self)
    }
    
    /// SwifterSwift: User’s current calendar.
    var calendar: Calendar {
        return Calendar(identifier: Calendar.current.identifier) // Workaround to segfault on corelibs foundation https://bugs.swift.org/browse/SR-10147
    }
    
    /// SwifterSwift: Date by adding multiples of calendar component.
    ///
    ///     let date = Date() // "Jan 12, 2017, 7:07 PM"
    ///     let date2 = date.adding(.minute, value: -10) // "Jan 12, 2017, 6:57 PM"
    ///     let date3 = date.adding(.day, value: 4) // "Jan 16, 2017, 7:07 PM"
    ///     let date4 = date.adding(.month, value: 2) // "Mar 12, 2017, 7:07 PM"
    ///     let date5 = date.adding(.year, value: 13) // "Jan 12, 2030, 7:07 PM"
    ///
    /// - Parameters:
    ///   - component: component type.
    ///   - value: multiples of components to add.
    /// - Returns: original date + multiples of component added.
    func adding(_ component: Calendar.Component, value: Int) -> Date {
        return calendar.date(byAdding: component, value: value, to: self)!
    }
}

extension DateComponents {
    func ToTimeString(wantsAMPM: Bool=Date.LocaleWantsAMPM) -> String {
        
        print("hour: \(String(describing: self.hour)) minute: \(String(describing: self.minute))")
        let date = Calendar.current.date(bySettingHour: self.hour ?? 0, minute: self.minute ?? 0, second: 0, of: Date())!
        
        
        let formatter = DateFormatter()
        formatter.dateStyle = DateFormatter.Style.long
        formatter.timeStyle = DateFormatter.Style.medium
        
        formatter.dateFormat = wantsAMPM ? "hh:mm a" : "HH:mm"
        return formatter.string(from: date)
        
    }
}

extension TimeInterval{
    
    func stringDaysFromTimeInterval() -> String {
        
        let aday = 86400.0 //in seconds
        let time = Double(self).magnitude
        
        let days = time / aday
        
        
        return days.twoDecimals
        
    }
}

extension Array where Element == DateInterval {
   
    // Check for intersection among the intervals in the given array and return
    // the interval if found.
    func intersect() -> DateInterval? {
        // Algorithm:
        // We will compare first two intervals.
        // If an intersection is found, we will save the resultant interval
        // and compare it with the next interval in the array.
        // If no intersection is found at any iteration
        // it means the intervals in the array are disjoint. Break the loop and return nil
        // Otherwise return the last intersection.
        
        var previous = self.first
        for (index, element) in self.enumerated() {
            if index == 0 {
                continue
            }
            
            previous = previous?.intersection(with: element)
            
            if previous == nil {
                break
            }
        }
        
        return previous
    }
}



