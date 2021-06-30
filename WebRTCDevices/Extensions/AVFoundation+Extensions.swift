//
//  AVFoundation+Extensions.swift
//  WebRTCDevices
//
//  Created by Colin Biggin on 2021-06-29.
//  Copyright © 2021 WhiteNile Systems Inc. All rights reserved.

//

import AVFoundation
import Foundation

extension AVAudioSession.RouteChangeReason: CustomStringConvertible {

	public var description: String {
		switch self {
			case .newDeviceAvailable: return ".newDeviceAvailable"
			case .oldDeviceUnavailable: return ".oldDeviceUnavailable"
			case .unknown: return ".unknown"
			case .categoryChange: return ".categoryChange"
			case .override: return ".override"
			case .wakeFromSleep: return ".wakeFromSleep"
			case .noSuitableRouteForCategory: return".noSuitableRouteForCategory"
			case .routeConfigurationChange: return ".routeConfigurationChange"
			@unknown default: return "@unknown default"
		}
	}
}

extension AVAudioSession.InterruptionType: CustomStringConvertible {

	public var description: String {
		switch self {
		case .began: return ".began"
		case .ended: return ".ended"
		@unknown default: return "@unknown default"
		}
	}
}

extension AVAudioSession.Category: CustomStringConvertible {

	public var description: String {
		switch self {
		case .ambient: return ".ambient"
		case .soloAmbient: return ".soloAmbient"
		case .playback: return ".playback"
		case .record: return ".record"
		case .playAndRecord: return ".playAndRecord"
		default:
			return "<???>"
		}
	}
}

extension AVAudioSession.CategoryOptions: CustomStringConvertible {

	public var description: String {
		switch self {
		case .mixWithOthers: return ".mixWithOthers"
		case .duckOthers: return ".duckOthers"
		case .allowBluetooth: return ".allowBluetooth"
		case .defaultToSpeaker: return ".defaultToSpeaker"
		case .interruptSpokenAudioAndMixWithOthers: return ".interruptSpokenAudioAndMixWithOthers"
		case .allowBluetoothA2DP: return ".allowBluetoothA2DP"
		case .allowAirPlay: return ".allowAirPlay"
		default:
			return "<???>"
		}
	}
}

extension AVAudioSession.Mode: CustomStringConvertible {

	public var description: String {
		switch self {
		case .`default`: return ".default"
		case .voiceChat: return ".voiceChat"
		case .gameChat: return ".gameChat"
		case .videoRecording: return ".videoRecording"
		case .measurement: return ".measurement"
		case .moviePlayback: return ".moviePlayback"
		case .videoChat: return ".videoChat"
		case .spokenAudio: return ".spokenAudio"
		case .voicePrompt: return ".voicePrompt"
		default:
			return "<???>"
		}
	}
}

extension AVAudioSession.PortOverride: CustomStringConvertible {

	public var description: String {
		switch self {
		case .none: return ".none"
		case .speaker: return ".speaker"
		default:
			return "<???>"
		}
	}
}
