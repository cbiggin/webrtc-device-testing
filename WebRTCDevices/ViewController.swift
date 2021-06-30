//
//  ViewController.swift
//  WebRTCDevices
//
//  Created by Colin Biggin on 2021-06-29.
//  Copyright © 2021 WhiteNile Systems Inc. All rights reserved.
//

import AVFoundation
import Combine
import UIKit

class ViewController: UIViewController {

	@IBOutlet weak var avInitializeButton: UIButton?
	@IBOutlet weak var rtcInitializeButton: UIButton?
	@IBOutlet weak var debuggerDumpButton: UIButton?
	@IBOutlet weak var sessionResetButton: UIButton?

	@IBOutlet weak var recordButton: UIButton?
	@IBOutlet weak var recordingTimeLabel: UILabel?
	@IBOutlet weak var playButton: UIButton?
	@IBOutlet weak var playingTimeLabel: UILabel?

	@IBOutlet weak var deviceSelection: UISegmentedControl?
	@IBOutlet weak var deviceListing: UILabel?

	@IBOutlet weak var errorLabel: UILabel?

	// MARK: statics
	private let recordingFileName = "temp.m4A"

	// MARK: private variables
	private var subscriptions = [AnyCancellable]()

	private var rtcSession: RTCHardware? = nil
	private var avSession: AVHardware? = nil
	private var currentSession: HardwareSession? = nil

	private var recordingSession: AVAudioRecorder? = nil
	private var recordingTimer: Timer? = nil

	private var playingSession: AVAudioPlayer? = nil
	private var playingTimer: Timer? = nil

	private var devicesToList: AVHardwareDeviceType = .all

	override func viewDidLoad() {
		super.viewDidLoad()

		redoControls()
	}

	@IBAction func toggleRTCInitialize() {
		guard rtcSession == nil else { return }

		rtcSession = RTCHardware()
		currentSession = rtcSession
		setupSubscriptions()
		redoControls()
	}

	@IBAction func toggleAVInitialize() {
		guard avSession == nil else { return }

		avSession = AVHardware()
		currentSession = avSession
		setupSubscriptions()
		redoControls()
	}

	@IBAction func toggleDebuggerDump() {
		guard let session = self.currentSession else { return }
		session.dump()
	}

	@IBAction func toggleRecord() {

		setupRecorder()

		guard let session = recordingSession else {
			redoError("toggleRecord() ERROR: no `recordingSession`")

			redoControls()
			return
		}

		if session.isRecording {
			session.stop()
			stopRecordingTimer()
		} else {
			session.prepareToRecord()
			session.record()
			startRecordingTimer()
		}

		redoControls()
	}

	@IBAction func togglePlayRecording() {

		setupPlayer()

		guard let session = playingSession else {
			redoError("togglePlayRecording() ERROR: no `playingSession`")
			redoControls()
			return
		}

		if session.isPlaying {
			session.stop()
			stopPlayingTimer()
		} else {
			session.prepareToPlay()
			session.play()
			startPlayingTimer()
	}

		redoControls()
	}

	@IBAction func toggleReset() {
		resetEverything()
		redoControls()
	}

	@IBAction func toggleDeviceSelection(_ control: UISegmentedControl) {

		switch control.selectedSegmentIndex {
		case 0: devicesToList = .microphone
		case 1: devicesToList = .speaker
		case 2: devicesToList = .camera
		case 3: devicesToList = .all
		default:
			break
		}

		redoDeviceListing()
	}

	fileprivate func setupSubscriptions() {
		guard let session = currentSession, subscriptions.isEmpty else { return }

		let _ = session.microphonesChanged
			.sink(receiveValue: { _ in
					self.redoDeviceListing()
				})
			.store(in: &subscriptions)
	}

	fileprivate func setupRecorder() {
		guard recordingSession == nil else { return }

		if let session = playingSession, session.isPlaying {
			redoError("setupRecorder() ERROR: plyaing session in progress")
			return
		}
		// store it in documents somewhere
		guard let recordingURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(recordingFileName) else {
			redoError("setupRecorder() ERROR: could not set `recordingURL`")
			return
		}

		// some settings
		let settings: [String: Any] = [
			AVSampleRateKey: 44100.0,
			AVNumberOfChannelsKey: 1,
//			AVEncoderBitRateKey: NSNumber(integerLiteral: 16),
			AVEncoderAudioQualityKey: AVAudioQuality.low.rawValue
		]

		do {
			try recordingSession = AVAudioRecorder(url: recordingURL, settings: settings)
			recordingSession?.delegate = self
		} catch {
			redoError("setupRecorder() ERROR: AVAudioRecorder() failed: \(error)")
		}
	}

	fileprivate func setupPlayer() {
		guard playingSession == nil else { return }

		if let session = recordingSession, session.isRecording {
			redoError("setupPlayer() ERROR: recording session in progress")
			return
		}

		// store it in documents somewhere
		guard let recordingURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(recordingFileName) else {
			redoError("setupPlayer() ERROR: could not get `recordingURL`")
			return
		}

		do {
			try playingSession = AVAudioPlayer(contentsOf: recordingURL)
			playingSession?.delegate = self
		} catch {
			redoError("setupRecorder() ERROR: AVAudioRecorder() failed: \(error)")
		}
	}

	fileprivate func redoControls() {

		rtcInitializeButton?.applyButton( currentSession == nil )
		avInitializeButton?.applyButton( currentSession == nil )
		sessionResetButton?.applyButton( currentSession != nil )
		debuggerDumpButton?.applyButton( currentSession != nil )

		switch devicesToList {
		case .microphone: deviceSelection?.selectedSegmentIndex = 0
		case .speaker: deviceSelection?.selectedSegmentIndex = 1
		case .camera: deviceSelection?.selectedSegmentIndex = 2

		case .none: fallthrough
		case .all: deviceSelection?.selectedSegmentIndex = 3
		}

		if let button = recordButton {
			button.applyButton( currentSession != nil )
			var title = "RECORD"
			if let session = recordingSession, session.isRecording {
				title = "STOP"
			}
			button.setTitle(title, for: .normal)
		}

		if let label = recordingTimeLabel, let session = recordingSession {
			label.isHidden = !session.isRecording
		}

		if let button = playButton {
			button.applyButton( currentSession != nil )
			var title = "PLAY"
			if let session = playingSession, session.isPlaying {
				title = "STOP"
			}
			button.setTitle(title, for: .normal)
		}

		if let label = playingTimeLabel, let session = playingSession {
			label.isHidden = !session.isPlaying
		}

		redoDeviceListing()
	}

	fileprivate func redoDeviceListing() {

		guard let session = currentSession else {
			deviceListing?.text = "No active session"
			deviceListing?.textColor = UIColor.red
			return
		}

		let devices = session.available(hardwareType: devicesToList)
		guard !devices.isEmpty else {
			deviceListing?.text = "No devices found... HUH??"
			deviceListing?.textColor = UIColor.red
			return
		}

		var text = ""
		let separator = (devices.count > 1) ? "\n--------------------------\n" : ""
		for (index, device) in devices.enumerated() {
			text += "\(index+1): \(device)" + separator
		}
		deviceListing?.text = text
		deviceListing?.textColor = UIColor.darkGray
	}

	fileprivate func redoError(_ str: String) {
		guard !str.isEmpty else {
			errorLabel?.text = ""
			return
		}

		errorLabel?.textColor = UIColor.red
		errorLabel?.text = str
	}

	fileprivate func resetEverything() {

		rtcSession = nil
		avSession = nil
		currentSession = nil
		subscriptions.removeAll()

		recordingTimeLabel?.text = ""
		recordingTimer?.invalidate()
		recordingTimer = nil

		playingTimeLabel?.text = ""
		playingTimer?.invalidate()
		playingTimer = nil

		errorLabel?.text = ""

		redoControls()
	}
}

// MARK: Timer
extension ViewController {
	func startRecordingTimer() {
		guard recordingTimer == nil else { return }
		guard let session = recordingSession else { return }

		recordingTimeLabel?.text = ""
		recordingTimer = Timer.scheduledTimer(withTimeInterval:0.1, repeats: true) { [weak self] _ in
			DispatchQueue.main.async {
				self?.recordingTimeLabel?.text = session.currentTime.timingString()
			}
		}
	}

	func stopRecordingTimer() {
		recordingTimer?.invalidate()
		recordingTimer = nil
	}

	func startPlayingTimer() {
		guard playingTimer == nil else { return }
		guard let session = playingSession else { return }

		playingTimeLabel?.text = ""
		playingTimer = Timer.scheduledTimer(withTimeInterval:0.1, repeats: true) { [weak self] _ in
			DispatchQueue.main.async {
				let duration = session.duration.timingString()
				let timePlayed = session.currentTime.timingString()
				self?.playingTimeLabel?.text = timePlayed + " / " + duration
			}
		}
	}

	func stopPlayingTimer() {
		playingTimer?.invalidate()
		playingTimer = nil
	}
}

// MARK: - AVAudioRecorderDelegate
extension ViewController: AVAudioRecorderDelegate {

	func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
		let str = "AVAudioRecorderDelegate.audioRecorderEncodeErrorDidOccur() ERROR: \(String(describing: error))"
		redoError(str)
	}

	func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
		if !flag {
			let str = "AVAudioRecorderDelegate.audioRecorderDidFinishRecording(): UNSUCCESSFUL"
			redoError(str)
		}
		stopRecordingTimer()
		redoControls()
	}
}

// MARK: - AVAudioPlayerDelegate
extension ViewController: AVAudioPlayerDelegate {

	func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
		let str = "AVAudioPlayerDelegate.audioPlayerDecodeErrorDidOccur() ERROR: \(String(describing: error))"
		redoError(str)
	}

	func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
		if !flag {
			let str = "AVAudioPlayerDelegate.audioPlayerDidFinishPlaying(): UNSUCCESSFUL"
			redoError(str)
		}
		stopPlayingTimer()
		redoControls()
	}
}

// MARK: -
fileprivate extension UIButton {

	func applyButton(_ enabled: Bool) {

		let color = enabled ? UIColor.systemBlue : UIColor.gray
		layer.cornerRadius = 5.0
		layer.borderWidth = 2.0
		layer.borderColor = color.cgColor

		setTitleColor(UIColor.systemBlue, for: .normal)
		setTitleColor(UIColor.gray, for: .disabled)
		setTitleColor(UIColor.lightGray, for: .highlighted)

		self.isEnabled = enabled
	}
}

fileprivate extension TimeInterval {

	func timingString() -> String {

		let totalSeconds = Int(self)
		let minutes = totalSeconds / 60
		let seconds = totalSeconds - (minutes * 60)

		return String(format: "%d:%02d", minutes, seconds)
	}
}
