//
//  AppDelegate.swift
//  LocalizationEditor
//
//  Created by Igor Kulman on 30/05/2018.
//  Copyright © 2018 Igor Kulman. All rights reserved.
//
// swiftlint:disable private_outlet

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    @IBOutlet weak var openFolderMenuItem: NSMenuItem!
    @IBOutlet weak var exportToCSVItem: NSMenuItem!
    @IBOutlet weak var importFileItem: NSMenuItem!

    func applicationDidFinishLaunching(_: Notification) {}

    func applicationWillTerminate(_: Notification) {}
}
