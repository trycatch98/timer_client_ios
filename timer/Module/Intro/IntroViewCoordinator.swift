//
//  IntroCoordinator.swift
//  timer
//
//  Created by Jeong Jin Eun on 09/04/2019.
//  Copyright © 2019 Jeong Jin Eun. All rights reserved.
//

import UIKit

/// Route from intro view
class IntroViewCoordinator: CoordinatorProtocol {
     // MARK: - route enumeration
    enum IntroRoute {
        case main
    }
    
    // MARK: - properties
    weak var viewController: IntroViewController!
    let provider: ServiceProviderProtocol
    
    // MARK: - constructor
    required init(provider: ServiceProviderProtocol) {
        self.provider = provider
    }
    
    func present(for route: IntroRoute) -> UIViewController {
        let viewController = get(for: route)
        
        switch route {
        case .main:
            // Present main view
            self.viewController.navigationController?.viewControllers = [viewController]
        }
        
        return viewController
    }
    
    func get(for route: IntroRoute) -> UIViewController {
        switch route {
        case .main:
            let coordinator = MainViewCoordinator(provider: provider)
            let viewController = MainViewController(coordinator: coordinator)
            
            // DI
            coordinator.viewController = viewController
            
            // set tab bar view controller initial index
            viewController.select(at: MainViewController.TabType.Productivity.rawValue, animated: false)
            return viewController
        }
    }
}