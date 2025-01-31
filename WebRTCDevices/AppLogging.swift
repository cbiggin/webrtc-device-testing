//
//  AppLogging.swift
//  StageTEN Connect iOS
//
//  Created by Colin Biggin on 2021-03-30
//  Copyright © 2021 Stage TEN. All rights reserved.
//

import Foundation
import os

public enum AppLoggingSubsystem: String {
	case standard = "tv.stageten.webrtc-devices"
}

public enum AppLoggingCategory: String {
	case vc
	case hardware
	case avaudio
	case rtcaudio
	case tjaudio
}

///
/// This is a wrapper on top of Apple's new OSLog/Logger system which is only available in Xcode 12 & iOS 14
/// There could be some performance implications so if necessary all instances of:
///
///     var logger = JanusLogging(subsystem: JanusLoggingSubsystem.XXXX.rawValue, category: JanusLoggingCategory.XXXX.rawValue)
///
/// can be replaced with:
///
///     let logger = Logger(subsystem: JanusLoggingSubsystem.XXXX.rawValue, category: JanusLoggingCategory.XXXX.rawValue)
///

public struct AppLogging {

	public private(set) static var loggingArchive: String = ""
	public private(set) static var loggingCategories: Set<AppLoggingCategory> = []
	public private(set) static var loggingEnabled = false
	public private(set) static var loggingArchiveEnabled = false
	public private(set) static var dateFormatter: DateFormatter = DateFormatter()

	// might need for multiple instances of same class
	public var identifier: String = "" { didSet { identifier.isEmpty ? (loggingPrefix = "") : (loggingPrefix = "(" + identifier + "): ") } }

	private var subsystem: AppLoggingSubsystem = .standard
	private var category: AppLoggingCategory = .vc
//	private var logger: Logger
	private var loggingPrefix: String = ""

	public init(subsystem: AppLoggingSubsystem = .standard, category: AppLoggingCategory, identifier: String = "") {
		self.subsystem = subsystem
		self.category = category
		self.identifier = identifier
//		self.logger = Logger(subsystem: subsystem.rawValue, category: category.rawValue)
	}

	// log, trace, debug, info, notice, warning, error, critical, fault
	public func trace(_ str: String) {
		internalLog(level: .debug, emoji: "🟫 ", string: str)
	}

	public func debug(_ str: String) {
		internalLog(level: .debug, emoji: "🟦 ", string: str)
	}

	public func log(_ str: String) {
		internalLog(level: .default, emoji: "🟩 ", string: str)
	}

	public func notice(_ str: String) {
		internalLog(level: .default, emoji: "🔶 ", string: str)
	}

	public func warning(_ str: String) {
		internalLog(level: .error, emoji: "⚠️ ", string: str)
	}

	public func error(_ str: String) {
		internalLog(level: .error, emoji: "❌ ", string: str)
	}

	public func fault(_ str: String) {
		internalLog(level: .fault, emoji: "⛔️ ", string: str)
	}

	public func statistics(_ str: String) {
		internalLog(level: .default, emoji: "🩻 ", string: str)
	}

	public func timing(_ str: String) {
		internalLog(level: .default, emoji: "⏱️ ", string: str)
	}

	fileprivate func internalLog(level: OSLogType, emoji: String, string: String) {
		guard Self.loggingEnabled, Self.loggingCategories.contains(category) else { return }
//		logger.log(level: level, "\(emoji + loggingPrefix + string)")
		let str = emoji + Self.timestampString() + ": " + loggingPrefix + string
		print(str)

		// tack on to the end of our archive
		if Self.loggingArchiveEnabled {
			Self.loggingArchive += str + "\n"
		}
	}

	// MARK: public static methods
	public static func isSet(_ category: AppLoggingCategory) -> Bool {
		guard Self.loggingEnabled else { return false }
		return Self.loggingCategories.contains(category)
	}

	public static func setLoggingCategories(_ categories: [AppLoggingCategory]) {
		Self.loggingCategories.removeAll()
		categories.forEach {
			Self.loggingCategories.insert($0)
		}
	}

	public static func enable() {
		Self.loggingEnabled = true
		Self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
	}

	public static func disable() {
		Self.loggingEnabled = false
	}

	public static func isEnabled() -> Bool {
		return Self.loggingEnabled
	}

	public static func archiveEnable() {
		Self.loggingArchiveEnabled = true
	}

	public static func archiveDisable() {
		Self.loggingArchiveEnabled = false
	}

	public static func isArchiveEnabled() -> Bool {
		return Self.loggingArchiveEnabled
	}

	public static func timestampString() -> String {
		return Self.dateFormatter.string(from: Date())
	}
}
