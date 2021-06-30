//
//  HardwareSession.swift
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

public protocol HardwareSession: AnyObject {
	var audioSession: AVAudioSession? { get }

	var microphonesChanged: PassthroughSubject<Bool, Never> { get }
	var speakersChanged: PassthroughSubject<Bool, Never> { get }

	var availableInputs: [String: AVHardwareDevice] { get set }
	var currentInputs: [String: AVHardwareDevice] { get set }
	var currentOutputs: [String: AVHardwareDevice] { get set }

	var logger: Logger { get }

	func dump()
}

public extension HardwareSession {

	func available(hardwareType: AVHardwareDeviceType) -> [AVHardwareDevice] {
		logger.log("HardwareSession.available() -> \(hardwareType)")

		let devices = availableInputs.values.filter() {
			($0.hardwareType == hardwareType) || (hardwareType == .all)
		}

		let sortedDevices = devices.sorted(by: { (device1, device2) -> Bool in
			device1.name.lowercased() < device2.name.lowercased()
		})

		return sortedDevices
	}

	func parseCurrentDevices(_ sendChanges: Bool = true) {

		// access AVAudioSession directly
		guard let session = self.audioSession else { return }

		currentInputs.removeAll()
		session.currentRoute.inputs.forEach {
			currentInputs[$0.uid] = AVHardwareDevice(hardwareType: .microphone, with: $0, currentDevice: true)
		}

		currentOutputs.removeAll()
		session.currentRoute.outputs.forEach {
			currentOutputs[$0.uid] = AVHardwareDevice(hardwareType: .speaker, with: $0, currentDevice: true)
		}

		// save this to check if anything really changes
		let oldAvailableInputs = availableInputs

		availableInputs.removeAll()
		session.availableInputs?.forEach {
			// check if in currentInputs and if so, then set flag
			let isCurrentDevice = (currentInputs[$0.uid] != nil)
			availableInputs[$0.uid] = AVHardwareDevice(hardwareType: .microphone, with: $0, currentDevice: isCurrentDevice)
		}

		// so we *might* get a `.newDeviceAvailable` and it might not have actually changed
		// this seems to happen ALOT with Airpods Pro. So actually verified that it's changed
		var anythingActuallyChanged = false
		if oldAvailableInputs.count != availableInputs.count {
			anythingActuallyChanged = true
		} else {
			// since counts are the same, we know that if nothing changed, then EVERY `availableInputs` should also
			// have an entry in `oldAvailableInputs`
			for input in availableInputs.values {
				guard oldAvailableInputs[input.uuid] != nil else { continue }
				// AHA, this one is not in the old one so must have changed
				anythingActuallyChanged = true
				break
			}
		}

		dump()

		// inform there are changes
		if sendChanges && anythingActuallyChanged {
			microphonesChanged.send(true)
			speakersChanged.send(true)
		}
	}
	func dump() {

		let captureDevices = AVCaptureDevice.devices()
		let accessories = EAAccessoryManager.shared().connectedAccessories

		logger.log("HardwareSession.dump ------------------- SUMMARY -------------------")
		logger.log("HardwareSession.dump CURRENT INPUTS #\(self.currentInputs.count)")
		logger.log("HardwareSession.dump CURRENT OUTPUTS #\(self.currentOutputs.count)")
		logger.log("HardwareSession.dump AVAILABLE INPUTS #\(self.availableInputs.count)")
		logger.log("HardwareSession.dump CAPTURE DEVICES #\(captureDevices.count)")
		logger.log("HardwareSession.dump ACCESSORIES #\(accessories.count)")

		logger.log("HardwareSession.dump ------------------- INPUTS --------------------")
		for (index, source) in self.currentInputs.values.enumerated() {
			logger.log("HardwareSession.dump INPUT \(index): \(source.description)")
		}

		logger.log("HardwareSession.dump ------------------- OUTPUTS -------------------")
		for (index, source) in self.currentOutputs.values.enumerated() {
			logger.log("HardwareSession.dump OUTPUT \(index): \(source.description)")
		}

		logger.log("HardwareSession.dump ------------------ AVAILABLE ------------------")
		for (index, source) in self.availableInputs.values.enumerated() {
			logger.log("HardwareSession.dump AVAILABLE \(index): \(source.description)")
		}

		logger.log("HardwareSession.dump ------------------- DEVICES -------------------")
		for (index, device) in captureDevices.enumerated() {
			logger.log("HardwareSession.dump DEVICE \(index): \(device.description)")
		}

		logger.log("HardwareSession.dump ----------------- ACCESSORIES -----------------")
		for (index, device) in accessories.enumerated() {
			logger.log("HardwareSession.dump ACCESSORY \(index): \(device.description)")
		}

		logger.log("HardwareSession.dump -----------------------------------------------")
	}

}
