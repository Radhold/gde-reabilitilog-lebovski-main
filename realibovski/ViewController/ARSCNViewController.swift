//
//  ARSCNViewController.swift
//  Eye Tracking
//
//

import Foundation
import UIKit
import ARKit
import PinLayout

class ARSCNViewController: eyeViewController {
    
    var goal: Int = 2
    
    var flag = false
    
    var errors = 0
    
    var timeForTest = [UInt64]()
    var currentTime: DispatchTime!
    let scoreLabel: UILabel = {
        $0.text = "Score: 0"
        $0.font = UIFont(name: "Helvetica Neue", size: 28)
        return $0
    }(UILabel(frame: CGRect.zero))
    
    let firstIV: UIImageView = {
        $0.clipsToBounds = true
        $0.layer.masksToBounds = true
        $0.contentMode = .scaleAspectFit
        return $0
    }(UIImageView())
    
    let secondIV: UIImageView = {
        $0.clipsToBounds = true
        $0.layer.masksToBounds = true
        $0.contentMode = .scaleAspectFit
        return $0
    }(UIImageView())
    
    let thirdIV: UIImageView = {
        $0.clipsToBounds = true
        $0.layer.masksToBounds = true
        $0.contentMode = .scaleAspectFit
        return $0
    }(UIImageView())
    
    var score = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
        }
    }
    
    var count = 0 {
        didSet {
            if count == 30{
                showAlert()
                print(maxQue.max())
            }
        }
    }
	var sceneView: ARSCNView!
	let configuration = ARFaceTrackingConfiguration()
    var maxQue = [Int]()
    var que = 0
	var leftEyeNode: SCNNode = {
		let geometry = SCNCone(topRadius: 0.005, bottomRadius: 0, height: 0.1)
		geometry.radialSegmentCount = 3
		geometry.firstMaterial?.diffuse.contents = UIColor.red
		let node = SCNNode()
		node.geometry = geometry
		node.eulerAngles.x = -.pi / 2
		node.position.z = 0.1
		let parentNode = SCNNode()
		parentNode.addChildNode(node)
		return parentNode
	}()

	var rightEyeNode: SCNNode = {
		let geometry = SCNCone(topRadius: 0.005, bottomRadius: 0, height: 0.1)
		geometry.radialSegmentCount = 3
		geometry.firstMaterial?.diffuse.contents = UIColor.blue
		let node = SCNNode()
		node.geometry = geometry
		node.eulerAngles.x = -.pi / 2
		node.position.z = 0.1
		let parentNode = SCNNode()
		parentNode.addChildNode(node)
		return parentNode
	}()

	var endPointLeftEye: SCNNode = {
		let node = SCNNode()
		node.position.z = 2
		return node
	}()

	var endPointRightEye: SCNNode = {
		let node = SCNNode()
		node.position.z = 2
		return node
	}()
    
	var nodeInFrontOfScreen: SCNNode = {

		let screenGeometry = SCNPlane(width: 1, height: 1)
		screenGeometry.firstMaterial?.isDoubleSided = true
		screenGeometry.firstMaterial?.fillMode = .fill
		screenGeometry.firstMaterial?.diffuse.contents = UIColor.green.withAlphaComponent(0.5)

		let node = SCNNode()
		node.geometry = screenGeometry
		return node
	}()

	let crosshair = Crosshair(size: .init(width: 50, height: 50))

	var points: [CGPoint] = []

	override func viewDidLoad() {
		super.viewDidLoad()
        changeImage()
		guard ARFaceTrackingConfiguration.isSupported else {
			fatalError("Face tracking is not supported on this device")
		}
        currentTime = .now()
		setupARSCNView()
        crosshair.center = view.center
		//sceneView.scene.rootNode.addChildNode(nodeInFrontOfScreen)
		sceneView.pointOfView?.addChildNode(nodeInFrontOfScreen)
	}

    override func viewDidLayoutSubviews() {
        setupView()
        view.addSubview(crosshair)
    }
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		//sceneView.isHidden = true
		sceneView.session.run(configuration)
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)

		sceneView.session.pause()
	}

	fileprivate func setupARSCNView() {
		sceneView = ARSCNView()
		sceneView.delegate = self
		view.addSubview(sceneView)
		sceneView.contraintARSCNToSuperView()
	}
    func showAlert () {
        let alert = UIAlertController(title: "Конец", message: "Вы прошли тренинг. Ваш счет \(score)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ок", style: .default))
        present(alert, animated: true)
    }
    
    func hitTest(left: Float, right: Float) {

		var leftEyeLocation = CGPoint()
		var rightEyeLocation = CGPoint()
		let leftEyeResult = nodeInFrontOfScreen.hitTestWithSegment(from: endPointLeftEye.worldPosition,
														  to: leftEyeNode.worldPosition,
														  options: nil)

		let rightEyeResult = nodeInFrontOfScreen.hitTestWithSegment(from: endPointRightEye.worldPosition,
														  to: rightEyeNode.worldPosition,
														  options: nil)

		if leftEyeResult.count > 0 || rightEyeResult.count > 0 {

			guard let leftResult = leftEyeResult.first, let rightResult = rightEyeResult.first else {
				return
			}

			leftEyeLocation.x = CGFloat(leftResult.localCoordinates.x) / (Constants.Device.screenSize.width / 2) *
				Constants.Device.frameSize.width
			leftEyeLocation.y = CGFloat(leftResult.localCoordinates.y) / (Constants.Device.screenSize.height / 2) *
				Constants.Device.frameSize.height

			rightEyeLocation.x = CGFloat(rightResult.localCoordinates.x) / (Constants.Device.screenSize.width / 2) *
				Constants.Device.frameSize.width
			rightEyeLocation.y = CGFloat(rightResult.localCoordinates.y) / (Constants.Device.screenSize.height / 2) *
				Constants.Device.frameSize.height

			let point: CGPoint = {
				var point = CGPoint()
				let pointX = ((leftEyeLocation.x + rightEyeLocation.x) / 2)
				let pointY = -(leftEyeLocation.y + rightEyeLocation.y) / 2

				point.x = pointX.clamped(to: Constants.Ranges.widthRange)
				point.y = pointY.clamped(to: Constants.Ranges.heightRange)
				return point
			}()
            setNewPoint(point, left: left, right: right)
		}
	}

	fileprivate func setupView() {
        let height = self.sceneView.bounds.height
        let width = self.sceneView.bounds.width
        scoreLabel.pin(to: self.view).hCenter().top(self.view.pin.safeArea.top).sizeToFit()
        firstIV.pin(to: self.view).hCenter().top(self.view.pin.safeArea.top + 20).height(height/3 - 50).width(width/2)
        secondIV.pin(to: self.view).below(of: firstIV).hCenter().marginTop(20).height(height/3 - 50).width(width/2)
        thirdIV.pin(to: self.view).below(of: secondIV).hCenter().marginTop(20).height(height/3 - 50).width(width/2)
        
		
	}

    fileprivate func setNewPoint(_ point: CGPoint, left: Float, right: Float) {
		points.append(point)
		points = points.suffix(50).map {$0}

		DispatchQueue.main.async {
			UIView.animate(withDuration: 0.1, animations: {
				self.crosshair.center = self.points.average()
            })
                let height: Double = self.sceneView.bounds.height
                if left > 0.9 && right > 0.9 && self.flag == false {
                    self.count += 1
                    self.flag = true
                    self.timeForTest.append(DispatchTime.now().rawValue - self.currentTime.rawValue)
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2){
                        self.flag = false
                    }
                    if self.crosshair.center.y < height/3 {
                        if self.goal == 1{
                            self.score += 1
                            self.que += 1
                        }
                        else {
                            self.errors += 1
                            self.maxQue.append(self.que)
                            self.que = 0
                        }
                    }
                    else if self.crosshair.center.y > height/3 && self.crosshair.center.y < 2 * (height/3) {
                        if self.goal == 2 {
                            self.score += 1
                            self.que += 1
                        }
                        else {
                            self.errors += 1
                            self.maxQue.append(self.que)
                            self.que = 0
                        }
                    }
                    else if self.crosshair.center.y > 2 * (height/3) {
                        if self.goal == 3{
                            self.score += 1
                            self.que += 1
                        }
                        else {
                            self.errors += 1
                            self.maxQue.append(self.que)
                            self.que = 0
                        }
                    }
                    self.currentTime = DispatchTime.now()
                    self.changeImage()
                    
                }
			
		}
	}
    func changeImage() {
        goal = Int.random(in: 1...3)
        if goal == 1{
            DispatchQueue.main.async{
                UIView.animate(withDuration: 0.3, animations: {
                self.firstIV.image = UIImage(named: "triangle")
                self.secondIV.image = UIImage(named: "kvadr")
                self.thirdIV.image = UIImage(named: "kvadr")
                })
            }
        }
        else if goal == 2{
            DispatchQueue.main.async{
            UIView.animate(withDuration: 0.3, animations: {
            self.firstIV.image = UIImage(named: "kvadr")
            self.secondIV.image = UIImage(named: "triangle")
            self.thirdIV.image = UIImage(named: "kvadr")
            })
        }
        }
        else if goal == 3{
            DispatchQueue.main.async{
            UIView.animate(withDuration: 0.3, animations: {
                self.firstIV.image = UIImage(named: "kvadr")
                self.secondIV.image = UIImage(named: "kvadr")
                self.thirdIV.image = UIImage(named: "triangle")
            })
            }
        }
       }
}

extension ARSCNViewController: ARSCNViewDelegate {

	func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {

		guard let device = sceneView.device else {
			return nil
		}

		let faceGeometry = ARSCNFaceGeometry(device: device)
		let node = SCNNode(geometry: faceGeometry)
		node.geometry?.firstMaterial?.fillMode = .lines
		node.addChildNode(leftEyeNode)
		leftEyeNode.addChildNode(endPointLeftEye)
		node.addChildNode(rightEyeNode)
		rightEyeNode.addChildNode(endPointRightEye)

		return node
	}

	func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {

		guard let faceAnchor = anchor as? ARFaceAnchor,
			let faceGeometry = node.geometry as? ARSCNFaceGeometry else {
				return
		}
		leftEyeNode.simdTransform = faceAnchor.leftEyeTransform
		rightEyeNode.simdTransform = faceAnchor.rightEyeTransform
		faceGeometry.update(from: faceAnchor.geometry)
		hitTest(left: faceAnchor.blendShapes[.eyeBlinkLeft]?.floatValue ?? 0, right: faceAnchor.blendShapes[.eyeBlinkRight]?.floatValue ?? 0)
	}
}

extension UIView {
    public func pin(to addView: UIView) -> PinLayout<UIView> {
        if !addView.subviews.contains(self) {
            addView.addSubview(self)
        }
        return self.pin
    }
}
