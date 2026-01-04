//
//  SpeedBarApp.swift
//  SpeedBar
//
//  Menu bar network quality measurement application
//

import SwiftUI

@main
struct SpeedBarApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Menu bar apps typically don't need a WindowGroup
        Settings {
            EmptyView()
        }
    }
}
