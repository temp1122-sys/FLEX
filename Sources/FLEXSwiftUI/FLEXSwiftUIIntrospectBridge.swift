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
import SwiftUIIntrospect

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
    
    /// Registers the Swift bridge callbacks with the Objective-C FLEXSwiftUISupport
    private func registerWithFLEXSwiftUISupport() {
        // Use runtime lookup to access the FLEXSwiftUISupport class
        guard let flexClass = NSClassFromString("FLEXSwiftUISupport") else {
            print("Warning: FLEXSwiftUISupport class not found")
            return
        }
        
        // Call the simplified registration method\n        let selector = NSSelectorFromString(\"registerSwiftBridge:\")\n        if flexClass.responds(to: selector) {\n            let _ = flexClass.perform(selector, with: self)\n        }
    }
    
    // MARK: - SwiftUI View Discovery
    
    /// Discovers underlying UIKit views from SwiftUI views using SwiftUI Introspect
    /// - Parameter swiftUIView: The SwiftUI view to introspect
    /// - Returns: Array of discovered UIKit views
    @objc public func discoverUIKitViews(from swiftUIView: Any) -> [UIView] {
        var discoveredViews: [UIView] = []
        
        // Try to extract UIKit views using reflection and introspection
        if let mirror = Mirror(reflecting: swiftUIView) as Mirror? {
            discoveredViews.append(contentsOf: extractUIKitViews(from: mirror))
        }
        
        return discoveredViews
    }
    
    /// Provides a readable description for SwiftUI views with underlying UIKit information
    /// - Parameter swiftUIView: The SwiftUI view to describe
    /// - Returns: Enhanced description including UIKit information
    @objc public func enhancedDescription(for swiftUIView: Any) -> String {
        let baseDescription = String(describing: swiftUIView)
        let readableName = readableTypeName(from: baseDescription)
        let uikitViews = discoverUIKitViews(from: swiftUIView)
        
        var description = "SwiftUI: \(readableName)"
        
        if !uikitViews.isEmpty {
            description += "\n├─ Underlying UIKit Views:"
            for (index, view) in uikitViews.enumerated() {
                let isLast = index == uikitViews.count - 1
                let prefix = isLast ? "└─" : "├─"
                description += "\n│  \(prefix) \(String(describing: type(of: view)))"
            }
        }
        
        return description
    }
    
    /// Extracts SwiftUI view hierarchy with UIKit backing views
    /// - Parameter rootView: The root SwiftUI view
    /// - Returns: Dictionary representing the view hierarchy
    @objc public func extractViewHierarchy(from rootView: Any) -> [String: Any] {
        var hierarchy: [String: Any] = [:]
        
        // Basic view information
        hierarchy["type"] = String(describing: type(of: rootView))
        hierarchy["readableType"] = readableTypeName(from: String(describing: type(of: rootView)))
        hierarchy["description"] = String(describing: rootView)
        
        // UIKit backing views
        let uikitViews = discoverUIKitViews(from: rootView)
        if !uikitViews.isEmpty {
            hierarchy["uikitViews"] = uikitViews.map { view in
                return [
                    "type": String(describing: type(of: view)),
                    "frame": NSCoder.string(for: view.frame),
                    "bounds": NSCoder.string(for: view.bounds),
                    "backgroundColor": view.backgroundColor?.description ?? "nil",
                    "isHidden": view.isHidden,
                    "alpha": view.alpha
                ]
            }
        }
        
        // Extract child views if possible
        if let mirror = Mirror(reflecting: rootView) as Mirror? {
            hierarchy["children"] = extractChildViews(from: mirror)
        }
        
        return hierarchy
    }
    
    // MARK: - Objective-C Bridge Methods
    
    /// Objective-C bridge method for enhanced descriptions
    @objc public func enhancedDescriptionForSwiftUIView(_ swiftUIView: Any) -> String? {
        return enhancedDescription(for: swiftUIView)
    }
    
    /// Objective-C bridge method for view hierarchy extraction
    @objc public func extractViewHierarchyFromSwiftUIView(_ swiftUIView: Any) -> [String: Any]? {
        return extractViewHierarchy(from: swiftUIView)
    }
    
    /// Objective-C bridge method for UIKit view discovery
    @objc public func discoverUIKitViewsFromSwiftUIView(_ swiftUIView: Any) -> [UIView]? {
        return discoverUIKitViews(from: swiftUIView)
    }
    
    /// Objective-C bridge method for SwiftUI-backed view detection
    @objc public func isSwiftUIBackedViewObjC(_ view: UIView) -> NSNumber {
        return NSNumber(value: isSwiftUIBackedView(view))
    }
    
    // MARK: - Private Helper Methods
    
    private func extractUIKitViews(from mirror: Mirror) -> [UIView] {
        var views: [UIView] = []
        
        for child in mirror.children {
            if let view = child.value as? UIView {
                views.append(view)
            } else if let nestedMirror = Mirror(reflecting: child.value) as Mirror? {
                views.append(contentsOf: extractUIKitViews(from: nestedMirror))
            }
        }
        
        return views
    }
    
    private func extractChildViews(from mirror: Mirror) -> [[String: Any]] {
        var children: [[String: Any]] = []
        
        for child in mirror.children {
            if isSwiftUIView(child.value) {
                children.append(extractViewHierarchy(from: child.value))
            }
        }
        
        return children
    }
    
    private func isSwiftUIView(_ object: Any) -> Bool {
        let typeName = String(describing: type(of: object))
        return typeName.contains("SwiftUI") || 
               typeName.contains("ModifiedContent") ||
               typeName.contains("TupleView") ||
               typeName.contains("_ConditionalContent") ||
               typeName.contains("ForEach") ||
               typeName.contains("Group") ||
               typeName.contains("Stack")
    }
    
    private func readableTypeName(from mangledName: String) -> String {
        // Handle common SwiftUI mangled names
        if mangledName.hasPrefix("_Tt") {
            return demangleSwiftUIType(mangledName)
        }
        
        // Handle generic SwiftUI types
        if let readable = extractReadableSwiftUIType(from: mangledName) {
            return readable
        }
        
        return mangledName
    }
    
    private func demangleSwiftUIType(_ mangledName: String) -> String {
        // Common SwiftUI type mappings
        let typeMap: [String: String] = [
            "UIShapeHitTestingView": "SwiftUI Shape Container",
            "UIKitSwiftUIView": "SwiftUI UIKit Bridge",
            "HostingView": "SwiftUI Hosting View",
            "SystemBackgroundView": "SwiftUI System Background",
            "HostingScrollView": "SwiftUI Hosting ScrollView",
            "PlatformGroupContainer": "SwiftUI Platform Group Container",
            "ListTableViewCell": "SwiftUI List Cell",
            "DisplayList": "SwiftUI Display List",
            "ViewHost": "SwiftUI View Host",
            "ContainerView": "SwiftUI Container View",
            "LayoutView": "SwiftUI Layout View",
            "ContentView": "SwiftUI Content View",
            "WrapperView": "SwiftUI Wrapper View",
            "BackgroundView": "SwiftUI Background View",
            "ScrollViewReader": "SwiftUI ScrollView Reader",
            "LazyVGrid": "SwiftUI LazyVGrid",
            "LazyHGrid": "SwiftUI LazyHGrid",
            "LazyVStack": "SwiftUI LazyVStack",
            "LazyHStack": "SwiftUI LazyHStack"
        ]
        
        for (key, value) in typeMap {
            if mangledName.contains(key) {
                return value
            }
        }
        
        // Handle specific mangled name patterns
        if mangledName.hasPrefix("_TtCC7SwiftUI") {
            // Extract the class name after the module prefix
            if let classNameMatch = extractClassNameFromMangledSwiftUI(mangledName) {
                return "SwiftUI.\(classNameMatch)"
            }
        }
        
        // Handle other Swift mangled name patterns
        if mangledName.hasPrefix("_TtC") {
            if let moduleName = extractModuleName(from: mangledName),
               let className = extractClassName(from: mangledName) {
                return "\(moduleName).\(className)"
            }
        }
        
        // Try to extract meaningful parts from mangled names
        if mangledName.contains("SwiftUI") {
            let components = mangledName.components(separatedBy: ".")
            if let lastComponent = components.last {
                return "SwiftUI.\(lastComponent)"
            }
        }
        
        return "SwiftUI View (mangled: \(mangledName))"
    }
    
    private func extractClassNameFromMangledSwiftUI(_ mangledName: String) -> String? {
        // Pattern: _TtCC7SwiftUI<length><classname><length><innerclass>
        // Example: _TtCC7SwiftUI17HostingScrollView22PlatformGroupContainer
        
        if mangledName.hasPrefix("_TtCC7SwiftUI") {
            let remaining = String(mangledName.dropFirst("_TtCC7SwiftUI".count))
            
            // Extract first class name
            if let lengthEnd = remaining.firstIndex(where: { !$0.isNumber }) {
                let lengthStr = String(remaining[..<lengthEnd])
                if let length = Int(lengthStr) {
                    let classNameStart = lengthEnd
                    let classNameEnd = remaining.index(classNameStart, offsetBy: length, limitedBy: remaining.endIndex)
                    
                    if let classNameEnd = classNameEnd {
                        let className = String(remaining[classNameStart..<classNameEnd])
                        
                        // Check if there's an inner class
                        let afterClassName = remaining[classNameEnd...]
                        if let innerLengthEnd = afterClassName.firstIndex(where: { !$0.isNumber }) {
                            let innerLengthStr = String(afterClassName[..<innerLengthEnd])
                            if let innerLength = Int(innerLengthStr) {
                                let innerClassNameStart = innerLengthEnd
                                let innerClassNameEnd = afterClassName.index(innerClassNameStart, offsetBy: innerLength, limitedBy: afterClassName.endIndex)
                                
                                if let innerClassNameEnd = innerClassNameEnd {
                                    let innerClassName = String(afterClassName[innerClassNameStart..<innerClassNameEnd])
                                    return "\(className).\(innerClassName)"
                                }
                            }
                        }
                        
                        return className
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractModuleName(from mangledName: String) -> String? {
        // Basic Swift module name extraction from mangled names
        if mangledName.hasPrefix("_TtC") {
            let remaining = String(mangledName.dropFirst("_TtC".count))
            if let lengthEnd = remaining.firstIndex(where: { !$0.isNumber }) {
                let lengthStr = String(remaining[..<lengthEnd])
                if let length = Int(lengthStr) {
                    let moduleNameStart = lengthEnd
                    let moduleNameEnd = remaining.index(moduleNameStart, offsetBy: length, limitedBy: remaining.endIndex)
                    
                    if let moduleNameEnd = moduleNameEnd {
                        return String(remaining[moduleNameStart..<moduleNameEnd])
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractClassName(from mangledName: String) -> String? {
        // Basic Swift class name extraction from mangled names
        if mangledName.hasPrefix("_TtC") {
            let remaining = String(mangledName.dropFirst("_TtC".count))
            
            // Skip module name first
            if let lengthEnd = remaining.firstIndex(where: { !$0.isNumber }) {
                let lengthStr = String(remaining[..<lengthEnd])
                if let length = Int(lengthStr) {
                    let afterModuleName = remaining[remaining.index(lengthEnd, offsetBy: length)...]
                    
                    // Now extract class name
                    if let classLengthEnd = afterModuleName.firstIndex(where: { !$0.isNumber }) {
                        let classLengthStr = String(afterModuleName[..<classLengthEnd])
                        if let classLength = Int(classLengthStr) {
                            let classNameStart = classLengthEnd
                            let classNameEnd = afterModuleName.index(classNameStart, offsetBy: classLength, limitedBy: afterModuleName.endIndex)
                            
                            if let classNameEnd = classNameEnd {
                                return String(afterModuleName[classNameStart..<classNameEnd])
                            }
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func extractReadableSwiftUIType(from typeName: String) -> String? {
        // Handle common SwiftUI patterns
        if typeName.contains("ModifiedContent") {
            return "Modified SwiftUI View"
        }
        
        if typeName.contains("TupleView") {
            return "SwiftUI Tuple View"
        }
        
        if typeName.contains("_ConditionalContent") {
            return "SwiftUI Conditional View"
        }
        
        if typeName.contains("ForEach") {
            return "SwiftUI ForEach"
        }
        
        if typeName.contains("HStack") {
            return "SwiftUI HStack"
        }
        
        if typeName.contains("VStack") {
            return "SwiftUI VStack"
        }
        
        if typeName.contains("ZStack") {
            return "SwiftUI ZStack"
        }
        
        if typeName.contains("Group") {
            return "SwiftUI Group"
        }
        
        return nil
    }
}

// MARK: - SwiftUI View Extensions for Introspection
// (Moved to FLEXSwiftUI.swift for better organization)

// MARK: - Extensions for FLEX Integration

extension FLEXSwiftUIIntrospectBridge {
    /// Registers a SwiftUI view for enhanced debugging
    /// - Parameter view: The UIKit view that backs a SwiftUI view
    @objc public func registerSwiftUIView(_ view: UIView) {
        // Add metadata to help FLEX identify this as a SwiftUI-backed view
        objc_setAssociatedObject(
            view,
            &AssociatedKeys.isSwiftUIBacked,
            true,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
    
    /// Checks if a UIView is backed by SwiftUI
    /// - Parameter view: The UIView to check
    /// - Returns: True if the view is SwiftUI-backed
    @objc public func isSwiftUIBackedView(_ view: UIView) -> Bool {
        return objc_getAssociatedObject(view, &AssociatedKeys.isSwiftUIBacked) as? Bool ?? false
    }
}

private struct AssociatedKeys {
    static var isSwiftUIBacked: UInt8 = 0
} 
