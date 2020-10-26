//
//  UserActivityConvertible.swift
//  Core
//
//  Created by Meir Radnovich on 15/10/2020.
//  Copyright © 2020 DuckDuckGo. All rights reserved.
//

import Foundation
import DictionaryCoding
import Core
import os.log

protocol UserActivityConvertible: Codable {
    static func restore(from userActivity: NSUserActivity) -> Self? // DISCUSS: Replace with initialiser?
    func userActivity(withType type: String) -> NSUserActivity
}

extension UserActivityConvertible {
    static func restore(from userActivity: NSUserActivity) -> Self? {
        guard let dictionary = userActivity.userInfo else {
            return nil
        }
        
        let decoder = DictionaryDecoder()
        
        do {
            let me = try decoder.decode(Self.self, from: dictionary)
            
            return me
        } catch {
            os_log("Error parsing %s from the scene: %s", log: generalLog, type: .debug, String(describing: Self.self), error.localizedDescription)
        }
        
        return nil
    }
    
    func userActivity(withType type: String) -> NSUserActivity {
        let activity = NSUserActivity(activityType: type)
        
        do {
            let encoder = DictionaryEncoder()
            
            let dict = try encoder.encode(self)
            
            activity.userInfo = dict
        } catch {
            os_log("Error encoding %s: %s", log: generalLog, type: .debug, String(describing: Self.self), error.localizedDescription)
        }
        
        return activity
    }
}

fileprivate struct WrappedArray<C>: UserActivityConvertible where C: Collection & Codable, C.Element: Codable {
    let data: C
}

extension Array: UserActivityConvertible where Element: Codable {
    static func restore(from userActivity: NSUserActivity) -> Self? {
        guard let wrapped = WrappedArray<Self>.restore(from: userActivity) else {
            return nil
        }
        
        return wrapped.data
    }
    
    func userActivity(withType type: String) -> NSUserActivity {
        let wrapped = WrappedArray(data: self)
        
        return wrapped.userActivity(withType: type)
    }
}
