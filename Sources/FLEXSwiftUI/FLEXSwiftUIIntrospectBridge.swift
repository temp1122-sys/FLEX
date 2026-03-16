//
//  FLEXSwiftUIIntrospectBridge.swift
//  FLEX
//
//  Created by FLEX Team on SwiftUI Introspect integration.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

import Foundation
import UIKit
import SwiftUI
// import SwiftUIIntrospect - Disabled: Module not found in project

/// Bridge between FLEX and SwiftUI Introspect for enhanced SwiftUI debugging
@objc public class FLEXSwiftUIIntrospectBridge: NSObject {
    
    /// Shared instance for the bridge
    @objc public static let shared = FLEXSwiftUIIntrospectBridge()
    
    /// Initializes the SwiftUI integration - call this early in app launch
    @objc public static func setupFLEXSwiftUI() {
        // This will trigger the shared instance creation and registration
        _ = shared
    }
    
    private override init() {
        super.init()
        
        // Register this bridge with the Objective-C SwiftUI support
        registerWithFLEXSwiftUISupport()
    }
    
    /// Registers as Swift bridge callbacks with FLEXSwiftUISupport
    private func registerWithFLEXSwiftUISupport() {
        // Use runtime lookup to access the FLEXSwiftUISupport class
        guard let flexClass = NSClassFromString("FLEXSwiftUISupport") else {
            print("Warning: FLEXSwiftUISupport class not found")
            return
        }
        
        // Call the simplified registration method
        let selector = NSSelectorFromString("registerSwiftBridge:")
        if flexClass.responds(to: selector) {
            let _ = flexClass.perform(selector, with: self, afterDelay: 0)
        }
    }
    
    /// Extracts a readable type name from mangled SwiftUI type names
    private func readableTypeName(from mangledName: String) -> String {
        // Handle common SwiftUI mangled names
        if mangledName.hasPrefix("_Tt") {
            if mangledName.hasPrefix("_TtCC7SwiftUI") {
                return "SwiftUI View Container"
            } else if mangledName.hasPrefix("_TtC") {
                return "SwiftUI View"
            }
        }
        
        // Handle generic SwiftUI types
        if mangledName.contains("List") {
            return "SwiftUI List"
        } else if mangledName.contains("Button") {
            return "SwiftUI Button"
        } else if mangledName.contains("Text") {
            return "SwiftUI Text"
        } else if mangledName.contains("Image") {
            return "SwiftUI Image"
        } else if mangledName.contains("Stack") {
            return "SwiftUI Stack"
        } else if mangledName.contains("ScrollView") {
            return "SwiftUI ScrollView"
        } else if mangledName.contains("LazyVStack") {
            return "SwiftUI LazyVStack"
        } else if mangledName.contains("LazyHStack") {
            return "SwiftUI LazyHStack"
        }
        
        return mangledName.replacingOccurrences(of: "_Tt", with: "")
            .replacingOccurrences(of: "SwiftUI.", with: "SwiftUI ")
    }
    
    /// Provides a readable description for SwiftUI views without SwiftUIIntrospect
    /// - Parameter swiftUIView: The SwiftUI view to describe
    /// - Returns: Description including view type
    @objc public func enhancedDescription(for swiftUIView: Any) -> String {
        let baseDescription = String(describing: swiftUIView)
        let readableName = readableTypeName(from: baseDescription)
        
        return "SwiftUI: \(readableName)"
    }
    
    /// Objective-C bridge method for enhanced descriptions
    @objc public func enhancedDescriptionForSwiftUIView(_ swiftUIView: Any) -> String? {
        return enhancedDescription(for: swiftUIView)
    }
}
