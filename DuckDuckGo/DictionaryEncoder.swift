//
//  DictionaryEncoder.swift
//  DuckDuckGo
//
//  Created by Meir Radnovich on 20 Tishri 5781.
//  Copyright © 5781 DuckDuckGo. All rights reserved.
//

import Foundation

typealias DictionaryEncoder = PropertyListEncoder

extension DictionaryEncoder {
    func dictify(data: Data) throws -> [AnyHashable:Any] {
        guard let d = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [AnyHashable:Any] else {
            return [:]
        }
        
        return d
    }
}

//class DictionaryEncoder : Encoder {
//    private let jsonEncoder = JSONEncoder()
//
//    var codingPath: [CodingKey] {
//        return jsonEncoder.codingPath
//    }
//
//    var userInfo: [CodingUserInfoKey : Any]
//
//    func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key : CodingKey {
//        <#code#>
//    }
//
//    func unkeyedContainer() -> UnkeyedEncodingContainer {
//        <#code#>
//    }
//
//    func singleValueContainer() -> SingleValueEncodingContainer {
//        <#code#>
//    }
//
//
//}
