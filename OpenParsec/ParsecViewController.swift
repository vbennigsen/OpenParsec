//
//  PoinerRegion.swift
//  OpenParsec
//
//  Created by s s on 2024/5/11.
//

import Foundation
import UIKit

class ParsecViewController :UIViewController, UIPointerInteractionDelegate, UIGestureRecognizerDelegate{
	var glkView: ParsecGLKViewController!
	var gamePadController: GamepadController!
	var touchController: TouchController!
	var u:UIImageView?
	var lastImg: CGImage?
	var backgroundTaskRunning = true
	let onBeforeRender: () -> Void
	override var prefersPointerLocked: Bool {
		return true
	}
	
	init(onBeforeRender: @escaping () -> Void) {
		self.onBeforeRender = onBeforeRender
		super.init(nibName: nil, bundle: nil)
		self.glkView = ParsecGLKViewController(viewController: self, updateImage: updateImage)
		self.gamePadController = GamepadController(viewController: self)
		self.touchController = TouchController(viewController: self)
		
		
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	func updateImage() {
		if CParsec.cursorImg != nil && !CParsec.cursorHidden {
			if lastImg != CParsec.cursorImg{
				u!.image = UIImage(cgImage: CParsec.cursorImg!)
				lastImg = CParsec.cursorImg!
			}
			let screenWidth = UIScreen.main.bounds.width
			let screenHeight = UIScreen.main.bounds.height
			
			u?.frame = CGRect(x: Int(CGFloat(CParsec.mouseX) * screenWidth) / Int(CParsec.hostWidth),
							  y: Int(CGFloat(CParsec.mouseY) * screenHeight) / Int(CParsec.hostHeight),
							  width: CParsec.cursorWidth / 2,
							  height: CParsec.cursorHeight / 2)
			
		} else {
			u?.image = nil
		}
	}
	
	override func viewDidLoad() {
		glkView.viewDidLoad()
		touchController.viewDidLoad()
		gamePadController.viewDidLoad()
		
		u = UIImageView(frame: CGRect(x: 0,y: 0,width: 100, height: 100))
		view.addSubview(u!)
		
		becomeFirstResponder()
		setNeedsUpdateOfPrefersPointerLocked()
		
		let pointerInteraction = UIPointerInteraction(delegate: self)
		view.addInteraction(pointerInteraction)
		
		view.isMultipleTouchEnabled = true
		view.isUserInteractionEnabled = true

		let panGestureRecognizer = UIPanGestureRecognizer(target:self, action:#selector(self.handlePanGesture(_:)))
		panGestureRecognizer.delegate = self
		view.addGestureRecognizer(panGestureRecognizer)

		
		
		// Add tap gesture recognizer for single-finger touch
		let singleFingerTapGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(handleSingleFingerTap(_:)))
		singleFingerTapGestureRecognizer.numberOfTouchesRequired = 1
		singleFingerTapGestureRecognizer.allowedTouchTypes = [0]
		view.addGestureRecognizer(singleFingerTapGestureRecognizer)

		// Add tap gesture recognizer for two-finger touch
		let twoFingerTapGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(handleTwoFingerTap(_:)))
		twoFingerTapGestureRecognizer.numberOfTouchesRequired = 2
		view.addGestureRecognizer(twoFingerTapGestureRecognizer)
//		view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
//		view.backgroundColor = UIColor(red: 0x66, green: 0xcc, blue: 0xff, alpha: 1.0)
		
		self.startBackgroundTask()
	}
	
	override func viewWillAppear(_ animated: Bool) {
		if let parent = parent {
			parent.setChildForHomeIndicatorAutoHidden(self)
			parent.setChildViewControllerForPointerLock(self)
		}
		setNeedsUpdateOfPrefersPointerLocked()
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		if let parent = parent {
			parent.setChildForHomeIndicatorAutoHidden(nil)
			parent.setChildViewControllerForPointerLock(nil)
		}
	}
	
	
	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		
		for press in presses {
			CParsec.sendKeyboardMessage(event:KeyBoardKeyEvent(input: press.key, isPressBegin: true) )
		}
			
	}
	
	override func pressesEnded (_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		
		for press in presses {
			CParsec.sendKeyboardMessage(event:KeyBoardKeyEvent(input: press.key, isPressBegin: false) )
		}
			
	}
	
	@objc func handlePanGesture(_ gestureRecognizer:UIPanGestureRecognizer)
	{
		if gestureRecognizer.numberOfTouches == 2 {
			let translation = gestureRecognizer.translation(in: gestureRecognizer.view)
			
			if abs( gestureRecognizer.velocity(in: gestureRecognizer.view).y) > 2 && abs(translation.y) > 10 {
				// Run your function when the user uses two fingers and swipes upwards
				CParsec.sendWheelMsg(x: 0, y: Int32(translation.y / 2))
				return
			}
			let location = gestureRecognizer.location(in:gestureRecognizer.view)
			touchController.onTouch(typeOfTap: 1, location: location, state: gestureRecognizer.state)
		}
		

	}

	@objc func handleSingleFingerTap(_ gestureRecognizer:UITapGestureRecognizer)
	{
		let location = gestureRecognizer.location(in:gestureRecognizer.view)
		touchController.onTap(typeOfTap: 1, location: location)

	}

	@objc func handleTwoFingerTap(_ gestureRecognizer:UITapGestureRecognizer)
	{
		let location = gestureRecognizer.location(in: gestureRecognizer.view)
		touchController.onTap(typeOfTap: 3, location: location)
	}
	
	func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
		return UIPointerStyle.hidden()
	}


	func pointerInteraction(_ inter: UIPointerInteraction, regionFor request: UIPointerRegionRequest, defaultRegion: UIPointerRegion) -> UIPointerRegion? {
		let loc = request.location
		if let iv = view!.hitTest(loc, with: nil) {
			let rect = view!.convert(iv.bounds, from: iv)
			let region = UIPointerRegion(rect: rect, identifier: iv.tag)
			return region
		}
		return nil
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		backgroundTaskRunning = false
	}
	
	func startBackgroundTask(){
		let item1 = DispatchWorkItem {
			while self.backgroundTaskRunning {
				CParsec.pollAudio()
			}
			
		}
		let item2 = DispatchWorkItem {
			while self.backgroundTaskRunning {
				CParsec.pollEvent()
				self.onBeforeRender()
			}
			
		}
		let mainQueue = DispatchQueue.global()
		mainQueue.async(execute: item1)
		mainQueue.async(execute: item2)
	}
	
}
