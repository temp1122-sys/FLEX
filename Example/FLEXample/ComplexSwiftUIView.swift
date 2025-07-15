import SwiftUI
import UIKit

// MARK: - Complex SwiftUI View for FLEX Testing
@available(iOS 13.0, *)
public struct ComplexSwiftUIView: View {
    @State private var counter: Int = 0
    @State private var isExpanded: Bool = false
    @State private var selectedTab: Int = 0
    @State private var sliderValue: Double = 0.5
    @State private var toggleValue: Bool = false
    @State private var textFieldValue: String = "Test Input"
    @State private var showingAlert: Bool = false
    @State private var showingSheet: Bool = false
    @State private var pickerSelection: Int = 0
    
    private let colors: [Color] = [.red, .blue, .green, .orange, .purple, .pink]
    private let sampleData = ["Item 1", "Item 2", "Item 3", "Item 4", "Item 5"]
    
    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Section
                    HeaderSection(counter: $counter, isExpanded: $isExpanded)
                    
                    // Tab View Section
                    TabSection(selectedTab: $selectedTab, colors: colors)
                    
                    // Controls Section
                    ControlsSection(
                        sliderValue: $sliderValue,
                        toggleValue: $toggleValue,
                        textFieldValue: $textFieldValue,
                        pickerSelection: $pickerSelection
                    )
                    
                    // List Section
                    ListSection(sampleData: sampleData, colors: colors)
                    
                    // Geometric Shapes Section
                    GeometricShapesSection(sliderValue: sliderValue)
                    
                    // Interactive Cards Section
                    InteractiveCardsSection(
                        showingAlert: $showingAlert,
                        showingSheet: $showingSheet
                    )
                    
                    // Nested Views Section
                    NestedViewsSection(counter: counter)
                }
                .padding()
            }
            .navigationTitle("Complex SwiftUI View")
            .navigationBarTitleDisplayMode(.large)
            .alert("Alert Triggered", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text("This is a test alert for FLEX hierarchy analysis")
            }
            .sheet(isPresented: $showingSheet) {
                SheetContentView()
            }
        }
        .accessibilityIdentifier("ComplexSwiftUIView")
    }
}

// MARK: - Header Section
@available(iOS 13.0, *)
struct HeaderSection: View {
    @Binding var counter: Int
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.title)
                
                Text("FLEX Hierarchy Test")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { counter += 1 }) {
                    Text("\(counter)")
                        .font(.title)
                        .foregroundColor(.white)
                        .padding()
                        .background(Circle().fill(Color.blue))
                }
            }
            
            DisclosureGroup("Expandable Section", isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("This is an expandable section")
                    Text("It contains multiple nested views")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        ForEach(0..<3) { index in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.3))
                                .frame(height: 30)
                                .overlay(Text("Item \(index + 1)"))
                        }
                    }
                }
                .padding()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Tab Section
@available(iOS 13.0, *)
struct TabSection: View {
    @Binding var selectedTab: Int
    let colors: [Color]
    
    var body: some View {
        VStack {
            Picker("Tab Selection", selection: $selectedTab) {
                ForEach(0..<3) { index in
                    Text("Tab \(index + 1)").tag(index)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            TabView(selection: $selectedTab) {
                ForEach(0..<3) { index in
                    VStack {
                        Circle()
                            .fill(colors[index])
                            .frame(width: 100, height: 100)
                        Text("Tab \(index + 1) Content")
                            .font(.headline)
                    }
                    .tag(index)
                }
            }
            .frame(height: 200)
            .tabViewStyle(PageTabViewStyle())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Controls Section
@available(iOS 13.0, *)
struct ControlsSection: View {
    @Binding var sliderValue: Double
    @Binding var toggleValue: Bool
    @Binding var textFieldValue: String
    @Binding var pickerSelection: Int
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Interactive Controls")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Slider Value: \(sliderValue, specifier: "%.2f")")
                Slider(value: $sliderValue, in: 0...1)
                    .tint(.blue)
            }
            
            HStack {
                Text("Toggle:")
                Spacer()
                Toggle("", isOn: $toggleValue)
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text("Text Field:")
                TextField("Enter text", text: $textFieldValue)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text("Picker Selection:")
                Picker("Options", selection: $pickerSelection) {
                    ForEach(0..<5) { index in
                        Text("Option \(index + 1)").tag(index)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - List Section
@available(iOS 13.0, *)
struct ListSection: View {
    let sampleData: [String]
    let colors: [Color]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("List Section")
                .font(.headline)
            
            ForEach(Array(sampleData.enumerated()), id: \.offset) { index, item in
                HStack {
                    Circle()
                        .fill(colors[index % colors.count])
                        .frame(width: 30, height: 30)
                    
                    VStack(alignment: .leading) {
                        Text(item)
                            .font(.body)
                        Text("Subtitle for \(item)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .shadow(radius: 1)
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Geometric Shapes Section
@available(iOS 13.0, *)
struct GeometricShapesSection: View {
    let sliderValue: Double
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Geometric Shapes")
                .font(.headline)
            
            HStack(spacing: 20) {
                // Circle with dynamic size
                Circle()
                    .fill(Color.red)
                    .frame(width: 50 + CGFloat(sliderValue * 50))
                
                // Rectangle with rotation
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(sliderValue * 360))
                
                // Rounded rectangle with scaling
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.green)
                    .frame(width: 70, height: 70)
                    .scaleEffect(0.5 + sliderValue * 0.5)
            }
            
            // Complex path shape
            Path { path in
                path.move(to: CGPoint(x: 50, y: 0))
                path.addLine(to: CGPoint(x: 100, y: 50))
                path.addLine(to: CGPoint(x: 50, y: 100))
                path.addLine(to: CGPoint(x: 0, y: 50))
                path.closeSubpath()
            }
            .fill(Color.orange)
            .frame(width: 100, height: 100)
            .rotationEffect(.degrees(sliderValue * 180))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Interactive Cards Section
@available(iOS 13.0, *)
struct InteractiveCardsSection: View {
    @Binding var showingAlert: Bool
    @Binding var showingSheet: Bool
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Interactive Cards")
                .font(.headline)
            
            HStack(spacing: 15) {
                Button(action: { showingAlert = true }) {
                    CardView(
                        title: "Alert",
                        subtitle: "Tap to show alert",
                        color: .red
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { showingSheet = true }) {
                    CardView(
                        title: "Sheet",
                        subtitle: "Tap to show sheet",
                        color: .blue
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Card View
@available(iOS 13.0, *)
struct CardView: View {
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.fill")
                .font(.largeTitle)
                .foregroundColor(color)
            
            Text(title)
                .font(.headline)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(radius: 2)
        )
    }
}

// MARK: - Nested Views Section
@available(iOS 13.0, *)
struct NestedViewsSection: View {
    let counter: Int
    
    var body: some View {
        VStack(spacing: 10) {
            Text("Nested Views Hierarchy")
                .font(.headline)
            
            // Multiple levels of nesting
            VStack {
                HStack {
                    VStack {
                        HStack {
                            Text("Level 1")
                            VStack {
                                Text("Level 2")
                                HStack {
                                    Text("Level 3")
                                    VStack {
                                        Text("Level 4")
                                        Text("Counter: \(counter)")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                        .padding(5)
                        .background(Color.yellow.opacity(0.3))
                        .cornerRadius(5)
                    }
                    .padding(5)
                    .background(Color.green.opacity(0.3))
                    .cornerRadius(5)
                }
                .padding(5)
                .background(Color.blue.opacity(0.3))
                .cornerRadius(5)
            }
            .padding(5)
            .background(Color.red.opacity(0.3))
            .cornerRadius(5)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// MARK: - Sheet Content View
@available(iOS 13.0, *)
struct SheetContentView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Sheet Content")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("This is a modal sheet presented from the main view")
                    .multilineTextAlignment(.center)
                    .padding()
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 20) {
                    ForEach(0..<6) { index in
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.6))
                            .frame(height: 80)
                            .overlay(
                                Text("Grid Item \(index + 1)")
                                    .foregroundColor(.white)
                                    .fontWeight(.semibold)
                            )
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Modal Sheet")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Close") { dismiss() })
        }
    }
}

// MARK: - Objective-C Bridge
@available(iOS 13.0, *)
@objc public class ComplexSwiftUIViewBridge: NSObject {
    @objc public static func createComplexSwiftUIView() -> AnyView {
        return AnyView(ComplexSwiftUIView())
    }
    
    @objc public static func createHostingController() -> UIViewController {
        return UIHostingController(rootView: ComplexSwiftUIView())
    }
}

// MARK: - ComplexSwiftUIView Extension for Objective-C
@available(iOS 13.0, *)
extension ComplexSwiftUIView {
    @objc public static func createViewController() -> UIViewController {
        return UIHostingController(rootView: ComplexSwiftUIView())
    }
} 