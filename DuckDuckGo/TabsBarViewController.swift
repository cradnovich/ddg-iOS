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

// swiftlint:disable file_length
import UIKit
import Core

protocol TabsBarDelegate: NSObjectProtocol {
    
    func tabsBar(_ controller: TabsBarViewController, didSelectTabAtIndex index: Int)
    func tabsBar(_ controller: TabsBarViewController, didRemoveTabAtIndex index: Int)
    func tabsBar(_ controller: TabsBarViewController, didRequestMoveTabFromIndex fromIndex: Int, toIndex: Int)
    func tabsBar(_ controller: TabsBarViewController, didRemoveTabs: [Tab])
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
    private weak var newWindowObserver: NewWindowNotification.Observer?
    
    private let tabSwitcherButton = TabSwitcherButton()
    private let longPressTabGesture = UILongPressGestureRecognizer()
    
    private weak var pressedCell: TabsBarCell?
    fileprivate var isDraggingToNewWindow = false
    
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
        
        addDraggedToMakeNewWindowNotificationObserver()
        
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
    
    private func addDraggedToMakeNewWindowNotificationObserver() {
        newWindowObserver = NewWindowNotification.addObserver(handler: { (tabUID) in
            
            self.removeTabs(withUID: tabUID)
        })
        
    }
    
    private func removeTabs(withUID uid: String) {
        guard let tabsModel = tabsModel else {
            fatalError("How does the tabs bar have no model?")
        }
        
        var movedTabs: [Tab] = []
        var removedIndexPaths: [IndexPath] = []
        
        for (i, tab) in tabsModel.tabs.enumerated() where uid == tab.uid {
            movedTabs.append(tab)
            let path = IndexPath(item: i, section: 0)
            removedIndexPaths.append(path)
        }
        
        guard !movedTabs.isEmpty else {
            return
        }
        
        collectionView.performBatchUpdates({
            self.delegate?.tabsBar(self, didRemoveTabs: movedTabs)
            self.collectionView.deleteItems(at: removedIndexPaths)
        }, completion: { _ in
            self.selectTab(in: self.collectionView, at: IndexPath(item: self.currentIndex, section: 0))
            self.refresh(tabsModel: tabsModel, scrollToSelected: true)
        })

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
        
        let dragCoordinator = TabDragCoordinator(sourceIndexPath: indexPath)
        session.localContext = dragCoordinator
        
        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        itemsForAddingTo session: UIDragSession,
                        at indexPath: IndexPath,
                        point: CGPoint) -> [UIDragItem] {
        guard let dragItem = dragItemFromTab(at: indexPath) else {
            return []
        }
        
        guard let dragCoordinator = session.localContext as? TabDragCoordinator else {
            debugPrint("The drag session context wasn't a TabDragCoordinator: \(String(describing: session.localContext))")
            return [dragItem]
        }
        
        dragCoordinator.add(indexPath: indexPath)
        
        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView, dragSessionDidEnd session: UIDragSession) {
        
        // Single Tab
        // When dropping in a new window: // FIXME: Need to remove old tabs
        //  - collectionView.hasActiveDrop: false
        //  - collectionView.hasActiveDrag: true
        //  - collectionView.hasUncommittedUpdates: false
        //  - dragCoordinator.dragCompleted: false
        //  - dragCoordinator.isReordering: false
        //  - dragCoordinator.didExit: true ... sometimes
        //  - sceneIdentifiers: ?
        // When cancelling: // OK, do nothing
        //  - collectionView.hasActiveDrop: false
        //  - collectionView.hasActiveDrag: true
        //  - collectionView.hasUncommittedUpdates: ?
        //  - dragCoordinator.dragCompleted: false
        //  - dragCoordinator.isReordering: false
        //  - dragCoordinator.didExit: true (?!)
        //  - sceneIdentifiers: ?
        // When dropping in the same window (reordering): // OK, do nothing
        //  - collectionView.hasActiveDrop: true
        //  - collectionView.hasActiveDrag: true
        //  - collectionView.hasUncommittedUpdates: ?
        //  - dragCoordinator.dragCompleted: true
        //  - dragCoordinator.isReordering: true
        //  - dragCoordinator.didExit: false
        //  - sceneIdentifiers: ?
        // When dropping in an existing, other window: // OK, delete moved tabs
        //  - collectionView.hasActiveDrop: false
        //  - collectionView.hasActiveDrag: true
        //  - collectionView.hasUncommittedUpdates: ?
        //  - dragCoordinator.dragCompleted: ?
        //  - dragCoordinator.isReordering: ?
        //  - dragCoordinator.didExit: false // Because other window sees the drop come in and changes this.
        //  - sceneIdentifiers: ?
        guard let dragCoordinator = session.localContext as? TabDragCoordinator,
              dragCoordinator.dragCompleted,
              !dragCoordinator.isReordering,
              let tabsModel = tabsModel else {
            return
        }
        
        var tabsDropped: [Tab] = []
        var removedIndexPaths: [IndexPath] = []
        
        // Filter out tabs from other tab bars
        for tab in dragCoordinator.foreignSourcedTabs {
            guard let idx = tabsModel.indexOf(tab: tab) else {
                continue
            }
            
            tabsDropped.append(tab)
            removedIndexPaths.append(IndexPath(item: idx, section: 0))
        }
        
        collectionView.performBatchUpdates({
            self.delegate?.tabsBar(self, didRemoveTabs: tabsDropped)
            collectionView.deleteItems(at: removedIndexPaths)
        }, completion: { _ in
            self.selectTab(in: collectionView, at: IndexPath(item: self.currentIndex, section: 0))
            self.refresh(tabsModel: tabsModel, scrollToSelected: true)
        })
        
        isDraggingToNewWindow = false
    }
}

extension TabsBarViewController: UICollectionViewDropDelegate {
    fileprivate func selectTab(in collectionView: UICollectionView, at indexPath: IndexPath?) {
        guard let ip = indexPath else {
            debugPrint("Unexpected nil IndexPath passed in to selectTab(in:at:)")
            return
        }
        
        assert(self === collectionView.delegate)
        
        if collectionView.delegate?.collectionView?(collectionView, shouldSelectItemAt: ip) ?? true {
            collectionView.selectItem(at: ip, animated: true, scrollPosition: .centeredHorizontally)
            self.collectionView(collectionView, didSelectItemAt: ip)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        guard let tabsModel = tabsModel else {
            fatalError("No tabsModel when dropping into TabsBar")
        }
        
        let destinationTabIndex = coordinator.destinationIndexPath?.item ?? tabsCount
        let newIndexPaths = (0..<coordinator.items.count).map({ IndexPath(item: destinationTabIndex + $0, section: 0) })
        
        switch coordinator.proposal.operation {
        case .copy:
            print("Copying from different app...")
            
            let totalProgress = Progress(totalUnitCount: Int64(coordinator.items.count))
            
            for item in coordinator.items {
                let itemProvider = item.dragItem.itemProvider
                let progress = itemProvider.loadObject(ofClass: URL.self) { (url, error) in
                    if let url = url {
                        let link = Link(title: "", url: url)
                        let tab = Tab(link: link)
                        tabsModel.insert(tab: tab, at: destinationTabIndex)
                        DispatchQueue.main.async {
                            collectionView.insertItems(at: newIndexPaths)
                        }
                    }
                }
                
                totalProgress.addChild(progress, withPendingUnitCount: 1)
            }
            
            totalProgress.resume()
        case .move:
            guard let dragCoordinator = coordinator.session.localDragSession?.localContext as? TabDragCoordinator else { return }
            collectionView.performBatchUpdates({
                for (i, item) in coordinator.items.reversed().enumerated() {
                    let destinationIndexPath = newIndexPaths[i]
                    
                    if let sourceIndexPath = item.sourceIndexPath {
                        print("Moving within the same collection view")
                        dragCoordinator.isReordering = true
                        collectionView.moveItem(at: sourceIndexPath, to: destinationIndexPath)
                        self.delegate?.tabsBar(self, didRequestMoveTabFromIndex: sourceIndexPath.item, toIndex: destinationIndexPath.item)
                    } else {
                        print("Moving between collection views. Also reordering? \(dragCoordinator.isReordering)")
                        
                        if let tab = item.dragItem.localObject as? Tab {
                            dragCoordinator.add(foreignTab: tab)
                            tabsModel.insert(tab: tab, at: destinationIndexPath.item)
                            collectionView.insertItems(at: [destinationIndexPath])
                        }
                    }
                }
            }, completion: { yn in
                // This block is called on the main queue if data is homogenous, background if heterogenous
                guard yn else {
                    return
                }
                
                self.selectTab(in: collectionView, at: newIndexPaths.first)
                self.refresh(tabsModel: tabsModel, scrollToSelected: true)
            })
            
            dragCoordinator.dragCompleted = true
            
            for (i, newPath) in newIndexPaths.enumerated() { // TODO: Check whether this should be reversed also
                let dragItem = coordinator.items[i].dragItem
                coordinator.drop(dragItem, toItemAt: newPath)
            }
        default:
            return
        }
    }
    
    func collectionView(_ collectionView: UICollectionView,
                        dropSessionDidUpdate session: UIDropSession,
                        withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        let op: UIDropOperation
        
        if nil == session.localDragSession {
            op = .copy
        } else {
            op = .move
        }
        
        return UICollectionViewDropProposal(operation: op, intent: .insertAtDestinationIndexPath)
    }
    
    // MARK: - Experimental for deletion
    func collectionView(_ collectionView: UICollectionView, dropSessionDidExit session: UIDropSession) {
        if let dragCoordinator = session.localDragSession?.localContext as? TabDragCoordinator {
            dragCoordinator.didExit = true
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidEnd session: UIDropSession) {
        print("\(#function) \(session) loc: \(session.location(in: collectionView)) frame: \(collectionView.bounds)")
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidEnter session: UIDropSession) {
        if let dragCoordinator = session.localDragSession?.localContext as? TabDragCoordinator {
            dragCoordinator.didExit = false
        }
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
    
    func tabsBar(_ controller: TabsBarViewController, didRemoveTabs tabs: [Tab]) {
        closeTabs(tabs)
    }
    
    func tabsBar(_ controller: TabsBarViewController, didSelectTabAtIndex index: Int) {
        dismissOmniBar()
        select(tabAt: index)
    }
    
    func tabsBar(_ controller: TabsBarViewController, didRemoveTabsAtIndices indexSet: IndexSet) {
        closeTabs(atOffsets: indexSet)
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
// swiftlint:enable file_length

