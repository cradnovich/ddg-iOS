//
//  TypeIdentifierError.swift
//  DuckDuckGo
//
//  Created by Meir Radnovich on 30 Tishri 5781.
//  Copyright © 5781 DuckDuckGo. All rights reserved.
//

import Foundation

public enum TypeIdentifierError: Error {
    case notSupported(expected: [String], actual: [String])
}
