//
//  TimeSetEditViewCoordinator.swift
//  timer
//
//  Created by JSilver on 09/08/2019.
//  Copyright © 2019 Jeong Jin Eun. All rights reserved.
//

import UIKit

class TimeSetEditViewCoordinator: CoordinatorProtocol {
    // MARK: - route enumeration
    enum Route {
        case home
        case timeSetSave(TimeSetItem)
    }
    
    // MARK: - properties
    weak var viewController: TimeSetEditViewController!
    let provider: ServiceProviderProtocol
    
    // MARK: - constructor
    required init(provider: ServiceProviderProtocol) {
        self.provider = provider
    }
    
    // MARK: - presentation
    func present(for route: Route) -> UIViewController? {
        guard let viewController = get(for: route) else { return nil }
        
        switch route {
        case .home:
            self.viewController.navigationController?.setViewControllers([viewController], animated: true)
            
        case .timeSetSave(_):
            self.viewController.navigationController?.pushViewController(viewController, animated: true)
        }
        
        return viewController
    }
    
    func get(for route: Route) -> UIViewController? {
        switch route {
        case .home:
            return self.viewController.navigationController?.viewControllers.first
            
        case let .timeSetSave(timeSetItem):
            let coordinator = TimeSetSaveViewCoordinator(provider: provider)
            let reactor = TimeSetSaveViewReactor(timeSetService: provider.timeSetService, timeSetItem: timeSetItem)
            let viewController = TimeSetSaveViewController(coordinator: coordinator)
            
            // DI
            coordinator.viewController = viewController
            viewController.reactor = reactor
            
            return viewController
        }
    }
}
