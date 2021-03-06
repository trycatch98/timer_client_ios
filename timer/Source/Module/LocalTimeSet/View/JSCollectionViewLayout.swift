//
//  JSCollectionViewLayout.swift
//  timer
//
//  Created by JSilver on 09/09/2019.
//  Copyright © 2019 Jeong Jin Eun. All rights reserved.
//

import UIKit

@objc protocol JSCollectionViewDelegateLayout: UICollectionViewDelegateFlowLayout {
    /// Asks the delegate for the size of the header view in the collection view.
    @objc optional func referenceSizeForHeader(in collectionView: UICollectionView, layout collectionViewLayout: JSCollectionViewLayout) -> CGSize
    
    /// Asks the delegate for the size of the footer view in the collection view.
    @objc optional func referenceSizeForFooter(in collectionView: UICollectionView, layout collectionViewLayout: JSCollectionViewLayout) -> CGSize
    
    /// Asks the delegate for visibility of the header view in the specified section.
    @objc optional func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: JSCollectionViewLayout, visibleHeaderInSection section: Int) -> Bool
    
    /// Asks the delegate for visibility of the footer view in the specified section.
    @objc optional func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: JSCollectionViewLayout, visibleFooterInSection section: Int) -> Bool
    
    /// Asks the delegate for visibility of the header view in the collection view.
    @objc optional func headerVisible(collectionView: UICollectionView, layout collectionViewLayout: JSCollectionViewLayout) -> Bool
    
    /// Asks the delegate for visibility of the footer view in the collection view.
    @objc optional func footerVisible(collectionView: UICollectionView, layout collectionViewLayout: JSCollectionViewLayout) -> Bool
    
    /// Asks the delegate for the inset of the collection view
    @objc optional func inset(for collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout) -> UIEdgeInsets
}

/// Global header & footer added flow layout
class JSCollectionViewLayout: UICollectionViewFlowLayout {
    enum Element: String, CaseIterable {
        case header
        case footer
        case sectionHeader
        case sectionFooter
        case cell
        
        var kind: String {
            return self.rawValue
        }
    }
    
    // MARK: - properties
    private var attributesCache: [Element: [IndexPath: UICollectionViewLayoutAttributes]] = [:]
    private var previousAttributesCache: [Element: [IndexPath: UICollectionViewLayoutAttributes]] = [:]
    private var insertedAttributes: [Element: [IndexPath]] = [:]
    private var deletedAttributes: [Element: [IndexPath]] = [:]
    
    private var contentSize: CGSize = .zero
    
    private var itemPosition: CGPoint = .zero
    private var maxRowPosition: CGFloat = 0
    
    // Flow layout delegate
    weak var delegate: JSCollectionViewDelegateLayout?
    
    // Global view inset
    var globalInset: UIEdgeInsets = .zero
    
    // Global supplementary view size
    var globalHeaderReferenceSize: CGSize = .zero
    var globalFooterReferenceSize: CGSize = .zero
    
    // Supplementary view visible
    var headerVisible: Bool = true
    var footerVisible: Bool = true
    var sectionHeaderVisible: Bool = true
    var sectionFooterVisible: Bool = true
    
    override var collectionViewContentSize: CGSize {
        return contentSize
    }
    
    // MARK: - core process
    override func prepare() {
        guard let collectionView = collectionView else { return }
        // Get delegate
        delegate = getDelegate()
        
        // Init layout & attributes cache
        prepareLayout(collectionView: collectionView)
        
        previousAttributesCache = attributesCache
        Element.allCases.forEach { attributesCache[$0] = [:] }
        
        // Section
        let sectionCount = collectionView.numberOfSections
        
        // Global header
        if sectionCount > 0 && delegate?.headerVisible?(collectionView: collectionView, layout: self) ?? headerVisible {
            prepareElement(UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: Element.header.kind,
                                                            with: IndexPath(item: 0, section: 0)),
                           size: delegate?.referenceSizeForHeader?(in: collectionView,
                                                                   layout: self) ?? globalHeaderReferenceSize,
                           type: Element.header)
        }
        
        contentSize.height += delegate?.inset?(for: collectionView, layout: self).top ?? globalInset.top
        
        (0 ..< sectionCount).forEach { section in
            // Section header
            if delegate?.collectionView?(collectionView, layout: self, visibleHeaderInSection: section) ?? sectionHeaderVisible {
                prepareElement(UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: Element.sectionHeader.kind,
                                                                with: IndexPath(item: 0, section: section)),
                               size: delegate?.collectionView?(collectionView,
                                                               layout: self,
                                                               referenceSizeForHeaderInSection: section) ?? headerReferenceSize,
                               type: Element.sectionHeader)
            }
            
            contentSize.height += delegate?.collectionView?(collectionView, layout: self, insetForSectionAt: section).top ?? sectionInset.top
            
            // Item
            let itemCount = collectionView.numberOfItems(inSection: section)
            (0 ..< itemCount).forEach { item in
                let indexPath = IndexPath(item: item, section: section)
                prepareElement(UICollectionViewLayoutAttributes(forCellWith: indexPath),
                               size: delegate?.collectionView?(collectionView,
                                                               layout: self,
                                                               sizeForItemAt: indexPath) ?? itemSize,
                               type: .cell,
                               section: section)
            }
            
            contentSize.height += delegate?.collectionView?(collectionView, layout: self, insetForSectionAt: section).bottom ?? sectionInset.bottom
            
            // Section footer
            if delegate?.collectionView?(collectionView, layout: self, visibleFooterInSection: section) ?? sectionFooterVisible {
                prepareElement(UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: Element.sectionFooter.kind,
                                                                with: IndexPath(item: 1, section: section)),
                               size: delegate?.collectionView?(collectionView,
                                                               layout: self,
                                                               referenceSizeForFooterInSection: section) ?? footerReferenceSize,
                               type: Element.sectionFooter)
            }
        }
        
        contentSize.height += delegate?.inset?(for: collectionView, layout: self).bottom ?? globalInset.bottom
        
        // Global footer
        if sectionCount > 0 && delegate?.footerVisible?(collectionView: collectionView, layout: self) ?? footerVisible {
            prepareElement(UICollectionViewLayoutAttributes(forSupplementaryViewOfKind: Element.header.kind,
                                                            with: IndexPath(item: 0, section: 0)),
                           size: delegate?.referenceSizeForFooter?(in: collectionView,
                                                                   layout: self) ?? globalFooterReferenceSize,
                           type: Element.footer)
        }

        // Adjust content offset if content offset was broken
        if collectionView.bounds.height < contentSize.height {
            let offsetY = min(collectionView.contentOffset.y, collectionView.contentSize.height - collectionView.bounds.height)
            
            if offsetY > 0 && collectionView.contentOffset.y != offsetY {
                UIView.animate(withDuration: 0.3) {
                    collectionView.contentOffset.y = offsetY
                }
            }
        }
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        var visibleAttributes: [UICollectionViewLayoutAttributes] = []
        attributesCache.forEach { visibleAttributes.append(contentsOf: $0.value.filter { $0.value.frame.intersects(rect) }.map { $0.value }) }
        return visibleAttributes
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return attributesCache[.cell]?[indexPath]
    }
    
    // MARK: - supplementary view
    override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let element = Element(rawValue: elementKind),
            let attribute = attributesCache[element]?[indexPath] else { return nil }
        return attribute
    }
    
    // MARK: - animation
    override func prepare(forCollectionViewUpdates updateItems: [UICollectionViewUpdateItem]) {
        super.prepare(forCollectionViewUpdates: updateItems)
        
        insertedAttributes.removeAll(keepingCapacity: false)
        deletedAttributes.removeAll(keepingCapacity: false)
        
        // Find inserted/deleted supplementary views
        Element.allCases.forEach { element in
            insertedAttributes[element] = []
            deletedAttributes[element] = []
            
            guard element != .cell else { return }
            
            // Inseted supplementary view
            attributesCache[element]?.forEach {
                guard previousAttributesCache[element]?[$0.key] == nil else { return }
                insertedAttributes[element]?.append($0.key)
            }
            
            // Deleted supplementary view
            previousAttributesCache[element]?.forEach {
                guard attributesCache[element]?[$0.key] == nil else { return }
                deletedAttributes[element]?.append($0.key)
            }
        }
        
        // Find insserted/deleted items
        updateItems.forEach {
            switch $0.updateAction {
            case .insert:
                guard let indexPath = $0.indexPathAfterUpdate else { return }
                insertedAttributes[.cell]?.append(indexPath)
                
            case .delete:
                guard let indexPath = $0.indexPathBeforeUpdate else { return }
                deletedAttributes[.cell]?.append(indexPath)
                
            default:
                break
            }
        }
    }
    
    override func finalizeCollectionViewUpdates() {
        super.finalizeCollectionViewUpdates()
        
        // Clear cache
        previousAttributesCache.removeAll(keepingCapacity: true)
        insertedAttributes.removeAll(keepingCapacity: false)
        deletedAttributes.removeAll(keepingCapacity: false)
    }

    override func initialLayoutAttributesForAppearingSupplementaryElement(ofKind elementKind: String, at elementIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let attributes = super.initialLayoutAttributesForAppearingSupplementaryElement(ofKind: elementKind, at: elementIndexPath)
        guard let element = Element(rawValue: elementKind), insertedAttributes[element]?.contains(elementIndexPath) ?? false else { return attributes }

        // Set initial attributes of element
        attributes?.alpha = 0

        return attributes
    }

    override func finalLayoutAttributesForDisappearingSupplementaryElement(ofKind elementKind: String, at elementIndexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        let attributes = super.finalLayoutAttributesForDisappearingSupplementaryElement(ofKind: elementKind, at: elementIndexPath)
        guard let element = Element(rawValue: elementKind), insertedAttributes[element]?.contains(elementIndexPath) ?? false else { return attributes }

        // Set final attributes of element
        attributes?.alpha = 0

        return attributes
    }

    override func indexPathsToInsertForSupplementaryView(ofKind elementKind: String) -> [IndexPath] {
        guard let element = Element(rawValue: elementKind), let indexPaths = insertedAttributes[element] else { return [] }
        return indexPaths
    }

    override func indexPathsToDeleteForSupplementaryView(ofKind elementKind: String) -> [IndexPath] {
        guard let element = Element(rawValue: elementKind), let indexPaths = deletedAttributes[element] else { return [] }
        return indexPaths
    }
    
    // MARK: - private method
    /// Get layout delegate
    private func getDelegate() -> JSCollectionViewDelegateLayout? {
        if let delegate = delegate {
            // Return set layout delegate
            return delegate
        }
        
        if let collectionView = collectionView,
            let delegate = collectionView.delegate as? JSCollectionViewDelegateLayout {
            // Return collection view delegate
            return delegate
        }
        
        return nil
    }
    
    /// Initialize properties for layout attributes
    private func prepareLayout(collectionView: UICollectionView) {
        // Init layout positioning property
        itemPosition = .zero
        maxRowPosition = 0
        
        // Init content size
        let contentInset = collectionView.contentInset
        contentSize = .zero
        contentSize.width = collectionView.bounds.width - (contentInset.left + contentInset.right)
    }
    
    /// Prepare element attribute for caching
    private func prepareElement(_ element: UICollectionViewLayoutAttributes, size: CGSize, type: Element, section: Int = 0) {
        guard let collectionView = collectionView, size != .zero else { return }
        
        if type == .cell {
            // If element type is cell, calculate cell can enter space
            if itemPosition.x + size.width > contentSize.width {
                let lineSpacing = delegate?.collectionView?(collectionView, layout: self, minimumLineSpacingForSectionAt: section) ?? minimumLineSpacing
                itemPosition = CGPoint(x: 0, y: contentSize.height + lineSpacing)
            } else if itemPosition.x > 0 {
                let interItemSpacing = delegate?.collectionView?(collectionView, layout: self, minimumInteritemSpacingForSectionAt: section) ?? minimumInteritemSpacing
                itemPosition.x += interItemSpacing
            } else {
                itemPosition.y = contentSize.height
            }
        } else {
            // Supplementary view occupies full width of collection view
            itemPosition = CGPoint(x: 0, y: contentSize.height)
        }
        
        // Set element frame attribute
        let origin = itemPosition
        element.frame = CGRect(origin: origin, size: size)
        
        if type == .cell {
            // If element type is cell, adjust next item position only x
            itemPosition.x = element.frame.maxX
        } else {
            // Except element type is cell, reset next item position by direction
            itemPosition = CGPoint(x: 0, y: element.frame.maxY)
        }
        
        // Update content size
        contentSize.height = max(contentSize.height, element.frame.maxY)
        
        // Add attribute into cache
        attributesCache[type]?[element.indexPath] = element
    }
}
