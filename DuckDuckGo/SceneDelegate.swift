//
//  SceneDelegate.swift
//  DuckDuckGo
//
//  Created by Meir Radnovich on 17 Tishri 5781.
//  Copyright © 5781 DuckDuckGo. All rights reserved.
//

import UIKit

class SceneDelegate : UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    @available(iOS 13.0, *)
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        return scene.userActivity
    }
    
    @available(iOS 13.0, *)
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let userActivity = connectionOptions.userActivities.first ?? session.stateRestorationActivity {
            Swift.debugPrint("Restoring \(String(describing: userActivity.userInfo))")
            window?.windowScene?.userActivity = userActivity
        }
        // The `window` property will automatically be loaded with the storyboard's initial view controller.
        
    }
}
