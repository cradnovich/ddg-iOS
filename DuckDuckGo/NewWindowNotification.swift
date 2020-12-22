//
//  NewWindowNotification.swift
//  DuckDuckGo
//
//  Copyright © 5781 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation

class NewWindowNotification {
    public class Observer {

        private let observer: NSObjectProtocol

        init(observer: NSObjectProtocol) {
            self.observer = observer
        }

        func remove() {
            NotificationCenter.default.removeObserver(observer)
        }

    }
    
    private static let tabUIDUserInfo = "uid"

    // Change this when it becomes possible to open a new window with a flock of tabs
    class func postNewWindowNotification(tabUID: String) {
        NotificationCenter.default.post(name: .newWindow, object: nil, userInfo: [tabUIDUserInfo: tabUID])
    }
    
    class func addObserver(handler: @escaping (String) -> Void) -> Observer {
        let observer = NotificationCenter.default.addObserver(forName: .newWindow, object: nil, queue: nil) { notification in
            guard let tabUid = notification.userInfo?[tabUIDUserInfo] as? String else { return }
            handler(tabUid)
        }

        return Observer(observer: observer)
    }
}

fileprivate extension NSNotification.Name {
    static let newWindow: NSNotification.Name = Notification.Name(rawValue: "com.duckduckgo.notification.newWindow")
}
