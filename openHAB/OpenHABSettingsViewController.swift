// Copyright (c) 2010-2022 Contributors to the openHAB project
//
// See the NOTICE file(s) distributed with this work for additional
// information.
//
// This program and the accompanying materials are made available under the
// terms of the Eclipse Public License 2.0 which is available at
// http://www.eclipse.org/legal/epl-2.0
//
// SPDX-License-Identifier: EPL-2.0

import FirebaseCrashlytics
import Kingfisher
import OpenHABCore
import os.log
import SafariServices
import UIKit

class OpenHABSettingsViewController: UITableViewController, UITextFieldDelegate {
    var settingsLocalUrl = ""
    var settingsRemoteUrl = ""
    var settingsUsername = ""
    var settingsPassword = ""
    var settingsAlwaysSendCreds = false
    var settingsIgnoreSSL = false
    var settingsDemomode = false
    var settingsIdleOff = false
    var settingsIconType: IconType = .png
    var settingsRealTimeSliders = false
    var settingsSendCrashReports = false

    var appData: OpenHABDataObject? {
        AppDelegate.appDelegate.appData
    }

    @IBOutlet private var settingsTableView: UITableView!
    @IBOutlet private var demomodeSwitch: UISwitch!
    @IBOutlet private var passwordTextField: UITextField!
    @IBOutlet private var usernameTextField: UITextField!
    @IBOutlet private var remoteUrlTextField: UITextField!
    @IBOutlet private var localUrlTextField: UITextField!
    @IBOutlet private var idleOffSwitch: UISwitch!
    @IBOutlet private var ignoreSSLSwitch: UISwitch!
    @IBOutlet private var iconSegmentedControl: UISegmentedControl!
    @IBOutlet private var alwaysSendCredsSwitch: UISwitch!
    @IBOutlet private var realTimeSlidersSwitch: UISwitch!
    @IBOutlet private var sendCrashReportsSwitch: UISwitch!
    @IBOutlet private var sendCrashReportsDummy: UIButton!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        os_log("OpenHABSettingsViewController viewDidLoad", log: .viewCycle, type: .info)
        navigationItem.hidesBackButton = true
        let leftBarButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(OpenHABSettingsViewController.cancelButtonPressed(_:)))
        let rightBarButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(OpenHABSettingsViewController.saveButtonPressed(_:)))
        navigationItem.leftBarButtonItem = leftBarButton
        navigationItem.rightBarButtonItem = rightBarButton
        loadSettings()
        updateSettingsUi()
        localUrlTextField?.delegate = self
        remoteUrlTextField?.delegate = self
        usernameTextField?.delegate = self
        passwordTextField?.delegate = self
        demomodeSwitch?.addTarget(self, action: #selector(OpenHABSettingsViewController.demomodeSwitchChange(_:)), for: .valueChanged)
        sendCrashReportsDummy.addTarget(self, action: #selector(crashReportingDummyPressed(_:)), for: .touchUpInside)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
            settingsTableView.deselectRow(at: indexPathForSelectedRow, animated: true)
        }
    }

    // This is to automatically hide keyboard on done/enter pressing
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }

    @objc
    private func cancelButtonPressed(_ sender: Any?) {
        navigationController?.popViewController(animated: true)
        os_log("Cancel button pressed", log: .viewCycle, type: .info)
    }

    @objc
    private func saveButtonPressed(_ sender: Any?) {
        // TODO: Make a check if any of the preferences has changed
        os_log("Save button pressed", log: .viewCycle, type: .info)

        updateSettings()
        saveSettings()
        appData?.rootViewController?.pageUrl = ""
        navigationController?.popToRootViewController(animated: true)
    }

    @objc
    private func demomodeSwitchChange(_ sender: Any?) {
        if demomodeSwitch!.isOn {
            os_log("Demo is ON", log: .viewCycle, type: .info)
            disableConnectionSettings()
        } else {
            os_log("Demo is OFF", log: .viewCycle, type: .info)
            enableConnectionSettings()
        }
    }

    @objc
    private func privacyButtonPressed(_ sender: Any?) {
        let webViewController = SFSafariViewController(url: URL.privacyPolicy)
        webViewController.configuration.barCollapsingEnabled = true

        present(webViewController, animated: true)
    }

    @objc
    private func crashReportingDummyPressed(_ sender: Any?) {
        if sendCrashReportsSwitch.isOn {
            sendCrashReportsSwitch.setOn(!sendCrashReportsSwitch.isOn, animated: true)
            Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(false)
        } else {
            let alertController = UIAlertController(title: NSLocalizedString("crash_reporting", comment: ""), message: NSLocalizedString("crash_reporting_info", comment: ""), preferredStyle: .actionSheet)
            alertController.addAction(
                UIAlertAction(title: NSLocalizedString("activate", comment: ""), style: .default) { [weak self] _ in
                    self?.sendCrashReportsSwitch.setOn(true, animated: true)
                    Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(true)
                }
            )
            alertController.addAction(
                UIAlertAction(title: NSLocalizedString("privacy_policy", comment: ""), style: .default) { [weak self] _ in
                    self?.privacyButtonPressed(nil)
                }
            )
            alertController.addAction(
                UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .default)
            )

            if let popOver = alertController.popoverPresentationController {
                popOver.sourceView = sendCrashReportsSwitch
                popOver.sourceRect = sendCrashReportsSwitch.bounds
            }
            present(alertController, animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var ret: Int
        switch section {
        case 0:
            if demomodeSwitch!.isOn {
                ret = 1
            } else {
                ret = 6
            }
        case 1:
            ret = 11
        default:
            ret = 10
        }
        return ret
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        settingsTableView.deselectRow(at: indexPath, animated: true)
        os_log("Row selected %d %d", log: .notifications, type: .info, indexPath.section, indexPath.row)
        switch tableView.cellForRow(at: indexPath)?.tag {
        case 888:
            privacyButtonPressed(nil)
        case 999:
            os_log("Clearing image cache", log: .viewCycle, type: .info)
            KingfisherManager.shared.cache.clearMemoryCache()
            KingfisherManager.shared.cache.clearDiskCache()
            KingfisherManager.shared.cache.cleanExpiredDiskCache()
        default: break
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return NSLocalizedString("openhab_connection", comment: "")
        default:
            return NSLocalizedString("application_settings", comment: "")
        }
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let version = appData?.openHABVersion ?? 2
        return version >= 3 && indexPath == IndexPath(row: 5, section: 1) ? .zero : UITableView.automaticDimension
    }

    func enableConnectionSettings() {
        settingsTableView.reloadData()
    }

    func disableConnectionSettings() {
        settingsTableView.reloadData()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        os_log("OpenHABSettingsViewController prepareForSegue", log: .viewCycle, type: .info)

        if segue.identifier == "showSelectSitemap" {
            os_log("OpenHABSettingsViewController showSelectSitemap", log: .viewCycle, type: .info)
            let dest = segue.destination as! OpenHABDrawerTableViewController
            dest.drawerTableType = .withoutStandardMenuEntries
            dest.openHABRootUrl = appData?.openHABRootUrl ?? ""
            dest.delegate = appData?.rootViewController
            updateSettings()
            saveSettings()
        }
    }

    func updateSettingsUi() {
        localUrlTextField?.text = settingsLocalUrl
        remoteUrlTextField?.text = settingsRemoteUrl
        usernameTextField?.text = settingsUsername
        passwordTextField?.text = settingsPassword
        alwaysSendCredsSwitch?.isOn = settingsAlwaysSendCreds
        ignoreSSLSwitch?.isOn = settingsIgnoreSSL
        demomodeSwitch?.isOn = settingsDemomode
        idleOffSwitch?.isOn = settingsIdleOff
        realTimeSlidersSwitch?.isOn = settingsRealTimeSliders
        sendCrashReportsSwitch?.isOn = settingsSendCrashReports
        iconSegmentedControl?.selectedSegmentIndex = settingsIconType.rawValue
        if settingsDemomode == true {
            disableConnectionSettings()
        } else {
            enableConnectionSettings()
        }
    }

    func loadSettings() {
        settingsLocalUrl = Preferences.localUrl
        settingsRemoteUrl = Preferences.remoteUrl
        settingsUsername = Preferences.username
        settingsPassword = Preferences.password
        settingsAlwaysSendCreds = Preferences.alwaysSendCreds
        settingsIgnoreSSL = Preferences.ignoreSSL
        settingsDemomode = Preferences.demomode
        settingsIdleOff = Preferences.idleOff
        settingsRealTimeSliders = Preferences.realTimeSliders
        settingsSendCrashReports = Preferences.sendCrashReports
        let rawSettingsIconType = Preferences.iconType
        settingsIconType = IconType(rawValue: rawSettingsIconType) ?? .png
    }

    func updateSettings() {
        settingsLocalUrl = localUrlTextField?.text ?? ""
        settingsRemoteUrl = remoteUrlTextField?.text ?? ""
        settingsUsername = usernameTextField?.text ?? ""
        settingsPassword = passwordTextField?.text ?? ""
        settingsAlwaysSendCreds = alwaysSendCredsSwitch?.isOn ?? false
        settingsIgnoreSSL = ignoreSSLSwitch?.isOn ?? false
        NetworkConnection.shared.serverCertificateManager.ignoreSSL = settingsIgnoreSSL
        settingsDemomode = demomodeSwitch?.isOn ?? false
        settingsIdleOff = idleOffSwitch?.isOn ?? false
        settingsRealTimeSliders = realTimeSlidersSwitch?.isOn ?? false
        settingsSendCrashReports = sendCrashReportsSwitch?.isOn ?? false
        settingsIconType = IconType(rawValue: iconSegmentedControl.selectedSegmentIndex) ?? .png
    }

    func saveSettings() {
        Preferences.localUrl = settingsLocalUrl
        Preferences.remoteUrl = settingsRemoteUrl
        Preferences.username = settingsUsername
        Preferences.password = settingsPassword
        Preferences.alwaysSendCreds = settingsAlwaysSendCreds
        Preferences.ignoreSSL = settingsIgnoreSSL
        Preferences.demomode = settingsDemomode
        Preferences.idleOff = settingsIdleOff
        Preferences.realTimeSliders = settingsRealTimeSliders
        Preferences.iconType = settingsIconType.rawValue
        Preferences.sendCrashReports = settingsSendCrashReports

        WatchMessageService.singleton.syncPreferencesToWatch()
    }
}
