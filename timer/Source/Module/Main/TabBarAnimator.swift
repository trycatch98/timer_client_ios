//
//  TabBarAnimator.swift
//  timer
//
//  Created by JSilver on 15/05/2019.
//  Copyright © 2019 Jeong Jin Eun. All rights reserved.
//

import UIKit

class TabBarAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    // MARK: - properties
    private let tabBarController: UITabBarController
    
    let fromIndex: Int
    let toIndex: Int
    
    // MARK: - constructor
    init(tabBarController: UITabBarController, at fromIndex: Int, to toIndex: Int) {
        self.tabBarController = tabBarController
        self.fromIndex = fromIndex
        self.toIndex = toIndex
    }
    
    // Duration of transition
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }
    
    // Implement transition animation when want to use like as UIViewPropertyAnimator that can interrupted.
    // Returned animator object have to equal transitioning animator.
    // This method added upper iOS 10+ for backward compatibility. If this method was implemented, environment call method instead of animateTransition(using:)
    func interruptibleAnimator(using transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating {
        // Get from, to view controller of transition
        guard let fromVC = transitionContext.viewController(forKey: .from) else { return UIViewPropertyAnimator() }
        guard let toVC = transitionContext.viewController(forKey: .to) else { return UIViewPropertyAnimator() }
        
        // Add view
        transitionContext.containerView.addSubview(toVC.view)
        
        // Get animation frame
        let frame = fromVC.view.frame
        
        var fromVCEndFrame = frame
        fromVCEndFrame.origin.x = toIndex > fromIndex ? frame.origin.x - frame.size.width : frame.origin.x + frame.size.width
        
        var toVCStartFrame = frame
        toVCStartFrame.origin.x = toIndex > fromIndex ? frame.origin.x + frame.size.width : frame.origin.x - frame.size.width
        
        // Set init frame
        toVC.view.frame = toVCStartFrame
        
        // Create animator
        let animator = UIViewPropertyAnimator(duration: transitionDuration(using: transitionContext),
                                              controlPoint1: CGPoint(x: 0.65, y: 0.0),
                                              controlPoint2: CGPoint(x: 0.35, y: 1.0)) {
            toVC.view.frame = frame
            fromVC.view.frame = fromVCEndFrame
        }
        
        // Add complete handler
        animator.addCompletion { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    
        return animator
    }
    
    // Animation to perform of transition
    // For keep contract of protocol, implement this method. Just can create animator using interruptibleAnimator(using:) and start it.
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let animator = interruptibleAnimator(using: transitionContext)
        // Start transition animation
        animator.startAnimation()
    }
    
    // Send delegate message when transition animation ended
    func animationEnded(_ transitionCompleted: Bool) {
        tabBarController.delegate?.tabBarController?(tabBarController, didSelect: tabBarController.selectedViewController!)
    }
}
