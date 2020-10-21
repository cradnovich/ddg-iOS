//
//  TabsBarViewController.swift
//  DuckDuckGo
//
//  Copyright © 2020 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import UIKit
import Core

protocol TabsBarDelegate: NSObjectProtocol {
    
    func tabsBar(_ controller: TabsBarViewController, didSelectTabAtIndex index: Int)
    func tabsBar(_ controller: TabsBarViewController, didRemoveTabAtIndex index: Int)
    func tabsBar(_ controller: TabsBarViewController, didRequestMoveTabFromIndex fromIndex: Int, toIndex: Int)
    func tabsBarDidRequestNewTab(_ controller: TabsBarViewController)
    func tabsBarDidRequestForgetAll(_ controller: TabsBarViewController)
    func tabsBarDidRequestTabSwitcher(_ controller: TabsBarViewController)

}

class TabsBarViewController: UIViewController {

    struct Constants {
        
        static let minItemWidth: CGFloat = 68

    }
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var buttonsStack: UIStackView!
    @IBOutlet weak var fireButton: UIButton!
    @IBOutlet weak var addTabButton: UIButton!
    @IBOutlet weak var tabSwitcherContainer: UIView!
    @IBOutlet weak var buttonsBackground: UIView!

    weak var delegate: TabsBarDelegate?
    private weak var tabsModel: TabsModel?

    private let tabSwitcherButton = TabSwitcherButton()
    private let longPressTabGesture = UILongPressGestureRecognizer()
    
    private weak var pressedCell: TabsBarCell?
    
    var tabsCount: Int {
        return tabsModel?.count ?? 0
    }
    
    var currentIndex: Int {
        return tabsModel?.currentIndex ?? 0
    }

    var maxItems: Int {
        return Int(collectionView.frame.size.width / Constants.minItemWidth)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        applyTheme(ThemeManager.shared.currentTheme)

        tabSwitcherButton.delegate = self
        tabSwitcherContainer.addSubview(tabSwitcherButton)

        collectionView.clipsToBounds = false
        collectionView.delegate = self
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        collectionView.dataSource = self
        
        configureGestures()
        
        enableInteractionsWithPointer()
        
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabSwitcherButton.layoutSubviews()
        reloadData()
    }

    @IBAction func onFireButtonPressed() {
        
        let alert = ForgetDataAlert.buildAlert(forgetTabsAndDataHandler: { [weak self] in
            guard let self = self else { return }
            self.delegate?.tabsBarDidRequestForgetAll(self)
        })
        self.present(controller: alert, fromView: fireButton)

    }

    @IBAction func onNewTabPressed() {
        requestNewTab()
    }

    func refresh(tabsModel: TabsModel?, scrollToSelected: Bool = false) {
        self.tabsModel = tabsModel
        
        tabSwitcherContainer.isAccessibilityElement = true
        tabSwitcherContainer.accessibilityLabel = UserText.tabSwitcherAccessibilityLabel
        tabSwitcherContainer.accessibilityHint = UserText.numberOfTabs(tabsCount)

        let availableWidth = collectionView.frame.size.width
        let maxVisibleItems = min(maxItems, tabsCount)
        
        var itemWidth = availableWidth / CGFloat(maxVisibleItems)
        itemWidth = max(itemWidth, Constants.minItemWidth)
        itemWidth = min(itemWidth, availableWidth / 2)

        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.itemSize = CGSize(width: itemWidth, height: view.frame.size.height)
        }
        
        reloadData()

        if scrollToSelected {
            DispatchQueue.main.async {
                self.collectionView.scrollToItem(at: IndexPath(row: self.currentIndex, section: 0), at: .right, animated: true)
            }
        }

    }

    private func reloadData() {
        collectionView.reloadData()
        tabSwitcherButton.tabCount = tabsCount
    }

    func backgroundTabAdded() {
        reloadData()
        tabSwitcherButton.tabCount = tabsCount - 1
        tabSwitcherButton.incrementAnimated()
    }
    
    private func configureGestures() {
        longPressTabGesture.addTarget(self, action: #selector(handleLongPressTabGesture))
        longPressTabGesture.minimumPressDuration = 0.2
        collectionView.addGestureRecognizer(longPressTabGesture)
    }
    
    @objc func handleLongPressTabGesture(gesture: UILongPressGestureRecognizer) {
        let locationInCollectionView = gesture.location(in: collectionView)
        
        switch gesture.state {
        case .began:
            guard let path = collectionView.indexPathForItem(at: locationInCollectionView) else { return }
            delegate?.tabsBar(self, didSelectTabAtIndex: path.row)

        case .changed:
            guard let path = collectionView.indexPathForItem(at: locationInCollectionView) else { return }
            if pressedCell == nil, let cell = collectionView.cellForItem(at: path) as? TabsBarCell {
                cell.isPressed = true
                pressedCell = cell
                collectionView.beginInteractiveMovementForItem(at: path)
            }
            let location = CGPoint(x: locationInCollectionView.x, y: collectionView.center.y)
            collectionView.updateInteractiveMovementTargetPosition(location)
            
        case .ended:
            collectionView.endInteractiveMovement()
            releasePressedCell()

        default:
            collectionView.cancelInteractiveMovement()
            releasePressedCell()
        }
    }

    private func releasePressedCell() {
        pressedCell?.isPressed = false
        pressedCell = nil
    }
    
    private func enableInteractionsWithPointer() {
        guard #available(iOS 13.4, *) else { return }
        fireButton.isPointerInteractionEnabled = true
        addTabButton.isPointerInteractionEnabled = true
        tabSwitcherButton.pointerView.frame.size.width = 34
    }
    
    private func requestNewTab() {
        delegate?.tabsBarDidRequestNewTab(self)
        DispatchQueue.main.async {
            self.collectionView.scrollToItem(at: IndexPath(row: self.currentIndex, section: 0), at: .right, animated: true)
        }
    }

}

extension TabsBarViewController: TabSwitcherButtonDelegate {
    
    func showTabSwitcher(_ button: TabSwitcherButton) {
        delegate?.tabsBarDidRequestTabSwitcher(self)
    }
    
    func launchNewTab(_ button: TabSwitcherButton) {
        requestNewTab()
    }
        
}

extension TabsBarViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.tabsBar(self, didSelectTabAtIndex: indexPath.item)
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return true
    }

    func collectionView(_ collectionView: UICollectionView, targetIndexPathForMoveFromItemAt originalIndexPath: IndexPath,
                        toProposedIndexPath proposedIndexPath: IndexPath) -> IndexPath {
        return proposedIndexPath
    }

    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        delegate?.tabsBar(self, didRequestMoveTabFromIndex: sourceIndexPath.row, toIndex: destinationIndexPath.row)
    }
    
}

extension TabsBarViewController: UICollectionViewDragDelegate {
    fileprivate func dragItemFromTab(at indexPath: IndexPath) -> UIDragItem? {
        guard let selectedTab = tabsModel?.get(tabAt: indexPath.row) else {
            return nil
        }
        
        let userActivity = selectedTab.openTabUserActivity
        let itemProvider = NSItemProvider(object: selectedTab)
        itemProvider.registerObject(userActivity, visibility: .all)
        
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = selectedTab

        return dragItem
    }
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard let dragItem = dragItemFromTab(at: indexPath) else {
            return []
        }
        
        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        itemsForAddingTo session: UIDragSession,
                        at indexPath: IndexPath,
                        point: CGPoint) -> [UIDragItem] {
        guard let dragItem = dragItemFromTab(at: indexPath) else {
            return []
        }

        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView, dragSessionDidEnd session: UIDragSession) {
        
        if let context = session.localContext {
            debugPrint("\(context)")
            
//            collectionView.performBatchUpdates({
//                var removedIndexPaths: [IndexPath] = []
//                var removedTabIndices = IndexSet()
//                
//                for item in session.items {
//                    guard let tab = item.localObject as? Tab,
//                          let tabIndex = self.tabsModel?.indexOf(tab: tab) else {
//                        continue
//                    }
//                    
//                    let indexPath = IndexPath(item: tabIndex, section: 0)
//                    removedTabIndices.insert(tabIndex)
//                    removedIndexPaths.append(indexPath)
//                }
//                
//                self.tabsModel?.remove(atOffsets: removedTabIndices)
//                collectionView.deleteItems(at: removedIndexPaths)
//            }, completion: { _ in self.refresh(tabsModel: self.tabsModel, scrollToSelected: true)})
        } else {
            debugPrint("Ending drag session: \(session.items)")
        }
    }
}

extension TabsBarViewController: UICollectionViewDropDelegate {
    fileprivate func selectTab(in collectionView: UICollectionView, at indexPath: IndexPath?) {
        guard let ip = indexPath else {
            debugPrint("Unexpected nil IndexPath passed in to selectTab(in:at:)")
            return
        }
        
        if collectionView.delegate?.collectionView?(collectionView, shouldSelectItemAt: ip) ?? true {
            collectionView.selectItem(at: ip, animated: true, scrollPosition: .centeredHorizontally)
            collectionView.delegate?.collectionView?(collectionView, didSelectItemAt: ip)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let tabsModel = tabsModel else {
            fatalError("No tabsModel when dropping into TabsBar")
        }
        
        let destinationTabIndex = coordinator.destinationIndexPath?.item ?? tabsCount
        
        let newIndexPaths = (0..<coordinator.items.count).map({ IndexPath(item: destinationTabIndex + $0, section: 0) })
        
        if nil != coordinator.session.localDragSession {
            let tabs = coordinator.items.compactMap({ $0.dragItem.localObject as? Tab })
            
            collectionView.performBatchUpdates({
                for (i, tab) in tabs.enumerated() {
                    let destinationIndexPath = newIndexPaths[i]
                    if let currentIndex = tabsModel.indexOf(tab: tab) {
                        tabsModel.moveTab(from: currentIndex, to: destinationTabIndex)
                        collectionView.moveItem(at: IndexPath(item: currentIndex, section: 0), to: destinationIndexPath)
                    } else {
                        collectionView.insertItems(at: [destinationIndexPath])
                    }
                }
                
//                self.tabsModel?.insert(tabs: tabs, at: destinationTabIndex)
//                collectionView.insertItems(at: newIndexPaths)
            }, completion: { yn in
                guard yn else {
                    return
                }
                
                DispatchQueue.main.async {
                    self.selectTab(in: collectionView, at: newIndexPaths.first)
                }
            })
        } else {
//            coordinator.session.loadObjects(ofClass: URL.self) { (itemProviderReadings) in
//                // swiftlint:disable force_cast
//                let tabs = itemProviderReadings.map({$0 as! Tab})
//                // swiftlint:enable force_cast
//                collectionView.performBatchUpdates({
//                    self.tabsModel?.insert(tabs: tabs, at: destinationIndex)
//                    self.refresh(tabsModel: self.tabsModel)
//                })
//            }

        }
        
        for (i, newPath) in newIndexPaths.enumerated() {
            let dragItem = coordinator.items[i].dragItem
            coordinator.drop(dragItem, toItemAt: newPath)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
            dropSessionDidUpdate session: UIDropSession,
            withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        let op: UIDropOperation
        
        if let sesh = session.localDragSession {
            op = .move
            sesh.localContext = "Moved!"
        } else {
            op = .copy
        }
        
        return UICollectionViewDropProposal(operation: op, intent: .insertAtDestinationIndexPath)
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidExit session: UIDropSession) {
        debugPrint("\(session.items.count) items to drop")
    }
}

extension TabsBarViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return tabsCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Tab", for: indexPath) as? TabsBarCell else {
            fatalError("Unable to create TabBarCell")
        }
        
        guard let model = tabsModel?.get(tabAt: indexPath.item) else {
            fatalError("Failed to load tab at \(indexPath.item)")
        }
        let isCurrent = indexPath.item == currentIndex
        let isNextCurrent = indexPath.item + 1 == currentIndex
        cell.update(model: model, isCurrent: isCurrent, isNextCurrent: isNextCurrent, withTheme: ThemeManager.shared.currentTheme)
        cell.onRemove = { [weak self] in
            guard let self = self,
                let tabIndex = self.tabsModel?.indexOf(tab: model)
                else { return }
            self.delegate?.tabsBar(self, didRemoveTabAtIndex: tabIndex)
        }
        return cell
    }

}

extension TabsBarViewController: Themable {

    func decorate(with theme: Theme) {
        view.backgroundColor = theme.tabsBarBackgroundColor
        view.tintColor = theme.barTintColor
        collectionView.backgroundColor = theme.tabsBarBackgroundColor
        buttonsBackground.backgroundColor = theme.tabsBarBackgroundColor
        tabSwitcherButton.decorate(with: theme)
        
        collectionView.reloadData()
    }

}

extension MainViewController: TabsBarDelegate {
  
    func tabsBar(_ controller: TabsBarViewController, didSelectTabAtIndex index: Int) {
        dismissOmniBar()
        select(tabAt: index)
    }
    
    func tabsBar(_ controller: TabsBarViewController, didRemoveTabAtIndex index: Int) {
        let tab = tabManager.model.get(tabAt: index)
        closeTab(tab)
    }
    
    func tabsBar(_ controller: TabsBarViewController, didRequestMoveTabFromIndex fromIndex: Int, toIndex: Int) {
        tabManager.model.moveTab(from: fromIndex, to: toIndex)
        select(tabAt: toIndex)
    }
    
    func tabsBarDidRequestNewTab(_ controller: TabsBarViewController) {
        newTab()
    }
    
    func tabsBarDidRequestForgetAll(_ controller: TabsBarViewController) {
        forgetAllWithAnimation()
    }
    
    func tabsBarDidRequestTabSwitcher(_ controller: TabsBarViewController) {
        showTabSwitcher()
    }
    
}
