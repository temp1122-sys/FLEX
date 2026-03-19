//
//  SwiftUIInspectorTest.swift
//  FLEXample
//
//  Created by FLEX Team on SwiftUI enhancement.
//  Copyright (c) 2020 FLEX Team. All rights reserved.
//

import SwiftUI
import UIKit

/// Comprehensive test view for the SwiftUI inspector functionality
@available(iOS 15.0, *)
struct SwiftUIInspectorTest: View {
    @State private var inspectorEnabled: Bool = true
    @State private var showingDebugInfo: Bool = false
    @State private var selectedTestCase: TestCase = .basic
    @State private var testValue: String = "Hello FLEX"
    @State private var counter: Int = 42
    @ObservedObject private var viewModel = TestViewModel()
    
    enum TestCase: String, CaseIterable {
        case basic = "Basic Views"
        case state = "State Variables"
        case bindings = "Bindings"
        case modifiers = "Modifiers"
        case nested = "Nested Hierarchy"
        case performance = "Performance Test"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Inspector Status
                InspectorStatusView(enabled: $inspectorEnabled)
                
                // Test Case Selector
                TestCaseSelectorView(selectedTestCase: $selectedTestCase)
                
                // Test Content based on selected case
                Group {
                    switch selectedTestCase {
                    case .basic:
                        BasicViewsTest()
                    case .state:
                        StateVariablesTest(testValue: $testValue, counter: $counter)
                    case .bindings:
                        BindingsTest(viewModel: viewModel)
                    case .modifiers:
                        ModifiersTest()
                    case .nested:
                        NestedHierarchyTest()
                    case .performance:
                        PerformanceTest()
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                // Debug Actions
                DebugActionsView(
                    showingDebugInfo: $showingDebugInfo,
                    testValue: testValue,
                    counter: counter
                )
                
                Spacer()
            }
            .padding()
            .navigationTitle("SwiftUI Inspector Test")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            setupSwiftUIInspector()
        }
        .sheet(isPresented: $showingDebugInfo) {
            DebugInfoView(testValue: testValue, counter: counter, viewModel: viewModel)
        }
    }
    
    private func setupSwiftUIInspector() {
        // Enable enhanced SwiftUI debugging
        FLEXSwiftUIBridge.enableSwiftUIDebugging()
        
        // Set up initial state for testing
        print("SwiftUI Inspector Test initialized")
        print("Available test cases: \(TestCase.allCases.map { $0.rawValue })")
    }
}

// MARK: - Inspector Status View
@available(iOS 15.0, *)
struct InspectorStatusView: View {
    @Binding var enabled: Bool
    
    var body: some View {
        HStack {
            Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(enabled ? .green : .red)
                .font(.title2)
            
            VStack(alignment: .leading) {
                Text("SwiftUI Inspector")
                    .font(.headline)
                Text(enabled ? "Enabled" : "Disabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Test Inspector") {
                testInspector()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func testInspector() {
        // Test the SwiftUI inspector functionality
        let testView = Text("Inspector Test")
        FLEXSwiftUIBridge.inspect(view: testView)
    }
}

// MARK: - Test Case Selector
@available(iOS 15.0, *)
struct TestCaseSelectorView: View {
    @Binding var selectedTestCase: SwiftUIInspectorTest.TestCase
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Test Case")
                .font(.headline)
            
            Picker("Test Case", selection: $selectedTestCase) {
                ForEach(SwiftUIInspectorTest.TestCase.allCases, id: \.self) { testCase in
                    Text(testCase.rawValue).tag(testCase)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
}

// MARK: - Basic Views Test
@available(iOS 15.0, *)
struct BasicViewsTest: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Basic Views Test")
                .font(.headline)
            
            HStack {
                Text("Text View")
                    .onTapGesture {
                        FLEXSwiftUIBridge.inspect(view: self)
                    }
                
                Spacer()
                
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .onTapGesture {
                        FLEXSwiftUIBridge.inspect(view: Image(systemName: "star.fill"))
                    }
            }
            
            Button("Button Test") {
                print("Button tapped - inspect this!")
            }
            .onTapGesture {
                FLEXSwiftUIBridge.inspect(view: self)
            }
            
            Rectangle()
                .fill(Color.blue)
                .frame(height: 40)
                .onTapGesture {
                    FLEXSwiftUIBridge.inspect(view: Rectangle().fill(Color.blue))
                }
        }
    }
}

// MARK: - State Variables Test
@available(iOS 15.0, *)
struct StateVariablesTest: View {
    @Binding var testValue: String
    @Binding var counter: Int
    @State private var localState: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            Text("State Variables Test")
                .font(.headline)
            
            Text("Test Value: \(testValue)")
                .onTapGesture {
                    FLEXSwiftUIBridge.inspect(view: self)
                }
            
            Text("Counter: \(counter)")
                .onTapGesture {
                    // Get debug info for this specific view
                    let debugInfo = FLEXSwiftUIBridge.debugInfo(for: self)
                    print("Debug info: \(debugInfo)")
                }
            
            Toggle("Local State", isOn: $localState)
                .onTapGesture {
                    FLEXSwiftUIBridge.inspect(view: Toggle("Local State", isOn: $localState))
                }
            
            HStack {
                Button("-") { counter -= 1 }
                Button("+") { counter += 1 }
            }
        }
    }
}

// MARK: - Test View Model
@available(iOS 15.0, *)
class TestViewModel: ObservableObject {
    @Published var name: String = "Test Model"
    @Published var value: Double = 3.14
    @Published var isActive: Bool = true
    @Published var items: [String] = ["Item 1", "Item 2", "Item 3"]
    
    func updateValue() {
        value = Double.random(in: 0...10)
    }
    
    func addItem() {
        items.append("Item \(items.count + 1)")
    }
}

// MARK: - Bindings Test
@available(iOS 15.0, *)
struct BindingsTest: View {
    @ObservedObject var viewModel: TestViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Bindings Test")
                .font(.headline)
            
            Text("Model Name: \(viewModel.name)")
                .onTapGesture {
                    FLEXSwiftUIBridge.inspect(view: self)
                }
            
            Text("Value: \(viewModel.value, specifier: "%.2f")")
                .onTapGesture {
                    viewModel.updateValue()
                }
            
            Toggle("Active", isOn: $viewModel.isActive)
            
            Text("Items: \(viewModel.items.count)")
                .onTapGesture {
                    viewModel.addItem()
                }
        }
    }
}

// MARK: - Modifiers Test
@available(iOS 15.0, *)
struct ModifiersTest: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Modifiers Test")
                .font(.headline)
            
            Text("Styled Text")
                .font(.title2)
                .foregroundColor(.blue)
                .padding()
                .background(Color.yellow.opacity(0.3))
                .cornerRadius(8)
                .shadow(radius: 2)
                .onTapGesture {
                    FLEXSwiftUIBridge.inspect(view: self)
                }
            
            Image(systemName: "heart.fill")
                .font(.largeTitle)
                .foregroundColor(.red)
                .scaleEffect(1.2)
                .rotationEffect(.degrees(15))
                .onTapGesture {
                    FLEXSwiftUIBridge.inspect(view: 
                        Image(systemName: "heart.fill")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                            .scaleEffect(1.2)
                            .rotationEffect(.degrees(15))
                    )
                }
        }
    }
}

// MARK: - Nested Hierarchy Test
@available(iOS 15.0, *)
struct NestedHierarchyTest: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Nested Hierarchy Test")
                .font(.headline)
            
            VStack {
                HStack {
                    VStack {
                        Text("Deep")
                        HStack {
                            Text("Nested")
                            VStack {
                                Text("Views")
                                Text("Hierarchy")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(4)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(4)
                }
                .padding(4)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(4)
            }
            .padding(4)
            .background(Color.red.opacity(0.2))
            .cornerRadius(4)
            .onTapGesture {
                FLEXSwiftUIBridge.inspect(view: self)
            }
        }
    }
}

// MARK: - Performance Test
@available(iOS 15.0, *)
struct PerformanceTest: View {
    @State private var isRunning: Bool = false
    @State private var iterations: Int = 0
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Performance Test")
                .font(.headline)
            
            Text("Iterations: \(iterations)")
            
            Button(isRunning ? "Stop Test" : "Start Test") {
                if isRunning {
                    stopPerformanceTest()
                } else {
                    startPerformanceTest()
                }
            }
            .buttonStyle(.borderedProminent)
            
            if isRunning {
                ProgressView("Running performance test...")
                    .onTapGesture {
                        FLEXSwiftUIBridge.inspect(view: self)
                    }
            }
        }
    }
    
    private func startPerformanceTest() {
        isRunning = true
        iterations = 0
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            iterations += 1
            
            if iterations >= 100 {
                timer.invalidate()
                isRunning = false
            }
            
            // Test SwiftUI inspector performance
            if iterations % 10 == 0 {
                let debugInfo = FLEXSwiftUIBridge.debugInfo(for: self)
                print("Performance test iteration \(iterations): \(debugInfo.keys)")
            }
        }
    }
    
    private func stopPerformanceTest() {
        isRunning = false
    }
}

// MARK: - Debug Actions View
@available(iOS 15.0, *)
struct DebugActionsView: View {
    @Binding var showingDebugInfo: Bool
    let testValue: String
    let counter: Int
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Debug Actions")
                .font(.headline)
            
            HStack {
                Button("Show Debug Info") {
                    showingDebugInfo = true
                }
                .buttonStyle(.bordered)
                
                Button("Test Inspection") {
                    testManualInspection()
                }
                .buttonStyle(.bordered)
            }
            
            Button("Clear Cache") {
                clearInspectorCache()
            }
            .buttonStyle(.bordered)
        }
    }
    
    private func testManualInspection() {
        // Test manual inspection of different view types
        let views: [Any] = [
            Text("Test Text"),
            Image(systemName: "star"),
            Button("Test Button") { },
            VStack { Text("VStack Test") },
            HStack { Text("HStack Test") }
        ]
        
        for (index, view) in views.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.5) {
                print("Inspecting view \(index + 1): \(type(of: view))")
                FLEXSwiftUIBridge.inspect(view: view)
            }
        }
    }
    
    private func clearInspectorCache() {
        // This would call any cache clearing methods in our implementation
        print("Inspector cache cleared")
    }
}

// MARK: - Debug Info View
@available(iOS 15.0, *)
struct DebugInfoView: View {
    @Environment(\.dismiss) private var dismiss
    let testValue: String
    let counter: Int
    let viewModel: TestViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    DebugSection(title: "Test State") {
                        DebugItem(label: "Test Value", value: testValue)
                        DebugItem(label: "Counter", value: "\(counter)")
                    }
                    
                    DebugSection(title: "View Model") {
                        DebugItem(label: "Name", value: viewModel.name)
                        DebugItem(label: "Value", value: String(format: "%.2f", viewModel.value))
                        DebugItem(label: "Is Active", value: "\(viewModel.isActive)")
                        DebugItem(label: "Items Count", value: "\(viewModel.items.count)")
                    }
                    
                    DebugSection(title: "Inspector Info") {
                        DebugItem(label: "Swift Bridge", value: "Enabled")
                        DebugItem(label: "Metadata Support", value: "Available")
                        DebugItem(label: "Name Demangling", value: "Available")
                    }
                }
                .padding()
            }
            .navigationTitle("Debug Information")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Close") { dismiss() })
        }
    }
}

// MARK: - Debug Components
@available(iOS 15.0, *)
struct DebugSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            content
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

@available(iOS 15.0, *)
struct DebugItem: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Objective-C Bridge for Testing
@available(iOS 15.0, *)
@objc public class SwiftUIInspectorTestBridge: NSObject {
    @objc public static func createTestViewController() -> UIViewController {
        return UIHostingController(rootView: SwiftUIInspectorTest())
    }
    
    @objc public static func runInspectorTests() {
        print("Running SwiftUI Inspector Tests...")
        
        // Enable the bridge
        FLEXSwiftUIBridge.enableSwiftUIDebugging()
        
        // Test basic functionality
        let testView = SwiftUIInspectorTest()
        let debugInfo = FLEXSwiftUIBridge.debugInfo(for: testView)
        print("Test completed. Debug info keys: \(debugInfo.keys)")
    }
}