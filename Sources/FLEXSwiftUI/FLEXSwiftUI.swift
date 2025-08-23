//
//  FLEXSwiftUI.swift
//  FLEX
//
//  Created by FLEX Team on SwiftUI integration.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

import Foundation
import SwiftUI

// MARK: - Public API

/// Initialize SwiftUI integration for FLEX
/// Call this early in your app launch, typically in AppDelegate or SceneDelegate
public func initializeFLEXSwiftUI() {
    FLEXSwiftUIIntrospectBridge.setupFLEXSwiftUI()
}

// MARK: - SwiftUI View Extension

@available(iOS 15.0, *)
extension View {
    /// Adds FLEX debugging capabilities to SwiftUI views
    /// This is automatically enabled when FLEXSwiftUI is initialized
    public func flexDebug() -> some View {
        self.background(
            FlexIntrospectionView()
                .frame(width: 0, height: 0)
                .hidden()
        )
    }
}

// MARK: - Supporting Types

@available(iOS 15.0, *)
private struct FlexIntrospectionView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        
        // Register this view for FLEX introspection
        DispatchQueue.main.async {
            if let parentView = view.superview {
                FLEXSwiftUIIntrospectBridge.shared.registerSwiftUIView(parentView)
            }
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // No updates needed
    }
} 