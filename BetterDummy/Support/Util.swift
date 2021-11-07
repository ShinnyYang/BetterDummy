//
//  BetterDummy
//
//  Created by @waydabber
//

import Cocoa
import Foundation
import os.log
import ServiceManagement

class Util {
  // Notifications

  static func setupNotifications() {
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(app.handleSleepNotification), name: NSWorkspace.screensDidSleepNotification, object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(app.handleSleepNotification), name: NSWorkspace.willSleepNotification, object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(app.handleWakeNotification), name: NSWorkspace.screensDidWakeNotification, object: nil)
    NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(app.handleWakeNotification), name: NSWorkspace.didWakeNotification, object: nil)
    CGDisplayRegisterReconfigurationCallback({ _, _, _ in app.handleDisplayReconfiguration() }, nil)
  }

  // MARK: Save and restore settings

  static func setDefaultPrefs() {
    if !prefs.bool(forKey: PrefKey.appAlreadyLaunched.rawValue) {
      prefs.set(true, forKey: PrefKey.appAlreadyLaunched.rawValue)
      prefs.set(true, forKey: PrefKey.SUEnableAutomaticChecks.rawValue)
      os_log("Setting default preferences.", type: .info)
    }
  }

  static func saveSettings() {
    guard DummyManager.dummies.count > 0 else {
      return
    }
    prefs.set(true, forKey: PrefKey.appAlreadyLaunched.rawValue)
    prefs.set(app.menu.automaticallyCheckForUpdatesMenuItem.state == .on, forKey: PrefKey.SUEnableAutomaticChecks.rawValue)
    prefs.set(Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1") ?? 1, forKey: PrefKey.buildNumber.rawValue)
    prefs.set(app.menu.startAtLoginMenuItem.state == .on, forKey: PrefKey.startAtLogin.rawValue)
    prefs.set(app.menu.enable16KMenuItem.state == .on, forKey: PrefKey.enable16K.rawValue)
    prefs.set(app.menu.reconnectAfterSleepMenuItem.state == .on, forKey: PrefKey.reconnectAfterSleep.rawValue)
    prefs.set(app.menu.useTempSleepMenuItem.state == .off, forKey: PrefKey.disableTempSleep.rawValue)
    prefs.set(DummyManager.dummies.count, forKey: PrefKey.numOfDummyDisplays.rawValue)
    var i = 1
    for dummy in DummyManager.dummies {
      prefs.set(dummy.value.dummyDefinitionItem, forKey: "\(PrefKey.display.rawValue)\(i)")
      prefs.set(dummy.value.serialNum, forKey: "\(PrefKey.serial.rawValue)\(i)")
      prefs.set(dummy.value.isConnected, forKey: "\(PrefKey.isConnected.rawValue)\(i)")
      i += 1
    }
    os_log("Preferences stored.", type: .info)
  }

  @available(macOS, deprecated: 10.10)
  static func restoreSettings() {
    os_log("Restoring settings.", type: .info)
    let startAtLogin = (SMCopyAllJobDictionaries(kSMDomainUserLaunchd).takeRetainedValue() as? [[String: AnyObject]])?.first { $0["Label"] as? String == "\(Bundle.main.bundleIdentifier!)Helper" }?["OnDemand"] as? Bool ?? false
    app.menu.startAtLoginMenuItem.state = startAtLogin ? .on : .off
    app.menu.automaticallyCheckForUpdatesMenuItem.state = prefs.bool(forKey: PrefKey.SUEnableAutomaticChecks.rawValue) ? .on : .off
    app.menu.enable16KMenuItem.state = prefs.bool(forKey: PrefKey.enable16K.rawValue) ? .on : .off
    app.menu.reconnectAfterSleepMenuItem.state = prefs.bool(forKey: PrefKey.reconnectAfterSleep.rawValue) ? .on : .off
    app.menu.useTempSleepMenuItem.state = !prefs.bool(forKey: PrefKey.disableTempSleep.rawValue) ? .on : .off
    guard prefs.integer(forKey: "numOfDummyDisplays") > 0 else {
      return
    }
    for i in 1 ... prefs.integer(forKey: PrefKey.numOfDummyDisplays.rawValue) where prefs.object(forKey: "\(PrefKey.display.rawValue)\(i)") != nil {
      let dummy = Dummy(number: DummyManager.dummyCounter, dummyDefinitionItem: prefs.integer(forKey: "\(PrefKey.display.rawValue)\(i)"), serialNum: UInt32(prefs.integer(forKey: "\(PrefKey.serial.rawValue)\(i)")), doConnect: prefs.bool(forKey: "\(PrefKey.isConnected.rawValue)\(i)"))
      DummyManager.processCreatedDummy(dummy)
    }
    app.menu.repopulateManageMenu()
  }
}
