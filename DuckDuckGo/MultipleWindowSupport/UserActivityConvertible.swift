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
    static func restore(from userActivity: NSUserActivity) -> Self?
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
}
