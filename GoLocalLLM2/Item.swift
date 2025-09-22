//
//  Item.swift
//  Simple SwiftData model backing the legacy sample view; unused in chat UI.
//
//  Created by Brendan Quinn on 9/12/25.
//

import Foundation
import SwiftData

@Model
final class Item {
    // Timestamp captured when the record is created.
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
