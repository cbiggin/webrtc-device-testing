//
//  RTCHardware.swift
//  WebRTCDevices
//
//  Created by Colin Biggin on 2021-06-29.
//  Copyright © 2021 WhiteNile Systems Inc. All rights reserved.
//

import AVKit
import Combine
import ExternalAccessory
import Foundation
import WebRTC
import os

// MARK: -
public class RTCHardware: NSObject, HardwareSession {

	// MARK: Public variables
	public fileprivate(set) var category: AVAudioSession.Category = .record
	public fileprivate(set) var options: AVAudioSession.CategoryOptions = .defaultToSpeaker
	public fileprivate(set) var mode: AVAudioSession.Mode = .default
	public fileprivate(set) var portOverride: AVAudioSession.PortOverride = .none

	// MARK: protocol HardwareSession { get set }
	public var audioSession: AVAudioSession? { return RTCAudioSession.sharedInstance().session }
	public var availableInputs = [String: AVHardwareDevice]()
	public var currentInputs = [String: AVHardwareDevice]()
	public var currentOutputs = [String: AVHardwareDevice]()

	// MARK: protocol HardwareSession { get }
	public fileprivate(set) var microphonesChanged = PassthroughSubject<Bool, Never>()
	public fileprivate(set) var speakersChanged = PassthroughSubject<Bool, Never>()
	public fileprivate(set) var logger = AppLogging(category: .rtcaudio)

	public init(category: AVAudioSession.Category = .record,
				options: AVAudioSession.CategoryOptions = .defaultToSpeaker,
				mode: AVAudioSession.Mode = .default,
				portOverride: AVAudioSession.PortOverride = .none,
				notifications: Bool = true,
				accessories: Bool = true
	) {
		super.init()
		logger.log("RTCHardware.init()")

		// initialize WebRTC itself
//		RTCInitFieldTrialDictionary([kRTCFieldTrialH264HighProfileKey : kRTCFieldTrialEnabledValue])
		RTCInitializeSSL()
//		RTCSetupInternalTracer()
		RTCSetMinDebugLogLevel(.info);

		// have to make ourselves the delegate
		RTCAudioSession.sharedInstance().add(self)

		self.category = category
		self.options = options
		self.mode = mode
		self.portOverride = portOverride

		// add bluetooth to our options
		self.configureAudioSession()
		if notifications {
			self.setupNotifications()
		}
		if accessories {
			self.setupAccessories()
		}
		self.parseCurrentDevices()
		self.dump()
	}

	deinit {
		logger.log("RTCHardware.deinit")
		terminateNotifications()
		terminateAccessories()
	}

	public func makeCurrentInput(device: AVHardwareDevice) {
		logger.log("RTCHardware.makeCurrentInput() -> \(device.description)")

		// make sure it's not already current
//		guard !device.isCurrentDevice else { return }

		guard let input = device.portDescription else { return }
		let session = RTCAudioSession.sharedInstance()

		do {
			try session.setPreferredInput(input)
		} catch {
			logger.error("RTCHardware.makeCurrentInput() ERROR \(error.localizedDescription):")
		}
	}
/*
	public func resetCurrentInput() {
		logger.log("RTCHardware.resetCurrentInput()")

		guard let session = self.session else { return }

		do {
			try session.setPreferredInput(nil)
		} catch {
			logger.error("RTCHardware.resetCurrentInput() ERROR \(error.localizedDescription):")
		}
	}
*/
}

// MARK: Private methods
extension RTCHardware {

	fileprivate func configureAudioSession() {
		logger.log("RTCHardware.configureAudioSession()")

		let session = RTCAudioSession.sharedInstance()

		do {
			try session.setActive(false)

			session.lockForConfiguration()
			try session.setCategory(self.category, with: self.options)
			try session.setMode(self.mode)
			try session.setPreferredSampleRate(44100)
			try session.setPreferredInputNumberOfChannels(2)
			session.unlockForConfiguration()

			try session.setActive(true)

			logger.log("RTCHardware.configureAudioSession() SUCCESS")
		} catch {
			session.unlockForConfiguration()
			let errorString = "\(error)"
			logger.error("RTCHardware.configureAudioSession() ERROR -> \(errorString)")
		}
	}
}

// MARK: Notifications
extension RTCHardware {

	fileprivate func setupNotifications() {
		logger.log("RTCHardware.setupNotifications()")

		let session = RTCAudioSession.sharedInstance()
		let centre = NotificationCenter.default

		centre.addObserver(self, selector: #selector(handleInterruption(notification:)), name: AVAudioSession.interruptionNotification, object: session)
		centre.addObserver(self, selector: #selector(handleRouteChange(notification:)), name: AVAudioSession.routeChangeNotification, object: session)
		centre.addObserver(self, selector: #selector(handleSilenceSecondaryAudioHint(notification:)), name: AVAudioSession.silenceSecondaryAudioHintNotification, object: session)
		centre.addObserver(self, selector: #selector(handleMediaServicesWereLost(notification:)), name: AVAudioSession.mediaServicesWereLostNotification, object: session)
		centre.addObserver(self, selector: #selector(handleMediaServicesWereReset(notification:)), name: AVAudioSession.mediaServicesWereResetNotification, object: session)

		centre.addObserver(self, selector: #selector(accessoryConnected(notification:)), name:NSNotification.Name.EAAccessoryDidConnect, object: nil)
		centre.addObserver(self, selector: #selector(accessoryDisconnected(notification:)), name:NSNotification.Name.EAAccessoryDidDisconnect, object: nil)
	}

	fileprivate func setupAccessories() {
		logger.log("RTCHardware.setupAccessories()")

		let accessoryManager = EAAccessoryManager.shared()
		accessoryManager.registerForLocalNotifications()
	}

	fileprivate func terminateNotifications() {
		logger.log("RTCHardware.terminateNotifications()")

		let centre = NotificationCenter.default
		centre.removeObserver(self)

		let accessoryManager = EAAccessoryManager.shared()
		accessoryManager.unregisterForLocalNotifications()
	}

	fileprivate func terminateAccessories() {
		logger.log("RTCHardware.terminateAccessories()")

		let accessoryManager = EAAccessoryManager.shared()
		accessoryManager.unregisterForLocalNotifications()
	}

	@objc
	func handleInterruption(notification: Notification) {

		guard let userInfo = notification.userInfo,
			let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
			let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
				logger.log("RTCHardware.handleInterruption() ERROR")
				return
		}

		logger.log("RTCHardware.handleInterruption() \(type)")

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
		logger.log("RTCHardware.handleRouteChange() ERROR")
			return
		}

		logger.log("RTCHardware.handleRouteChange() \(reason)")

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
		logger.log("RTCHardware.handleSilenceSecondaryAudioHint()")
	}

	@objc
	func handleMediaServicesWereLost(notification: Notification) {
		logger.log("RTCHardware.handleMediaServicesWereLost()")
	}

	@objc
	func handleMediaServicesWereReset(notification: Notification) {
		logger.log("RTCHardware.handleMediaServicesWereReset()")

		parseCurrentDevices()
	}

	@objc
	func accessoryConnected(notification: Notification) {
		logger.log("RTCHardware.accessoryConnected()")

		parseCurrentDevices()
	}

	@objc
	func accessoryDisconnected(notification: Notification) {
		logger.log("RTCHardware.accessoryDisconnected()")

		parseCurrentDevices()
	}
}

// MARK: -
extension RTCHardware: RTCAudioSessionDelegate {
	public func audioSessionDidBeginInterruption(_ session: RTCAudioSession) {
		logger.log("RTCHardware.audioSessionDidBeginInterruption()")
	}

	public func audioSessionMediaServerReset(_ session: RTCAudioSession) {
		logger.log("RTCHardware.audioSessionMediaServerReset()")
	}

	public func audioSessionMediaServerTerminated(_ session: RTCAudioSession) {
		logger.log("RTCHardware.audioSessionMediaServerTerminated()")
	}

	public func audioSessionDidStopPlayOrRecord(_ session: RTCAudioSession) {
		logger.log("RTCHardware.audioSessionDidStopPlayOrRecord()")
	}

	public func audioSessionDidStartPlayOrRecord(_ session: RTCAudioSession) {
		logger.log("RTCHardware.audioSessionDidStartPlayOrRecord()")
	}

	public func audioSession(_ audioSession: RTCAudioSession, didSetActive active: Bool) {
		logger.log("RTCHardware.audioSession.didSetActive()")
	}

	public func audioSession(_ audioSession: RTCAudioSession, willSetActive active: Bool) {
		logger.log("RTCHardware.audioSession.willSetActive()")
	}

	public func audioSessionDidEndInterruption(_ session: RTCAudioSession, shouldResumeSession: Bool) {
		logger.log("RTCHardware.audioSessionDidEndInterruption()")
	}

	public func audioSession(_ audioSession: RTCAudioSession, didChangeOutputVolume outputVolume: Float) {
		logger.log("RTCHardware.audioSession.didChangeOutputVolume()")
	}

	public func audioSession(_ audioSession: RTCAudioSession, didDetectPlayoutGlitch totalNumberOfGlitches: Int64) {
		logger.log("RTCHardware.audioSession.didDetectPlayoutGlitch()")
	}

	public func audioSession(_ session: RTCAudioSession, didChangeCanPlayOrRecord canPlayOrRecord: Bool) {
		logger.log("RTCHardware.audioSession.didChangeCanPlayOrRecord()")
	}

	public func audioSession(_ audioSession: RTCAudioSession, failedToSetActive active: Bool, error: Error) {
		logger.log("RTCHardware.audioSession.failedToSetActive()")
	}

	public func audioSessionDidChangeRoute(_ session: RTCAudioSession, reason: AVAudioSession.RouteChangeReason, previousRoute: AVAudioSessionRouteDescription) {
		logger.log("RTCHardware.audioSessionDidChangeRoute()")
		parseCurrentDevices()
	}
}
