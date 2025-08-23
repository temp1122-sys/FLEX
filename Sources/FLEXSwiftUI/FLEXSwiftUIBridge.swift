//
//  FLEXSwiftUIBridge.swift
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

import SwiftUI
import Foundation

/// Bridge class to enable enhanced SwiftUI introspection from Swift code
@objc public class FLEXSwiftUIBridge: NSObject {
    
    /// Singleton instance
    @objc public static let shared = FLEXSwiftUIBridge()
    
    private override init() {
        super.init()
        registerWithFLEX()
    }
    
    /// Registers this bridge with FLEX for enhanced SwiftUI support
    private func registerWithFLEX() {
        // Use reflection to call the FLEX registration method
        if let flexSwiftUIClass = NSClassFromString("FLEXSwiftUISupport") as? NSObject.Type {
            let selector = NSSelectorFromString("registerSwiftBridge:")
            if flexSwiftUIClass.responds(to: selector) {
                _ = flexSwiftUIClass.perform(selector, with: self)
            }
        }
    }
    
    // MARK: - Enhanced Description Methods
    
    /// Provides enhanced description for SwiftUI views
    @objc public func enhancedDescription(forSwiftUIView view: Any) -> String? {
        return enhancedDescriptionForSwiftUIView(view)
    }
    
    /// Extracts view hierarchy from SwiftUI views
    @objc public func extractViewHierarchy(fromSwiftUIView view: Any) -> [String: Any]? {
        return extractViewHierarchyFromSwiftUIView(view)
    }
    
    /// Discovers UIKit views from SwiftUI views
    @objc public func discoverUIKitViews(fromSwiftUIView view: Any) -> [UIView]? {
        return discoverUIKitViewsFromSwiftUIView(view)
    }
    
    /// Checks if a UIView is SwiftUI-backed
    @objc public func isSwiftUIBackedView(_ view: UIView) -> Bool {
        return isSwiftUIBacked(view: view)
    }
    
    // MARK: - SwiftUI Introspection Implementation
    
    private func enhancedDescriptionForSwiftUIView(_ view: Any) -> String? {
        let mirror = Mirror(reflecting: view)
        let typeName = String(describing: type(of: view))
        
        var description = simplifySwiftUITypeName(typeName)
        var details: [String] = []
        
        // Extract common SwiftUI view properties
        for child in mirror.children {
            if let label = child.label {
                let value = extractValueDescription(child.value)
                details.append("\(label): \(value)")
            }
        }
        
        // Add state information
        if let stateInfo = extractStateInformation(from: view) {
            details.append("state: \(stateInfo)")
        }
        
        // Add modifier information
        if let modifierInfo = extractModifierInformation(from: view) {
            details.append("modifiers: \(modifierInfo)")
        }
        
        if !details.isEmpty {
            description += " (\(details.joined(separator: ", ")))"
        }
        
        return description
    }
    
    private func extractViewHierarchyFromSwiftUIView(_ view: Any) -> [String: Any]? {
        let mirror = Mirror(reflecting: view)
        let typeName = String(describing: type(of: view))
        
        var hierarchy: [String: Any] = [
            "type": typeName,
            "readableName": simplifySwiftUITypeName(typeName),
            "description": enhancedDescriptionForSwiftUIView(view) ?? typeName
        ]
        
        // Extract child views
        var children: [[String: Any]] = []
        
        for child in mirror.children {
            if isSwiftUIView(child.value) {
                if let childHierarchy = extractViewHierarchyFromSwiftUIView(child.value) {
                    children.append(childHierarchy)
                }
            } else if let childViews = extractChildViews(from: child.value) {
                for childView in childViews {
                    if let childHierarchy = extractViewHierarchyFromSwiftUIView(childView) {
                        children.append(childHierarchy)
                    }
                }
            }
        }
        
        if !children.isEmpty {
            hierarchy["children"] = children
        }
        
        return hierarchy
    }
    
    private func discoverUIKitViewsFromSwiftUIView(_ view: Any) -> [UIView]? {
        var uiViews: [UIView] = []
        
        // Look for UIViewRepresentable and UIViewControllerRepresentable
        // Note: We can't directly instantiate representable contexts, so we'll use a different approach
        if let representableView = view as? UIView, 
           NSStringFromClass(type(of: representableView)).contains("UIHostingView") {
            uiViews.append(representableView)
        }
        
        // Recursively search in child views
        let mirror = Mirror(reflecting: view)
        for child in mirror.children {
            if let childUIViews = discoverUIKitViewsFromSwiftUIView(child.value) {
                uiViews.append(contentsOf: childUIViews)
            }
        }
        
        return uiViews.isEmpty ? nil : uiViews
    }
    
    private func isSwiftUIBacked(view: UIView) -> Bool {
        let className = String(describing: type(of: view))
        
        // Common SwiftUI hosting view patterns
        let swiftUIPatterns = [
            "UIHostingView",
            "_UIHostingView",
            "SwiftUI",
            "HostingScrollView",
            "PlatformGroupContainer",
            "ListTableViewCell",
            "DisplayList"
        ]
        
        return swiftUIPatterns.contains { className.contains($0) }
    }
    
    // MARK: - Helper Methods
    
    private func isSwiftUIView(_ value: Any) -> Bool {
        let typeName = String(describing: type(of: value))
        return typeName.contains("SwiftUI") || isCommonSwiftUIType(typeName)
    }
    
    private func isCommonSwiftUIType(_ typeName: String) -> Bool {
        let commonTypes = [
            "Text", "Image", "Button", "VStack", "HStack", "ZStack",
            "List", "ScrollView", "NavigationView", "TabView", "Group",
            "ForEach", "ModifiedContent", "TupleView", "_ConditionalContent"
        ]
        
        return commonTypes.contains { typeName.contains($0) }
    }
    
    private func simplifySwiftUITypeName(_ typeName: String) -> String {
        // Remove module prefixes and simplify generic types
        var simplified = typeName
        
        // Remove SwiftUI module prefix
        if simplified.hasPrefix("SwiftUI.") {
            simplified = String(simplified.dropFirst(8))
        }
        
        // Simplify generic types
        if let angleIndex = simplified.firstIndex(of: "<") {
            simplified = String(simplified[..<angleIndex])
        }
        
        // Handle common SwiftUI internal types
        let mappings = [
            "ModifiedContent": "ModifiedView",
            "_ConditionalContent": "ConditionalView",
            "_ViewModifier_Content": "ViewModifier",
            "TupleView": "TupleView"
        ]
        
        for (pattern, replacement) in mappings {
            if simplified.contains(pattern) {
                return replacement
            }
        }
        
        return simplified
    }
    
    private func extractValueDescription(_ value: Any) -> String {
        let mirror = Mirror(reflecting: value)
        
        // Handle common SwiftUI types
        if let string = value as? String {
            return "\"\(string)\""
        }
        
        if let number = value as? any Numeric {
            return String(describing: number)
        }
        
        if let bool = value as? Bool {
            return bool ? "true" : "false"
        }
        
        // Handle optional types
        if mirror.displayStyle == .optional {
            if mirror.children.isEmpty {
                return "nil"
            } else {
                return extractValueDescription(mirror.children.first!.value)
            }
        }
        
        // Handle collections
        if mirror.displayStyle == .collection {
            return "[\(mirror.children.count) items]"
        }
        
        // Default description
        return String(describing: type(of: value))
    }
    
    private func extractStateInformation(from view: Any) -> String? {
        let mirror = Mirror(reflecting: view)
        var stateVars: [String] = []
        
        for child in mirror.children {
            guard let label = child.label else { continue }
            
            // Look for common SwiftUI state patterns
            if label.hasPrefix("_") || label.contains("state") || label.contains("binding") {
                let valueDesc = extractValueDescription(child.value)
                stateVars.append("\(label): \(valueDesc)")
            }
        }
        
        return stateVars.isEmpty ? nil : stateVars.joined(separator: ", ")
    }
    
    private func extractModifierInformation(from view: Any) -> String? {
        let typeName = String(describing: type(of: view))
        
        if typeName.contains("ModifiedContent") {
            let mirror = Mirror(reflecting: view)
            for child in mirror.children {
                if child.label == "modifier" {
                    let modifierType = String(describing: type(of: child.value))
                    return simplifySwiftUITypeName(modifierType)
                }
            }
        }
        
        return nil
    }
    
    private func extractChildViews(from value: Any) -> [Any]? {
        let mirror = Mirror(reflecting: value)
        
        // Handle common SwiftUI container types
        if mirror.displayStyle == .collection {
            return mirror.children.map { $0.value }
        }
        
        // Handle TupleView
        if String(describing: type(of: value)).contains("TupleView") {
            for child in mirror.children {
                if child.label == "value" {
                    let tupleMirror = Mirror(reflecting: child.value)
                    return tupleMirror.children.map { $0.value }
                }
            }
        }
        
        // Handle Group, VStack, HStack, ZStack
        for child in mirror.children {
            if child.label == "content" {
                if let childViews = extractChildViews(from: child.value) {
                    return childViews
                } else if isSwiftUIView(child.value) {
                    return [child.value]
                }
            }
        }
        
        return nil
    }
}

// MARK: - Public API Extensions

public extension FLEXSwiftUIBridge {
    
    /// Manually trigger FLEX inspection of a SwiftUI view
    @objc static func inspect(view: Any) {
        if let flexClass = NSClassFromString("FLEXManager") as? NSObject.Type {
            let sharedManagerSelector = NSSelectorFromString("sharedManager")
            if flexClass.responds(to: sharedManagerSelector) {
                let managerResult = flexClass.perform(sharedManagerSelector)
                if let managerObject = managerResult?.takeUnretainedValue() as? NSObject {
                    let selector = NSSelectorFromString("showExplorerForObject:")
                    if managerObject.responds(to: selector) {
                        _ = managerObject.perform(selector, with: view)
                    }
                }
            }
        }
    }
    
    /// Enable enhanced SwiftUI debugging
    @objc static func enableSwiftUIDebugging() {
        _ = FLEXSwiftUIBridge.shared
    }
    
    /// Get debug information about a SwiftUI view
    static func debugInfo(for view: Any) -> [String: Any] {
        let bridge = FLEXSwiftUIBridge.shared
        var info: [String: Any] = [:]
        
        info["enhancedDescription"] = bridge.enhancedDescriptionForSwiftUIView(view)
        info["viewHierarchy"] = bridge.extractViewHierarchyFromSwiftUIView(view)
        info["uiKitViews"] = bridge.discoverUIKitViewsFromSwiftUIView(view)
        info["typeName"] = String(describing: type(of: view))
        
        return info
    }
}