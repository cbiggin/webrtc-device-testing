//
//  AppDelegate.swift
//  WebRTCDevices
//
//  Created by Colin Biggin on 2021-06-29.
//  Copyright © 2021 WhiteNile Systems Inc. All rights reserved.
//

import S10TJ
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

		setupAppLogging()
		setupTJLogging()

		// Override point for customization after application launch.
		return true
	}

	// MARK: UISceneSession Lifecycle

	func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
		// Called when a new scene session is being created.
		// Use this method to select a configuration to create the new scene with.
		return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
	}

	func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
		// Called when the user discards a scene session.
		// If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
		// Use this method to release any resources that were specific to the discarded scenes, as they will not return.
	}

	func setupAppLogging() {
		let categories: [AppLoggingCategory] = [
			.hardware,
			.avaudio,
			.rtcaudio,
			.tjaudio
		]

		AppLogging.setLoggingCategories(categories)
//		AppLogging.archiveEnable()
//		AppLogging.disable()
		AppLogging.enable()
	}

	func setupTJLogging() {
		let categories: [TJLoggingCategory] = [
//			.source,
//			.canvas,
//			.sourceCapture,
//			.output,
//			.audioSession,
//			.audioSessionNotifications
		]
		TJLogging.setLoggingCategories(categories)
//		TJLogging.archiveEnable()
//		TJLogging.disable()
		TJLogging.enable()
	}
}

