//
//  AVHardware.swift
//  WebRTCDevices
//
//  Created by Colin Biggin on 2021-06-29.
//  Copyright © 2021 WhiteNile Systems Inc. All rights reserved.
//

import AVKit
import Combine
import ExternalAccessory
import Foundation
import os

public class AVHardware: HardwareSession {

	// MARK: Public variables
	public fileprivate(set) var session: AVAudioSession? = nil
	public fileprivate(set) var category: AVAudioSession.Category = .playAndRecord
	public fileprivate(set) var options: AVAudioSession.CategoryOptions = .defaultToSpeaker
	public fileprivate(set) var mode: AVAudioSession.Mode = .default
	public fileprivate(set) var portOverride: AVAudioSession.PortOverride = .none

	// MARK: protocol HardwareSession
	public var audioSession: AVAudioSession? { return AVAudioSession.sharedInstance() }
	public fileprivate(set) var microphonesChanged = PassthroughSubject<Bool, Never>()
	public fileprivate(set) var speakersChanged = PassthroughSubject<Bool, Never>()
	public var availableInputs = [String: AVHardwareDevice]()
	public var currentInputs = [String: AVHardwareDevice]()
	public var currentOutputs = [String: AVHardwareDevice]()
	public fileprivate(set) var logger = AppLogging(category: .avaudio)

	public init(category: AVAudioSession.Category = .playAndRecord,
				options: AVAudioSession.CategoryOptions = .defaultToSpeaker,
				mode: AVAudioSession.Mode = .default,
				portOverride: AVAudioSession.PortOverride = .none
	) {
		logger.log("AVHardware.init()")

		// initialize to the shared session
		self.session = AVAudioSession.sharedInstance()

		self.category = category
		self.options = options
		self.mode = mode
		self.portOverride = portOverride

		// add bluetooth to our options
		self.configureAudioSession()
		self.setupNotifications()
		self.parseCurrentDevices()
		self.dump()
	}

	deinit {
		logger.log("AVHardware.deinit")
		terminateNotifications()
	}

	public func makeCurrentInput(device: AVHardwareDevice) {
		logger.log("AVHardware.makeCurrentInput() -> \(device.description)")

		guard let session = self.session else { return }

		do {
			try session.setPreferredInput(device.portDescription)
		} catch {
			logger.error("AVHardware.makeCurrentInput() ERROR \(error.localizedDescription):")
		}
	}

	public func resetCurrentInput() {
		logger.log("AVHardware.resetCurrentInput()")

		guard let session = self.session else { return }

		do {
			try session.setPreferredInput(nil)
		} catch {
			logger.error("AVHardware.resetCurrentInput() ERROR \(error.localizedDescription):")
		}
	}
}

// MARK: Private methods
extension AVHardware {

	fileprivate func configureAudioSession() {
		logger.log("AVHardware.configureAudioSession()")

		guard let session = self.session else { return }

		do {
			try session.setActive(false)
			try session.setCategory(self.category, options: self.options)
			try session.setMode(self.mode)
			try session.setActive(true)

			logger.log("AVHardware.configureAudioSession() SUCCESS")
		} catch {
			let errorString = "\(error)"
			logger.error("AVHardware.configureAudioSession() ERROR -> \(errorString)")
		}
	}
}

// MARK: Notifications
extension AVHardware {

	fileprivate func setupNotifications() {
		logger.log("AVHardware.setupNotifications()")

		guard let session = self.session else { return }

		let centre = NotificationCenter.default

		centre.addObserver(self, selector: #selector(handleInterruption(notification:)), name: AVAudioSession.interruptionNotification, object: session)
		centre.addObserver(self, selector: #selector(handleRouteChange(notification:)), name: AVAudioSession.routeChangeNotification, object: session)
		centre.addObserver(self, selector: #selector(handleSilenceSecondaryAudioHint(notification:)), name: AVAudioSession.silenceSecondaryAudioHintNotification, object: session)
		centre.addObserver(self, selector: #selector(handleMediaServicesWereLost(notification:)), name: AVAudioSession.mediaServicesWereLostNotification, object: session)
		centre.addObserver(self, selector: #selector(handleMediaServicesWereReset(notification:)), name: AVAudioSession.mediaServicesWereResetNotification, object: session)

		centre.addObserver(self, selector: #selector(accessoryConnected(notification:)), name:NSNotification.Name.EAAccessoryDidConnect, object: nil)
		centre.addObserver(self, selector: #selector(accessoryDisconnected(notification:)), name:NSNotification.Name.EAAccessoryDidDisconnect, object: nil)
		let accessoryManager = EAAccessoryManager.shared()
		accessoryManager.registerForLocalNotifications()
	}

	fileprivate func terminateNotifications() {
		logger.log("AVHardware.terminateNotifications()")

		let centre = NotificationCenter.default
		centre.removeObserver(self)

		let accessoryManager = EAAccessoryManager.shared()
		accessoryManager.unregisterForLocalNotifications()
	}

	@objc
	func handleInterruption(notification: Notification) {

		guard let userInfo = notification.userInfo,
			let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
			let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
				logger.log("AVHardware.handleInterruption() ERROR")
				return
		}

		logger.log("AVHardware.handleInterruption() \(type)")

		switch type {
		case .began:
			break

		case .ended:
			parseCurrentDevices()

		default:
			break
		}
	}

	@objc
	func handleRouteChange(notification: Notification) {

		guard	let userInfo = notification.userInfo,
				let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
				let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
		logger.log("AVHardware.handleRouteChange() ERROR")
			return
		}

		logger.log("AVHardware.handleRouteChange() \(reason)")

		switch reason {
		case .newDeviceAvailable:
			parseCurrentDevices()

		case .oldDeviceUnavailable:
			parseCurrentDevices()

		case .routeConfigurationChange:
			parseCurrentDevices(false)

		case .unknown: fallthrough
		case .categoryChange: fallthrough
		case .override: fallthrough
		case .wakeFromSleep: fallthrough
		case .noSuitableRouteForCategory: fallthrough
		@unknown default:
			parseCurrentDevices(false)
		}
	}

	@objc
	func handleSilenceSecondaryAudioHint(notification: Notification) {
		logger.log("AVHardware.handleSilenceSecondaryAudioHint()")
	}

	@objc
	func handleMediaServicesWereLost(notification: Notification) {
		logger.log("AVHardware.handleMediaServicesWereLost()")
	}

	@objc
	func handleMediaServicesWereReset(notification: Notification) {
		logger.log("AVHardware.handleMediaServicesWereReset()")

		parseCurrentDevices()
	}

	@objc
	func accessoryConnected(notification: Notification) {
		logger.log("AVHardware.accessoryConnected()")

		parseCurrentDevices()
	}

	@objc
	func accessoryDisconnected(notification: Notification) {
		logger.log("AVHardware.accessoryDisconnected()")

		parseCurrentDevices()
	}
}

