//
//  Tab.swift
//  DuckDuckGo
//
//  Copyright © 2017 DuckDuckGo. All rights reserved.
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

import Core
import DictionaryCoding

protocol TabObserver: class {
 
    func didChange(tab: Tab)
    
}

public class Tab: NSObject, NSCoding, Codable, UserActivityConvertible {
    
    static let OpenTabActivityType = "com.duckduckgo.openTabInNewWindow"
    
    struct WeaklyHeldTabObserver {
        weak var observer: TabObserver?
    }
    
    struct NSCodingKeys {
        static let uid = "uid"
        static let link = "link"
        static let viewed = "viewed"
        static let desktop = "desktop"
    }
    
    enum CodingKeys: String, CodingKey {
        case uid, link, viewed, isDesktop = "desktop"
    }

    private var observersHolder = [WeaklyHeldTabObserver]()
    
    let uid: String
    
    var isDesktop: Bool = false {
        didSet {
            notifyObservers()
        }
    }
    
    var link: Link? {
        didSet {
            notifyObservers()
        }
    }
    
    var viewed: Bool = true {
        didSet {
            notifyObservers()
        }
    }
    
    var openTabUserActivity: NSUserActivity {
        let ua = userActivity(withType: Tab.OpenTabActivityType)
        ua.title = link?.displayTitle ?? UserText.homeTabTitle
        
        return ua
    }

    public required init(uid: String? = nil,
                         link: Link? = nil,
                         viewed: Bool = true,
                         desktop: Bool = AppWidthObserver.shared.isLargeWidth) {
        self.uid = uid ?? UUID().uuidString
        self.link = link
        self.viewed = viewed
        self.isDesktop = desktop
    }

    public convenience required init?(coder decoder: NSCoder) {
        let uid = decoder.decodeObject(forKey: NSCodingKeys.uid) as? String
        let link = decoder.decodeObject(forKey: NSCodingKeys.link) as? Link
        let viewed = decoder.containsValue(forKey: NSCodingKeys.viewed) ? decoder.decodeBool(forKey: NSCodingKeys.viewed) : true
        let desktop = decoder.containsValue(forKey: NSCodingKeys.desktop) ? decoder.decodeBool(forKey: NSCodingKeys.desktop) : false
        self.init(uid: uid, link: link, viewed: viewed, desktop: desktop)
    }

    public func encode(with coder: NSCoder) {
        coder.encode(uid, forKey: NSCodingKeys.uid)
        coder.encode(link, forKey: NSCodingKeys.link)
        coder.encode(viewed, forKey: NSCodingKeys.viewed)
        coder.encode(isDesktop, forKey: NSCodingKeys.desktop)
    }

    public override func isEqual(_ other: Any?) -> Bool {
        guard let other = other as? Tab else { return false }
        return link == other.link
    }
    
    func toggleDesktopMode() {
        isDesktop = !isDesktop
    }
    
    func didUpdatePreview() {
        notifyObservers()
    }
    
    func didUpdateFavicon() {
        notifyObservers()
    }
    
    func addObserver(_ observer: TabObserver) {
        guard indexOf(observer) == nil else { return }
        observersHolder.append(WeaklyHeldTabObserver(observer: observer))
    }
    
    func removeObserver(_ observer: TabObserver) {
        guard let index = indexOf(observer) else { return }
        observersHolder.remove(at: index)
    }
    
    private func indexOf(_ observer: TabObserver) -> Int? {
        pruneHolders()
        return observersHolder.firstIndex(where: { $0.observer === observer })
    }
    
    private func notifyObservers() {
        observersHolder.forEach { $0.observer?.didChange(tab: self) }
        pruneHolders()
    }

    private func pruneHolders() {
        observersHolder = observersHolder.filter { $0.observer != nil }
    }

}

extension Tab: NSItemProviderWriting {
    public static var writableTypeIdentifiersForItemProvider: [String] {
        [TypeIdentifier.duckTab]
    }
    
    public static func itemProviderVisibilityForRepresentation(withTypeIdentifier typeIdentifier: String) -> NSItemProviderRepresentationVisibility {
        .all
    }
    
    public func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        
        let progress = Progress(totalUnitCount: 100)
        
        do {
            let encoder = JSONEncoder()
            #if DEBUG
            encoder.outputFormatting = .prettyPrinted
            #endif
            let data = try encoder.encode(self)
            #if DEBUG
            if let json = String(data: data, encoding: String.Encoding.utf8) {
                Swift.debugPrint(json)
            }
            #endif
            progress.completedUnitCount = 100
            completionHandler(data, nil)
        } catch {
            
            completionHandler(nil, error)
        }
        
        return progress
    }
}

extension Tab: NSItemProviderReading {
    public static var readableTypeIdentifiersForItemProvider: [String] {
        [TypeIdentifier.duckTab, TypeIdentifier.url]
    }
    
    public static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
        switch typeIdentifier {
        case TypeIdentifier.duckTab:
            let decoder = JSONDecoder()
            let tab = try decoder.decode(Self.self, from: data)
            return tab
        case TypeIdentifier.url:
            let decoder = PropertyListDecoder()
            let u = try decoder.decode(URL.self, from: data)
            let link = Link(title: nil, url: u)
            return Self(link: link)
        default:
            throw TypeIdentifierError.notSupported(expected: readableTypeIdentifiersForItemProvider, actual: [typeIdentifier])
        }
    }
}
