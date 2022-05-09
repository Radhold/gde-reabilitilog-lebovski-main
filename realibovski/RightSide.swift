import Foundation
import UIKit
import ARKit
import PinLayout
import RxSwift

class RightSide: eyeViewController {
    
    enum Direction: String, CaseIterable {
        case up = "up"
        case down = "down"
        case right = "right"
        case left = "left"
        
    }
    
    var directions = [Direction]()
    
    var directionsCount = [Direction: Int]()
    
    var imageViews = [UIImageView]()
    
    let firstStack: UIStackView = {
        $0.axis = .horizontal
        $0.alignment = .top
        $0.distribution = .fillEqually
        $0.spacing = 8.0
        return $0
    }(UIStackView())
    
    let secondStack: UIStackView = {
        $0.axis = .horizontal
        $0.alignment = .top
        $0.distribution = .fillEqually
        $0.spacing = 8.0
        return $0
    }(UIStackView())
    
    let thirdStack: UIStackView = {
        $0.axis = .horizontal
        $0.alignment = .top
        $0.distribution = .fillEqually
        $0.spacing = 8.0
        return $0
    }(UIStackView())
    
    var goal: Direction = .up
    
    var flag = false
    
    var errors = 0
    let disposeBag = DisposeBag()
    
    var timeForTest = [Double]()
    var currentTime = CFAbsoluteTimeGetCurrent()
    let scoreLabel: UILabel = {
        $0.text = "Score: 0"
        $0.font = UIFont(name: "Helvetica Neue", size: 28)
        return $0
    }(UILabel(frame: CGRect.zero))
    
    var score = 0 {
        didSet {
            scoreLabel.text = "Score: \(score)"
        }
    }
    
    var count = 0 {
        didSet {
            if count == 10{
                
//                showAlert()
                StatsService.sendRightSideStats(stats: EyeStatsDTO(
                    errorCount: errors,
                    timeForAction: timeForTest,
                    maxQue: maxQue.max() ?? 0,
                    score: score)
                ).subscribe(on: ConcurrentDispatchQueueScheduler(qos: .background))
                    .observe(on: MainScheduler.instance)
                    .subscribe(onSuccess: { [weak self] response in
                    }, onFailure: { [weak self] error in
                            return
                        }
                    )
                    .disposed(by: disposeBag)
                print(maxQue.max())
                navigationController?.popViewController(animated: true)
                
                
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
        for i in (0...8) {
            let imageView = UIImageView()
//            imageView.image = UIImage(named: "up")
            imageViews.append(imageView)
            switch i {
            case 0...2: firstStack.addArrangedSubview(imageView)
            case 3...5: secondStack.addArrangedSubview(imageView)
            case 6...8: thirdStack.addArrangedSubview(imageView)
            default:
                break
            }

        }
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            changeArrows()
//        }
        guard ARFaceTrackingConfiguration.isSupported else {
            fatalError("Face tracking is not supported on this device")
        }
        currentTime = CFAbsoluteTimeGetCurrent()
        setupARSCNView()
        crosshair.center = view.center
        //sceneView.scene.rootNode.addChildNode(nodeInFrontOfScreen)
        sceneView.pointOfView?.addChildNode(nodeInFrontOfScreen)
    }
    
    override func viewDidLayoutSubviews() {
        view.addSubview(crosshair)
        setupView()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
//        navigationController?.isNavigationBarHidden = true
        navigationController?.hidesBarsOnSwipe = true
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
        let leftEyeResult = nodeInFrontOfScreen.hitTestWithSegment(
            from: endPointLeftEye.worldPosition,
            to: leftEyeNode.worldPosition,
            options: nil)
        
        let rightEyeResult = nodeInFrontOfScreen.hitTestWithSegment(
            from: endPointRightEye.worldPosition,
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
    
    fileprivate func setNewPoint(_ point: CGPoint, left: Float, right: Float) {
        points.append(point)
        points = points.suffix(50).map {$0}
        
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.1, animations: {
                self.crosshair.center = self.points.average()
            })
            let width = self.view.bounds.width
            let height: Double = self.view.bounds.height
            if left > 0.9 && right > 0.9 && self.flag == false {
                self.count += 1
                self.flag = true
                self.timeForTest.append(CFAbsoluteTimeGetCurrent() - self.currentTime)
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.2){
                    self.flag = false
                }
                if self.crosshair.center.y < height/3 {
                    if self.goal == .up{
                        self.score += 1
                        self.que += 1
                    }
                    else {
                        self.errors += 1
                        self.maxQue.append(self.que)
                        self.que = 0
                    }
                }
                else if self.crosshair.center.y > height/3 && self.crosshair.center.y < 2 * (height/3) && self.crosshair.center.x > width/2 {
                    if self.goal == .right {
                        self.score += 1
                        self.que += 1
                    }
                    else {
                        self.errors += 1
                        self.maxQue.append(self.que)
                        self.que = 0
                    }
                }
                else if self.crosshair.center.y > height/3 && self.crosshair.center.y < 2 * (height/3) && self.crosshair.center.x < width/2 {
                    if self.goal == .left {
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
                    if self.goal == .down{
                        self.score += 1
                        self.que += 1
                    }
                    else {
                        self.errors += 1
                        self.maxQue.append(self.que)
                        self.que = 0
                    }
                }
                self.currentTime = CFAbsoluteTimeGetCurrent()
                self.changeArrows()
            }
            
        }
    }
    func setupView() {
        let height = self.view.bounds.height
        let width = self.view.bounds.width
        let middleLine = UIView(frame: CGRect(x: 0, y: 0, width: 2, height: height/2))
        let upLine =  UIView(frame: CGRect(x: 0, y: 0, width: width, height: 2))
        let downLine = UIView(frame: CGRect(x: 0, y: 0, width: width, height: 2))
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.scoreLabel.pin(to: self.view).hCenter().top(self.view.pin.safeArea.top).sizeToFit()
            middleLine.pin(to: self.view).center()
            downLine.pin(to: self.view).bottom(25%)
            upLine.pin(to: self.view).top(25%)
            
            self.secondStack.pin(to: self.view).center().width(width * 0.75).height(100)
            self.firstStack.pin(to: self.view).above(of: self.secondStack).marginTop(0).hCenter().width(width * 0.75).height(100)
            self.thirdStack.pin(to: self.view).below(of: self.secondStack).hCenter().width(width * 0.75).height(100)
            
            self.view.bringSubviewToFront(self.secondStack)
            self.view.bringSubviewToFront(self.firstStack)
            self.view.bringSubviewToFront(self.thirdStack)
        }
        middleLine.backgroundColor = .cyan
        upLine.backgroundColor = .cyan
        downLine.backgroundColor = .cyan
        
    }
    
    func changeArrows() {
        directions = []
        directionsCount.removeAll()
        directions = (1...9).map {_ in
            let element = Direction.allCases.randomElement() ?? .up
            directionsCount[element] = (directionsCount[element] ?? 0) + 1
            return element
        }
        
        let max = directionsCount.values.max()
        
        
        let maxDirection: Direction = directionsCount.keys.first {
            directionsCount[$0] == max
        } ?? .up
        directionsCount.forEach {
            if maxDirection != $0.key {
                if max == $0.value {
                    let first = directions.firstIndex { $0 != maxDirection}
                    directions[first ?? 0] = maxDirection
                }
            }
        }
        goal = maxDirection
        DispatchQueue.main.async { [weak self] in
            for number in (0...8) {
                self?.imageViews[number].image = UIImage(named: self?.directions[number].rawValue ?? "up")
            }
        }
        
    }
}


extension RightSide: ARSCNViewDelegate {
    
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
