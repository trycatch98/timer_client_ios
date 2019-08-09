//
//  LocalTimeSetViewCoordinator.swift
//  timer
//
//  Created by Jeong Jin Eun on 09/04/2019.
//  Copyright © 2019 Jeong Jin Eun. All rights reserved.
//

import UIKit

/// Route from local time set view
class LocalTimeSetViewCoordinator: CoordinatorProtocol {
     // MARK: - route enumeration
    enum LocalTimeSetRoute {
        
    }
    
    // MARK: - properties
    weak var viewController: LocalTimeSetViewController!
    let provider: ServiceProviderProtocol
    
    // MARK: - constructor
    required init(provider: ServiceProviderProtocol) {
        self.provider = provider
    }
    
    func present(for route: LocalTimeSetRoute) -> UIViewController {
        let viewController = get(for: route)
        
        return viewController
    }
    
    func get(for route: LocalTimeSetRoute) -> UIViewController {
        return UIViewController()
    }
}