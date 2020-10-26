//
//  UserActivityPersisting.swift
//  DuckDuckGo
//
//  Created by Meir Radnovich on 8 Heshvan 5781.
//  Copyright © 5781 DuckDuckGo. All rights reserved.
//

import Foundation

public protocol UserActivityPersisting {
    func persist(activity: NSUserActivity)
}
