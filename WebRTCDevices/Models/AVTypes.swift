//
//  AVTypes.swift
//  WebRTCDevices
//
//  Created by Colin Biggin on 2021-06-29.
//  Copyright © 2021 WhiteNile Systems Inc. All rights reserved.
//

import AVFoundation
import Foundation

public enum AVHardwareDeviceType: String, CustomStringConvertible {
	case none
	case all

	case microphone
	case speaker
	case camera

	public var description: String { return self.rawValue }
}

public struct AVHardwareDevice: CustomStringConvertible {

	public var hardwareType: AVHardwareDeviceType = .none
	public var portDescription: AVAudioSessionPortDescription? = nil
	public var name: String = ""
	public var uid: String = ""
	public var portType: AVAudioSession.Port
	public var uuid: String = ""
	public var isCurrentDevice: Bool = false

	init(hardwareType: AVHardwareDeviceType, with portDescription: AVAudioSessionPortDescription, currentDevice: Bool = false) {
		self.hardwareType = hardwareType
		self.portDescription = portDescription
		self.name = portDescription.portName
		self.uid = portDescription.uid
		self.portType = portDescription.portType
		self.uuid = UUID().uuidString
		self.isCurrentDevice = currentDevice
	}

	public var description: String {
		return "\(self.hardwareType.rawValue.uppercased()): \(self.name) (\(self.portType.rawValue)), uid: \(self.uid), uuid: \(self.uuid), current: \(self.isCurrentDevice ? "YES" : "NO")"
	}
}

