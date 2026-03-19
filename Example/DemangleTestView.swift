//
//  DemangleTestView.swift
//  FLEX
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

import SwiftUI
import FLEXSwiftUI

/// Test view with custom name to verify demangling works
struct CustomPaymentView: View {
    @State private var amount: Double = 0.0
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Payment: \(amount, specifier: "%.2f")")
                .font(.title)
            
            Button("Tap to inspect in FLEX") {
                print("Tapped - should show CustomPaymentView in FLEX")
                FLEXSwiftUIBridge.inspect(view: self)
            }
            
            Text("Custom view type should be:")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("CustomPaymentView")
                .font(.caption)
                .foregroundColor(.blue)
            
            Divider()
            
            Text("Mangled version would show as:")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("_TtCC7MyApp16CustomPaymentView")
                .font(.caption)
                .font(.system(.monospaced))
                .foregroundColor(.red)
        }
        .padding()
        .navigationTitle("Demangle Test")
    }
}

/// Another custom view with complex generics
struct GenericWrapperView<T: View>: View {
    let content: T
    
    var body: some View {
        content
    }
}

/// Test view using generics
struct ComplexGenericView: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("Generic View Test")
                .font(.headline)
            
            GenericWrapperView(content: Text("Generic Content"))
                .onTapGesture {
                    print("Generic wrapper type should be: GenericWrapperView<SwiftUI.Text>")
                    FLEXSwiftUIBridge.inspect(view: GenericWrapperView(content: Text("Generic Content")))
                }
        }
    }
}
