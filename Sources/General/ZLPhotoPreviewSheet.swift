//
//  ZLPhotoPreviewSheet.swift
//  ZLPhotoBrowser
//
//  Created by long on 2020/8/11.
//
//  Copyright (c) 2020 Long Zhang <longitachi@163.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import UIKit
import Photos

public class ZLPhotoPreviewSheet: UIView {

    struct Layout {
        
        static let colH: CGFloat = 155
        
        static let btnH: CGFloat = 45
        
        static let spacing: CGFloat = 1 / UIScreen.main.scale
        
    }
    
    private var baseView: UIView!
    
    private var collectionView: UICollectionView!
    
    private var cameraBtn: UIButton!
    
    private var photoLibraryBtn: UIButton!
    
    private var cancelBtn: UIButton!
    
    private var flexibleView: UIView!
    
    private var placeholderLabel: UILabel!
    
    private var arrDataSources: [ZLPhotoModel] = []
    
    private var arrSelectedModels: [ZLPhotoModel] = []
    
    private var preview = false
    
    private var animate = true
    
    private var senderTabBarIsHidden: Bool?
    
    private var baseViewHeight: CGFloat = 0
    
    private var isSelectOriginal = false
    
    private var panBeginPoint: CGPoint = .zero
    
    private var panImageView: UIImageView?
    
    private var panModel: ZLPhotoModel?
    
    private var panCell: ZLThumbnailPhotoCell?
    
    private weak var sender: UIViewController?
    
    private var fetchImageQueue: OperationQueue = OperationQueue()
    
    /// 解析成功的照片回调  参数为: 1.解析好的图片 2.对应asset 3.是否原图
    @objc public var selectImageBlock: ( ([UIImage], [PHAsset], Bool) -> Void )?
    
    /// 解析失败的照片回调  参数: 1.失败的asset 2.对应的下标
    @objc public var selectImageRequestErrorBlock: ( ([PHAsset], [Int]) -> Void )?
    
    /// 取消选择回调
    @objc public var cancelBlock: ( () -> Void )?
    
    deinit {
        zl_debugPrint("ZLPhotoPreviewSheet deinit")
    }
    
    @objc public init(selectedAssets: [PHAsset] = []) {
        super.init(frame: .zero)
        
        if !ZLPhotoConfiguration.default().allowSelectImage &&
            !ZLPhotoConfiguration.default().allowSelectVideo {
            assert(false, "参数配置错误")
            ZLPhotoConfiguration.default().allowSelectImage = true
        }
        
        let models = selectedAssets.map { (asset) -> ZLPhotoModel in
            let m = ZLPhotoModel(asset: asset)
            m.isSelected = true
            return m
        }
        self.arrSelectedModels.append(contentsOf: models)
        
        self.fetchImageQueue.maxConcurrentOperationCount = 3
        self.setupUI()
        
        self.arrSelectedModels.removeAll()
        selectedAssets.forEach { (asset) in
            if !ZLPhotoConfiguration.default().allowMixSelect, asset.mediaType == .video {
                return
            }
            
            let m = ZLPhotoModel(asset: asset)
            m.isSelected = true
            self.arrSelectedModels.append(m)
        }
    }
    
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        self.baseView.frame = CGRect(x: 0, y: self.bounds.height - self.baseViewHeight, width: self.bounds.width, height: self.baseViewHeight)
        
        var btnY: CGFloat = 0
        if ZLPhotoConfiguration.default().maxPreviewCount > 0 {
            self.collectionView.frame = CGRect(x: 0, y: 0, width: self.bounds.width, height: ZLPhotoPreviewSheet.Layout.colH)
            btnY += (self.collectionView.frame.maxY + ZLPhotoPreviewSheet.Layout.spacing)
        }
        if self.canShowCameraBtn() {
            self.cameraBtn.frame = CGRect(x: 0, y: btnY, width: self.bounds.width, height: ZLPhotoPreviewSheet.Layout.btnH)
            btnY += (ZLPhotoPreviewSheet.Layout.btnH + ZLPhotoPreviewSheet.Layout.spacing)
        }
        self.photoLibraryBtn.frame = CGRect(x: 0, y: btnY, width: self.bounds.width, height: ZLPhotoPreviewSheet.Layout.btnH)
        btnY += (ZLPhotoPreviewSheet.Layout.btnH + ZLPhotoPreviewSheet.Layout.spacing)
        self.cancelBtn.frame = CGRect(x: 0, y: btnY, width: self.bounds.width, height: ZLPhotoPreviewSheet.Layout.btnH)
        btnY += ZLPhotoPreviewSheet.Layout.btnH
        self.flexibleView.frame = CGRect(x: 0, y: btnY, width: self.bounds.width, height: self.baseViewHeight - btnY)
    }
    
    func setupUI() {
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.backgroundColor = .previewBgColor
        
        let showCameraBtn = self.canShowCameraBtn()
        var bh: CGFloat = 0
        if ZLPhotoConfiguration.default().maxPreviewCount > 0 {
            bh += ZLPhotoPreviewSheet.Layout.colH
        }
        bh += (ZLPhotoPreviewSheet.Layout.spacing + ZLPhotoPreviewSheet.Layout.btnH) * (showCameraBtn ? 3 : 2)
        bh += deviceSafeAreaInsets().bottom
        self.baseViewHeight = bh
        
        self.baseView = UIView()
        self.baseView.backgroundColor = zlRGB(230, 230, 230)
        self.addSubview(self.baseView)
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 3
        layout.minimumLineSpacing = 3
        layout.sectionInset = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        self.collectionView.backgroundColor = .previewBtnBgColor
        self.collectionView.delegate = self
        self.collectionView.dataSource = self
        self.collectionView.isHidden = ZLPhotoConfiguration.default().maxPreviewCount == 0
        ZLThumbnailPhotoCell.zl_register(self.collectionView)
        self.baseView.addSubview(self.collectionView)
        
        self.placeholderLabel = UILabel()
        self.placeholderLabel.font = getFont(15)
        self.placeholderLabel.text = localLanguageTextValue(.noPhotoTips)
        self.placeholderLabel.textAlignment = .center
        self.placeholderLabel.textColor = .previewBtnTitleColor
        self.collectionView.backgroundView = self.placeholderLabel
        
        func createBtn(_ title: String) -> UIButton {
            let btn = UIButton(type: .custom)
            btn.backgroundColor = .previewBtnBgColor
            btn.setTitleColor(.previewBtnTitleColor, for: .normal)
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = getFont(17)
            return btn
        }
        
        let cameraTitle: String
        if !ZLPhotoConfiguration.default().allowSelectImage, ZLPhotoConfiguration.default().allowRecordVideo {
            cameraTitle = localLanguageTextValue(.previewCameraRecord)
        } else {
            cameraTitle = localLanguageTextValue(.previewCamera)
        }
        self.cameraBtn = createBtn(cameraTitle)
        self.cameraBtn.isHidden = !showCameraBtn
        self.cameraBtn.addTarget(self, action: #selector(cameraBtnClick), for: .touchUpInside)
        self.baseView.addSubview(self.cameraBtn)
        
        self.photoLibraryBtn = createBtn(localLanguageTextValue(.previewAlbum))
        self.photoLibraryBtn.addTarget(self, action: #selector(photoLibraryBtnClick), for: .touchUpInside)
        self.baseView.addSubview(self.photoLibraryBtn)
        
        self.cancelBtn = createBtn(localLanguageTextValue(.previewCancel))
        self.cancelBtn.addTarget(self, action: #selector(cancelBtnClick), for: .touchUpInside)
        self.baseView.addSubview(self.cancelBtn)
        
        self.flexibleView = UIView()
        self.flexibleView.backgroundColor = .previewBtnBgColor
        self.baseView.addSubview(self.flexibleView)
        
        if ZLPhotoConfiguration.default().allowDragSelect {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(panSelectAction(_:)))
            self.baseView.addGestureRecognizer(pan)
        }
    }
    
    func canShowCameraBtn() -> Bool {
        if !ZLPhotoConfiguration.default().allowSelectImage, !ZLPhotoConfiguration.default().allowRecordVideo {
            return false
        }
        return true
    }
    
    @objc public func showPreview(animate: Bool = true, sender: UIViewController) {
        self.show(preview: true, animate: animate, sender: sender)
    }
    
    @objc public func showPhotoLibrary(sender: UIViewController) {
        self.show(preview: false, animate: false, sender: sender)
    }
    
    /// 传入已选择的assets，并预览
    @objc public func previewAssets(sender: UIViewController, assets: [PHAsset], index: Int, isOriginal: Bool, showBottomViewAndSelectBtn: Bool = true) {
        let models = assets.map { (asset) -> ZLPhotoModel in
            let m = ZLPhotoModel(asset: asset)
            m.isSelected = true
            return m
        }
        self.arrSelectedModels.removeAll()
        self.arrSelectedModels.append(contentsOf: models)
        self.sender = sender
        self.isSelectOriginal = isOriginal
        self.isHidden = true
        self.sender?.view.addSubview(self)
        
        let vc = ZLPhotoPreviewViewController(photos: models, index: index)
        let nav = self.getImageNav(rootViewController: vc)
        vc.backBlock = { [weak self] in
            self?.hide()
        }
        self.sender?.showDetailViewController(nav, sender: nil)
    }
    
    func show(preview: Bool, animate: Bool, sender: UIViewController) {
        self.preview = preview
        self.animate = animate
        self.sender = sender
        
        let status = PHPhotoLibrary.authorizationStatus()
        if status == .restricted || status == .denied {
            showAlertView(String(format: localLanguageTextValue(.noPhotoLibratyAuthority), getAppName()), self.sender)
        } else if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization { (status) in
                DispatchQueue.main.async {
                    if status == .denied {
                        showAlertView(String(format: localLanguageTextValue(.noPhotoLibratyAuthority), getAppName()), self.sender)
                    } else if status == .authorized {
                        if self.preview {
                            self.loadPhotos()
                            self.show()
                        } else {
                            self.photoLibraryBtnClick()
                        }
                    }
                }
            }
            
            self.sender?.view.addSubview(self)
        } else {
            if preview {
                self.loadPhotos()
                self.show()
            } else {
                self.sender?.view.addSubview(self)
                self.photoLibraryBtnClick()
            }
        }
    }
    
    func loadPhotos() {
        self.arrDataSources.removeAll()
        
        let config = ZLPhotoConfiguration.default()
        ZLPhotoManager.getCameraRollAlbum(allowSelectImage: config.allowSelectImage, allowSelectVideo: config.allowSelectVideo) { [weak self] (cameraRoll) in
            guard let `self` = self else { return }
            var totalPhotos = ZLPhotoManager.fetchPhoto(in: cameraRoll.result, ascending: false, allowSelectImage: config.allowSelectImage, allowSelectVideo: config.allowSelectVideo, limitCount: config.maxPreviewCount)
            markSelected(source: &totalPhotos, selected: &self.arrSelectedModels)
            self.arrDataSources.append(contentsOf: totalPhotos)
            self.collectionView.reloadData()
        }
    }
    
    func show() {
        self.frame = self.sender?.view.bounds ?? .zero
        
        self.collectionView.contentOffset = .zero
        
        if self.superview == nil {
            self.sender?.view.addSubview(self)
        }
        
        if let tabBar = self.sender?.tabBarController?.tabBar, !tabBar.isHidden {
            self.senderTabBarIsHidden = tabBar.isHidden
            tabBar.isHidden =  true
        }
        
        if self.animate {
            self.backgroundColor = UIColor.previewBgColor.withAlphaComponent(0)
            var frame = self.baseView.frame
            frame.origin.y = self.bounds.height
            self.baseView.frame = frame
            UIView.animate(withDuration: 0.2) {
                self.backgroundColor = UIColor.previewBgColor
                frame.origin.y -= self.baseViewHeight
                self.baseView.frame = frame
            }
        }
    }
    
    func hide() {
        if self.animate {
            
            var frame = self.baseView.frame
            frame.origin.y += self.baseViewHeight
            UIView.animate(withDuration: 0.2, animations: {
                self.backgroundColor = UIColor.previewBgColor.withAlphaComponent(0)
                self.baseView.frame = frame
            }) { (_) in
                self.isHidden = true
                self.removeFromSuperview()
            }
        } else {
            self.isHidden = true
            self.removeFromSuperview()
        }
        
        if let temp = self.senderTabBarIsHidden {
            self.sender?.tabBarController?.tabBar.isHidden = temp
        }
    }
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.randomElement()
        guard let location = touch?.location(in: self) else {
            return
        }
        
        if !self.baseView.frame.contains(location) {
            self.hide()
        }
    }
    
    @objc func cameraBtnClick() {
        let config = ZLPhotoConfiguration.default()
        if config.useCustomCamera {
            let camera = ZLCustomCamera()
            camera.takeDoneBlock = { [weak self] (image, videoUrl) in
                self?.save(image: image, videoUrl: videoUrl)
            }
            self.sender?.showDetailViewController(camera, sender: nil)
        } else {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                let picker = UIImagePickerController()
                picker.delegate = self
                picker.allowsEditing = false
                picker.videoQuality = .typeHigh
                picker.sourceType = .camera
                picker.cameraFlashMode = config.cameraFlashMode.imagePickerFlashMode
                var mediaTypes = [String]()
                if config.allowSelectImage {
                    mediaTypes.append("public.image")
                }
                if config.allowRecordVideo {
                    mediaTypes.append("public.movie")
                }
                picker.mediaTypes = mediaTypes
                picker.videoMaximumDuration = TimeInterval(config.maxRecordDuration)
                self.sender?.showDetailViewController(picker, sender: nil)
            } else {
                showAlertView(localLanguageTextValue(.cameraUnavailable), self.sender)
            }
        }
    }
    
    @objc func photoLibraryBtnClick() {
        self.animate = false
        self.showThumbnailViewController()
    }
    
    @objc func cancelBtnClick() {
        guard !self.arrSelectedModels.isEmpty else {
            self.cancelBlock?()
            self.hide()
            return
        }
        self.requestSelectPhoto()
    }
    
    @objc func panSelectAction(_ pan: UIPanGestureRecognizer) {
        let point = pan.location(in: self.collectionView)
        if pan.state == .began {
            let cp = self.baseView.convert(point, from: self.collectionView)
            guard self.collectionView.frame.contains(cp) else {
                self.panBeginPoint = .zero
                return
            }
            self.panBeginPoint = point
        } else if pan.state == .changed {
            guard self.panBeginPoint != .zero else {
                return
            }
            
            guard let indexPath = self.collectionView.indexPathForItem(at: self.panBeginPoint) else {
                return
            }
            
            if self.panImageView == nil {
                // 必须向上拖动
                guard point.y < self.panBeginPoint.y else {
                    return
                }
                guard let cell = self.collectionView.cellForItem(at: indexPath) as? ZLThumbnailPhotoCell else {
                    return
                }
                self.panModel = self.arrDataSources[indexPath.row]
                self.panCell = cell
                self.panImageView = UIImageView(frame: cell.bounds)
                self.panImageView?.contentMode = .scaleAspectFill
                self.panImageView?.clipsToBounds = true
                self.panImageView?.image = cell.imageView.image
                cell.imageView.image = nil
                self.addSubview(self.panImageView!)
            }
            self.panImageView?.center = self.convert(point, from: self.collectionView)
        } else if pan.state == .cancelled || pan.state == .ended {
            guard let pv = self.panImageView else {
                return
            }
            let pvRect = self.baseView.convert(pv.frame, from: self)
            var callBack = false
            if pvRect.midY < -10 {
                self.arrSelectedModels.removeAll()
                self.arrSelectedModels.append(self.panModel!)
                self.requestSelectPhoto()
                callBack = true
            }
            
            self.panModel = nil
            if !callBack {
                let toRect = self.convert(self.panCell?.frame ?? .zero, from: self.collectionView)
                UIView.animate(withDuration: 0.25, animations: {
                    self.panImageView?.frame = toRect
                }) { (_) in
                    self.panCell?.imageView.image = self.panImageView?.image
                    self.panCell = nil
                    self.panImageView?.removeFromSuperview()
                    self.panImageView = nil
                }
            } else {
                self.panCell?.imageView.image = self.panImageView?.image
                self.panImageView?.removeFromSuperview()
                self.panImageView = nil
                self.panCell = nil
            }
        }
    }
    
    func requestSelectPhoto(viewController: UIViewController? = nil) {
        let hud = ZLProgressHUD(style: ZLPhotoConfiguration.default().hudStyle)
        
        var timeout = false
        hud.timeoutBlock = {
            showAlertView(localLanguageTextValue(.timeout), self.sender)
            self.fetchImageQueue.cancelAllOperations()
            timeout = true
        }
        
        hud.show(timeout: ZLPhotoConfiguration.default().timeout)
        
        guard ZLPhotoConfiguration.default().shouldAnialysisAsset else {
            hud.hide()
            self.selectImageBlock?([], self.arrSelectedModels.map { $0.asset }, self.isSelectOriginal)
            self.arrSelectedModels.removeAll()
            self.hide()
            viewController?.dismiss(animated: true, completion: nil)
            return
        }
        
        var images: [UIImage?] = Array(repeating: nil, count: self.arrSelectedModels.count)
        var assets: [PHAsset?] = Array(repeating: nil, count: self.arrSelectedModels.count)
        var errorAssets: [PHAsset] = []
        var errorIndexs: [Int] = []
        
        var sucCount = 0
        let totalCount = self.arrSelectedModels.count
        for (i, m) in self.arrSelectedModels.enumerated() {
            let operation = ZLFetchImageOperation(model: m, isOriginal: self.isSelectOriginal) { [weak self] (image, asset) in
                guard !timeout else { return }
                
                sucCount += 1
                
                if let image = image {
                    images[i] = image
                    assets[i] = asset ?? m.asset
                    zl_debugPrint("---- suc request \(i)")
                } else {
                    errorAssets[i] = m.asset
                    errorIndexs[i] = i
                    zl_debugPrint("---- failed request \(i)")
                }
                
                guard sucCount >= totalCount else { return }
                let sucImages = images.compactMap { $0 }
                let sucAssets = assets.compactMap { $0 }
                hud.hide()
                
                self?.selectImageBlock?(sucImages, sucAssets, self?.isSelectOriginal ?? false)
                self?.arrSelectedModels.removeAll()
                if !errorAssets.isEmpty {
                    self?.selectImageRequestErrorBlock?(errorAssets, errorIndexs)
                }
                self?.arrDataSources.removeAll()
                self?.hide()
                viewController?.dismiss(animated: true, completion: nil)
            }
            self.fetchImageQueue.addOperation(operation)
        }
    }
    
    func showThumbnailViewController() {
        ZLPhotoManager.getCameraRollAlbum(allowSelectImage: ZLPhotoConfiguration.default().allowSelectImage, allowSelectVideo: ZLPhotoConfiguration.default().allowSelectVideo) { [weak self] (cameraRoll) in
            guard let `self` = self else { return }
            let nav: ZLImageNavController
            if ZLPhotoConfiguration.default().style == .embedAlbumList {
                let tvc = ZLThumbnailViewController(albumList: cameraRoll)
                nav = self.getImageNav(rootViewController: tvc)
            } else {
                nav = self.getImageNav(rootViewController: ZLAlbumListController())
                let tvc = ZLThumbnailViewController(albumList: cameraRoll)
                nav.pushViewController(tvc, animated: true)
            }
            self.sender?.showDetailViewController(nav, sender: nil)
        }
    }
    
    func showPreviewController(_ models: [ZLPhotoModel], index: Int) {
        let vc = ZLPhotoPreviewViewController(photos: models, index: index)
        let nav = self.getImageNav(rootViewController: vc)
        vc.backBlock = { [weak self, weak nav] in
            guard let `self` = self else { return }
            self.isSelectOriginal = nav?.isSelectedOriginal ?? false
            self.arrSelectedModels.removeAll()
            self.arrSelectedModels.append(contentsOf: nav?.arrSelectedModels ?? [])
            markSelected(source: &self.arrDataSources, selected: &self.arrSelectedModels)
            self.collectionView.reloadItems(at: self.collectionView.indexPathsForVisibleItems)
            self.changeCancelBtnTitle()
        }
        self.sender?.showDetailViewController(nav, sender: nil)
    }
    
    func showEditImageVC(model: ZLPhotoModel) {
        let hud = ZLProgressHUD(style: ZLPhotoConfiguration.default().hudStyle)
        hud.show()
        
        let asset = model.asset
        let w = min(UIScreen.main.bounds.width, ZLMaxImageWidth) * 2
        let size = CGSize(width: w, height: w * CGFloat(asset.pixelHeight) / CGFloat(asset.pixelWidth))
        hud.show()
        ZLPhotoManager.fetchImage(for: asset, size: size) { [weak self] (image, isDegraded) in
            if !isDegraded {
                if let image = image {
                    let vc = ZLEditImageViewController(image: image)
                    vc.editFinishBlock = { [weak self] (image) in
                        model.isSelected = true
                        model.editImage = image
                        self?.arrSelectedModels.append(model)
                        self?.requestSelectPhoto()
                    }
                    vc.modalPresentationStyle = .fullScreen
                    self?.sender?.showDetailViewController(vc, sender: nil)
                } else {
                    showAlertView(localLanguageTextValue(.imageLoadFailed), self?.sender)
                }
                hud.hide()
            }
        }
    }
    
    func showEditVideoVC(model: ZLPhotoModel) {
        let hud = ZLProgressHUD(style: ZLPhotoConfiguration.default().hudStyle)
        
        var requestAvAssetID: PHImageRequestID?
        
        hud.show(timeout: 15)
        hud.timeoutBlock = {
            if let _ = requestAvAssetID {
                PHImageManager.default().cancelImageRequest(requestAvAssetID!)
            }
        }
        // 提前fetch一下 avasset
        requestAvAssetID = ZLPhotoManager.fetchAVAsset(forVideo: model.asset) { [weak self] (asset, _) in
            hud.hide()
            if asset == nil {
                showAlertView(localLanguageTextValue(.timeout), self?.sender)
            } else {
                let vc = ZLEditVideoViewController(asset: model.asset)
                vc.editFinishBlock = { [weak self] (asset) in
                    let m = ZLPhotoModel(asset: asset)
                    m.isSelected = true
                    self?.arrSelectedModels.append(m)
                    self?.requestSelectPhoto()
                }
                vc.modalPresentationStyle = .fullScreen
                self?.sender?.showDetailViewController(vc, sender: nil)
            }
        }
    }
    
    func getImageNav(rootViewController: UIViewController) -> ZLImageNavController {
        let nav = ZLImageNavController(rootViewController: rootViewController)
        nav.modalPresentationStyle = .fullScreen
        nav.selectImageBlock = { [weak self, weak nav] in
            self?.isSelectOriginal = nav?.isSelectedOriginal ?? false
            self?.arrSelectedModels.removeAll()
            self?.arrSelectedModels.append(contentsOf: nav?.arrSelectedModels ?? [])
            self?.requestSelectPhoto(viewController: nav)
        }
        
        nav.cancelBlock = { [weak self] in
            self?.cancelBlock?()
            self?.hide()
        }
        nav.isSelectedOriginal = self.isSelectOriginal
        nav.arrSelectedModels.removeAll()
        nav.arrSelectedModels.append(contentsOf: self.arrSelectedModels)
        
        return nav
    }
    
    func save(image: UIImage?, videoUrl: URL?) {
        let hud = ZLProgressHUD(style: ZLPhotoConfiguration.default().hudStyle)
        if let image = image {
            hud.show()
            ZLPhotoManager.saveImageToAlbum(image: image) { [weak self] (suc, asset) in
                if suc, let at = asset {
                    let model = ZLPhotoModel(asset: at)
                    self?.handleDataArray(newModel: model)
                } else {
                    showAlertView(localLanguageTextValue(.saveImageError), self?.sender)
                }
                hud.hide()
            }
        } else if let videoUrl = videoUrl {
            hud.show()
            ZLPhotoManager.saveVideoToAblum(url: videoUrl) { [weak self] (suc, asset) in
                if suc, let at = asset {
                    let model = ZLPhotoModel(asset: at)
                    self?.handleDataArray(newModel: model)
                } else {
                    showAlertView(localLanguageTextValue(.saveVideoError), self?.sender)
                }
                hud.hide()
            }
        }
    }
    
    func handleDataArray(newModel: ZLPhotoModel) {
        self.arrDataSources.insert(newModel, at: 0)
        
        if canAddModel(newModel, currentSelectCount: self.arrSelectedModels.count, sender: self.sender, showAlert: false) {
            if !self.shouldDirectEdit(newModel) {
                newModel.isSelected = true
                self.arrSelectedModels.append(newModel)
            }
        }
        
        let insertIndexPath = IndexPath(row: 0, section: 0)
        self.collectionView.performBatchUpdates({
            self.collectionView.insertItems(at: [insertIndexPath])
        }) { (_) in
            self.collectionView.scrollToItem(at: insertIndexPath, at: .centeredHorizontally, animated: true)
            self.collectionView.reloadItems(at: self.collectionView.indexPathsForVisibleItems)
        }
        
        self.changeCancelBtnTitle()
    }
    
}


extension ZLPhotoPreviewSheet: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let m = self.arrDataSources[indexPath.row]
        let w = CGFloat(m.asset.pixelWidth)
        let h = CGFloat(m.asset.pixelHeight)
        let scale = min(1.7, max(0.5, w / h))
        return CGSize(width: collectionView.frame.height * scale, height: collectionView.frame.height)
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        self.placeholderLabel.isHidden = self.arrSelectedModels.isEmpty
        return self.arrDataSources.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ZLThumbnailPhotoCell.zl_identifier(), for: indexPath) as! ZLThumbnailPhotoCell
        
        let model = self.arrDataSources[indexPath.row]
        
        cell.selectedBlock = { [weak self, weak cell] (isSelected) in
            guard let `self` = self else { return }
            if !isSelected {
                if self.arrSelectedModels.count > ZLPhotoConfiguration.default().maxSelectCount {
                    let message = String(format: localLanguageTextValue(.maxSelectCount), ZLPhotoConfiguration.default().maxSelectCount)
                    showAlertView(message, self.sender)
                    return
                }
                if self.arrSelectedModels.count > 0 {
                    if !ZLPhotoConfiguration.default().allowMixSelect, model.type == .video {
                        return
                    }
                }
                if model.type == .video {
                    if model.second > ZLPhotoConfiguration.default().maxSelectVideoDuration {
                        let message = String(format: localLanguageTextValue(.longerThanMaxVideoDuration), ZLPhotoConfiguration.default().maxSelectVideoDuration)
                        showAlertView(message, self.sender)
                        return
                    }
                    if model.second < ZLPhotoConfiguration.default().minSelectVideoDuration {
                        let message = String(format: localLanguageTextValue(.shorterThanMaxVideoDuration), ZLPhotoConfiguration.default().minSelectVideoDuration)
                        showAlertView(message, self.sender)
                        return
                    }
                }
                if !self.shouldDirectEdit(model) {
                    model.isSelected = true
                    self.arrSelectedModels.append(model)
                    cell?.btnSelect.isSelected = true
                    self.setCellIndex(cell, showIndexLabel: true, index: self.arrSelectedModels.count, animate: true)
                }
            } else {
                cell?.btnSelect.isSelected = false
                model.isSelected = false
                self.arrSelectedModels.removeAll { $0 == model }
                self.refreshCellIndex()
            }
            
            self.refreshCellMaskView()
            self.changeCancelBtnTitle()
        }
        
        cell.indexLabel.isHidden = true
        if ZLPhotoConfiguration.default().showSelectedIndex {
            for (index, selM) in self.arrSelectedModels.enumerated() {
                if model == selM {
                    self.setCellIndex(cell, showIndexLabel: true, index: index + 1, animate: false)
                    break
                }
            }
        }
        
        self.setCellMaskView(cell, isSelected: model.isSelected, model: model)
        
        cell.model = model
        
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let c = cell as? ZLThumbnailPhotoCell else {
            return
        }
        let model = self.arrDataSources[indexPath.row]
        self.setCellMaskView(c, isSelected: model.isSelected, model: model)
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? ZLThumbnailPhotoCell else {
            return
        }
        if !cell.enableSelect {
            return
        }
        let model = self.arrDataSources[indexPath.row]
        
        if self.shouldDirectEdit(model) {
            return
        }
        let config = ZLPhotoConfiguration.default()
        let hud = ZLProgressHUD(style: config.hudStyle)
        hud.show()
        
        ZLPhotoManager.getCameraRollAlbum(allowSelectImage: config.allowSelectImage, allowSelectVideo: config.allowSelectVideo) { [weak self] (cameraRoll) in
            guard let `self` = self else {
                hud.hide()
                return
            }
            var totalPhotos = ZLPhotoManager.fetchPhoto(in: cameraRoll.result, ascending: config.sortAscending, allowSelectImage: config.allowSelectImage, allowSelectVideo: config.allowSelectVideo)
            markSelected(source: &totalPhotos, selected: &self.arrSelectedModels)
            let defaultIndex = config.sortAscending ? totalPhotos.count - 1 : 0
            var index: Int?
            // last和first效果一样，只是排序方式不同时候分别从前后开始查找可以更快命中
            if config.sortAscending {
                index = totalPhotos.lastIndex { $0 == model }
            } else {
                index = totalPhotos.firstIndex { $0 == model }
            }
            hud.hide()
            
            self.showPreviewController(totalPhotos, index: index ?? defaultIndex)
        }
    }
    
    func shouldDirectEdit(_ model: ZLPhotoModel) -> Bool {
        let canEditImage = ZLPhotoConfiguration.default().editAfterSelectThumbnailImage &&
            ZLPhotoConfiguration.default().allowEditImage &&
            ZLPhotoConfiguration.default().maxSelectCount == 1 &&
            model.type.rawValue < ZLPhotoModel.MediaType.video.rawValue
        
        let canEditVideo = ZLPhotoConfiguration.default().editAfterSelectThumbnailImage &&
            ZLPhotoConfiguration.default().allowEditVideo &&
            model.type == .video &&
            ZLPhotoConfiguration.default().maxSelectCount == 1
        
        //当前未选择图片 或已经选择了一张并且点击的是已选择的图片
        let flag = self.arrSelectedModels.isEmpty || (self.arrSelectedModels.count == 1 && self.arrSelectedModels.first?.ident == model.ident)
        
        if canEditImage, flag {
            self.showEditImageVC(model: model)
        } else if canEditVideo, flag {
            self.showEditVideoVC(model: model)
        }
        
        return ZLPhotoConfiguration.default().editAfterSelectThumbnailImage && ZLPhotoConfiguration.default().maxSelectCount == 1 && (ZLPhotoConfiguration.default().allowEditImage || ZLPhotoConfiguration.default().allowEditVideo)
    }
    
    func setCellIndex(_ cell: ZLThumbnailPhotoCell?, showIndexLabel: Bool, index: Int, animate: Bool) {
        guard ZLPhotoConfiguration.default().showSelectedIndex else {
            return
        }
        cell?.index = index
        cell?.indexLabel.isHidden = !showIndexLabel
        if animate {
            cell?.indexLabel.layer.add(getSpringAnimation(), forKey: nil)
        }
    }
    
    func refreshCellIndex() {
        guard ZLPhotoConfiguration.default().showSelectedIndex else {
            return
        }
        
        let visibleIndexPaths = self.collectionView.indexPathsForVisibleItems
        
        visibleIndexPaths.forEach { (indexPath) in
            guard let cell = self.collectionView.cellForItem(at: indexPath) as? ZLThumbnailPhotoCell else {
                return
            }
            let m = self.arrDataSources[indexPath.row]
            
            var show = false
            var idx = 0
            for (index, selM) in self.arrSelectedModels.enumerated() {
                if m == selM {
                    show = true
                    idx = index + 1
                    break
                }
            }
            self.setCellIndex(cell, showIndexLabel: show, index: idx, animate: false)
        }
    }
    
    func refreshCellMaskView() {
        guard ZLPhotoConfiguration.default().showSelectedMask || ZLPhotoConfiguration.default().showInvalidMask else {
            return
        }
        
        let visibleIndexPaths = self.collectionView.indexPathsForVisibleItems
        
        visibleIndexPaths.forEach { (indexPath) in
            guard let cell = self.collectionView.cellForItem(at: indexPath) as? ZLThumbnailPhotoCell else {
                return
            }
            let m = self.arrDataSources[indexPath.row]
            
            var isSelected = false
            for selM in self.arrSelectedModels {
                if m == selM {
                    isSelected = true
                    break
                }
            }
            self.setCellMaskView(cell, isSelected: isSelected, model: m)
        }
    }
    
    func setCellMaskView(_ cell: ZLThumbnailPhotoCell, isSelected: Bool, model: ZLPhotoModel) {
        cell.coverView.isHidden = true
        cell.enableSelect = true
        
        if isSelected {
            cell.coverView.backgroundColor = .selectedMaskColor
            cell.coverView.isHidden = !ZLPhotoConfiguration.default().showSelectedMask
        } else {
            let selCount = self.arrSelectedModels.count
            if selCount < ZLPhotoConfiguration.default().maxSelectCount, selCount > 0 {
                if !ZLPhotoConfiguration.default().allowMixSelect {
                    cell.coverView.backgroundColor = .invalidMaskColor
                    cell.coverView.isHidden = (!ZLPhotoConfiguration.default().showInvalidMask || model.type != .video)
                    cell.enableSelect = model.type != .video
                }
            } else if selCount >= ZLPhotoConfiguration.default().maxSelectCount {
                cell.coverView.backgroundColor = .invalidMaskColor
                cell.coverView.isHidden = ZLPhotoConfiguration.default().showInvalidMask
                cell.enableSelect = false
            }
        }
    }
    
    func changeCancelBtnTitle() {
        if self.arrSelectedModels.count > 0 {
            self.cancelBtn.setTitle(String(format: "%@(%ld)", localLanguageTextValue(.done), self.arrSelectedModels.count), for: .normal)
            self.cancelBtn.setTitleColor(.previewBtnHighlightTitleColor, for: .normal)
        } else {
            self.cancelBtn.setTitle(localLanguageTextValue(.previewCancel), for: .normal)
            self.cancelBtn.setTitleColor(.previewBtnTitleColor, for: .normal)
        }
    }
    
}


extension ZLPhotoPreviewSheet: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) {
            let image = info[.originalImage] as? UIImage
            let url = info[.mediaURL] as? URL
            self.save(image: image, videoUrl: url)
        }
    }
    
}
