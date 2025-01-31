//
//  TJHardware.swift
//  WebRTCDevices
//
//  Created by Colin Biggin on 2024-04-05.
//  Copyright © 2021 WhiteNile Systems Inc. All rights reserved.
//

import AVKit
import Combine
import ExternalAccessory
import Foundation
import S10TJ

// MARK: -
public class TJHardware: NSObject, HardwareSession {

	// MARK: Public variables
	public fileprivate(set) var category: AVAudioSession.Category = .record
	public fileprivate(set) var options: AVAudioSession.CategoryOptions = .defaultToSpeaker
	public fileprivate(set) var mode: AVAudioSession.Mode = .default
	public fileprivate(set) var portOverride: AVAudioSession.PortOverride = .none

	// MARK: protocol HardwareSession { get set }
	public var audioSession: AVAudioSession?
	public var availableInputs = [String: AVHardwareDevice]()
	public var currentInputs = [String: AVHardwareDevice]()
	public var currentOutputs = [String: AVHardwareDevice]()

	// MARK: protocol HardwareSession { get }
	public fileprivate(set) var microphonesChanged = PassthroughSubject<Bool, Never>()
	public fileprivate(set) var speakersChanged = PassthroughSubject<Bool, Never>()
	public fileprivate(set) var logger = AppLogging(category: .tjaudio)

	// MARK: private variables
	private var tjAudioSession: TJAudioSession? = nil
	private var subscriptions = [AnyCancellable]()

	public init(category: AVAudioSession.Category = .record,
				options: AVAudioSession.CategoryOptions = .defaultToSpeaker,
				mode: AVAudioSession.Mode = .default,
				portOverride: AVAudioSession.PortOverride = .none,
				notifications: Bool = false,
				subscriptions: Bool = true
	) {
		super.init()
		logger.log("TJHardware.init()")

		// configure a few things
		self.tjAudioSession = TJAudioSession(identifier: "TJAudioSession")
		if let session = self.tjAudioSession {
			self.audioSession = session.audioSession
		}

		self.category = category
		self.options = options
		self.mode = mode
		self.portOverride = portOverride

		if notifications {
			self.setupNotifications()
		}
		if subscriptions {
			self.setupSubscriptions()
		}
		self.parseCurrentDevices()
		self.dump()
	}

	deinit {
		logger.log("TJHardware.deinit")
		reset()
	}

	public func reset() {
		logger.log("TJHardware.reset()")
		terminateNotifications()
	}
}

// MARK: Notifications
extension TJHardware {

	fileprivate func setupSubscriptions() {
		logger.log("TJHardware.setupSubscriptions()")
/*
		guard let tjAudioSession else { return }

		tjAudioSession.audioNotifications
			.sink { notification in
				switch notification.name {
				case AVAudioSession.interruptionNotification:
					self.logger.log("TJHardware.setupSubscriptions().audioNotifications [AVAudioSession.interruptionNotification]")
//					self.microphonesChanged.send(true)
					self.handleInterruption(notification: notification)
				case AVAudioSession.routeChangeNotification:
					self.logger.log("TJHardware.setupSubscriptions().audioNotifications [AVAudioSession.routeChangeNotification]")
//					self.microphonesChanged.send(true)
					self.handleRouteChange(notification: notification)
				default:
					break
				}
			}
			.store(in: &subscriptions)
 */
	}

	fileprivate func setupNotifications() {
		logger.log("TJHardware.setupNotifications()")

		guard let audioSession else { return }

		let centre = NotificationCenter.default

		centre.addObserver(self, selector: #selector(handleInterruption(notification:)), name: AVAudioSession.interruptionNotification, object: audioSession)
		centre.addObserver(self, selector: #selector(handleRouteChange(notification:)), name: AVAudioSession.routeChangeNotification, object: audioSession)
		centre.addObserver(self, selector: #selector(handleSilenceSecondaryAudioHint(notification:)), name: AVAudioSession.silenceSecondaryAudioHintNotification, object: audioSession)
		centre.addObserver(self, selector: #selector(handleMediaServicesWereLost(notification:)), name: AVAudioSession.mediaServicesWereLostNotification, object: audioSession)
		centre.addObserver(self, selector: #selector(handleMediaServicesWereReset(notification:)), name: AVAudioSession.mediaServicesWereResetNotification, object: audioSession)

		centre.addObserver(self, selector: #selector(accessoryConnected(notification:)), name:NSNotification.Name.EAAccessoryDidConnect, object: nil)
		centre.addObserver(self, selector: #selector(accessoryDisconnected(notification:)), name:NSNotification.Name.EAAccessoryDidDisconnect, object: nil)

		let accessoryManager = EAAccessoryManager.shared()
		accessoryManager.registerForLocalNotifications()
	}

	fileprivate func terminateNotifications() {
		logger.log("TJHardware.terminateNotifications()")

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
				logger.log("TJHardware.handleInterruption() ERROR")
				return
		}

		logger.log("TJHardware.handleInterruption() \(type)")

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
			logger.error("TJHardware.handleRouteChange() ERROR")
			return
		}

		logger.log("TJHardware.handleRouteChange() \(reason)")

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
		logger.log("TJHardware.handleSilenceSecondaryAudioHint()")
	}

	@objc
	func handleMediaServicesWereLost(notification: Notification) {
		logger.log("TJHardware.handleMediaServicesWereLost()")
	}

	@objc
	func handleMediaServicesWereReset(notification: Notification) {
		logger.log("TJHardware.handleMediaServicesWereReset()")

		parseCurrentDevices()
	}

	@objc
	func accessoryConnected(notification: Notification) {
		logger.log("TJHardware.accessoryConnected()")

		parseCurrentDevices()
	}

	@objc
	func accessoryDisconnected(notification: Notification) {
		logger.log("TJHardware.accessoryDisconnected()")

		parseCurrentDevices()
	}
}
