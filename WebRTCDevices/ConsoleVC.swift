//
//	ConsoleVC.swift
//  Cicero
//
//  Created by Colin Biggin on 2024-04-05.
//  Copyright © 2024 Stage TEN. All rights reserved.
//

import S10TJ
import UIKit

class ConsoleVC: UIViewController {

	// MARK: - outlets
	@IBOutlet weak var consoleSelection: UISegmentedControl!
	@IBOutlet weak var messages: UITextView!

	// MARK: - Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)

		refreshConsole()
	}

	// MARK: - IBActions
	@IBAction func toggleRefresh() {
		refreshConsole()
	}

	@IBAction func toggleConsoleSelection() {
		refreshConsole()
	}

	// MARK: - other
	fileprivate func setupControls() {
		redoControls()
	}

	fileprivate func redoControls() {
	}

	fileprivate func refreshConsole() {
		switch consoleSelection.selectedSegmentIndex {
		case 0: refreshAppConsole()
		case 1: refreshTJ()
		default:
			break
		}
	}

	fileprivate func refreshAppConsole() {
		guard let messages else { return }
		messages.text = AppLogging.loggingArchive
		messages.scrollToBottom()
	}

	fileprivate func refreshTJ() {
		guard let messages else { return }
		messages.text = TJLogging.loggingArchive
		messages.scrollToBottom()
	}
}

extension UIScrollView {
	func scrollToBottom(_ animated: Bool = false) {
		let bottomOffset = CGPoint(x: 0, y: contentSize.height - bounds.height + contentInset.bottom)
		setContentOffset(bottomOffset, animated: animated)
	}
}
