//
//  TimerOptionViewReactor.swift
//  timer
//
//  Created by JSilver on 25/07/2019.
//  Copyright © 2019 Jeong Jin Eun. All rights reserved.
//

import RxSwift
import ReactorKit

class TimerOptionViewReactor: Reactor {
    // MARK: - constants
    static let MAX_COMMENT_LENGTH: Int = 200
    
    enum Action {
        /// Update timer info when view will appear
        case viewWillAppear
        
        /// Update title of timer
        case updateTitle(String)
        
        /// Update timer info
        case updateTimer(TimerInfo)
        
        /// Update comment of timer
        case updateComment(String)
        
        /// Update alarm of timer
        case updateAlarm(String)
    }
    
    enum Mutation {
        /// Set title of timer
        case setTitle(String)
        
        /// Set comment of timer
        case setComment(String)
        
        /// Set alarm of timer
        case setAlarm(String)
    }
    
    struct State {
        /// Title of the timer
        var title: String
        
        /// Comment of the timer
        var comment: String
        
        /// Alarm of the timer
        var alarm: String
    }
    
    // MARK: - properties
    var initialState: State
    var timerInfo: TimerInfo?
    
    // MARK: - constructor
    init() {
        self.initialState = State(title: "",
                                  comment: "",
                                  alarm: "")
    }
    
    // MARK: - mutation
    func mutate(action: Action) -> Observable<Mutation> {
        switch action {
        case .viewWillAppear:
            return actionViewWillAppear()
            
        case let .updateTitle(title):
            return actionUpdateTitle(title)
            
        case let .updateTimer(timerInfo):
            return actionUpdateTimer(info: timerInfo)
            
        case let .updateComment(comment):
            return actionUpdateComment(comment)
            
        case let .updateAlarm(alarm):
            return actionUpdateAlarm(alarm)
        }
    }
    
    func reduce(state: State, mutation: Mutation) -> State {
        var state = state
        
        switch mutation {
        case let .setTitle(title):
            state.title = title
            return state
            
        case let .setComment(comment):
            state.comment = comment
            return state
            
        case let .setAlarm(alarm):
            state.alarm = alarm
            return state
        }
    }
    
    // MARK: - action method
    private func actionViewWillAppear() -> Observable<Mutation> {
        guard let timerInfo = timerInfo else { return .empty() }
        return actionUpdateTimer(info: timerInfo)
    }
    
    private func actionUpdateTitle(_ title: String) -> Observable<Mutation> {
        return .just(.setTitle(title))
    }
    
    private func actionUpdateTimer(info: TimerInfo) -> Observable<Mutation> {
        // Change current timer
        timerInfo = info
        return .concat(.just(.setComment(info.comment)),
                       .just(.setAlarm(info.alarm)))
    }
    
    private func actionUpdateComment(_ comment: String) -> Observable<Mutation> {
        // Update timer's comment
        guard let timerInfo = timerInfo else { return .empty() }
        let length = comment.lengthOfBytes(using: .utf16)
        
        guard length <= TimerOptionViewReactor.MAX_COMMENT_LENGTH else {
            return .just(.setComment(timerInfo.comment))
        }
        
        timerInfo.comment = comment
        
        return .just(.setComment(comment))
    }
    
    private func actionUpdateAlarm(_ alarm: String) -> Observable<Mutation> {
        // Update alarm title
        timerInfo?.alarm = alarm
        return .just(.setAlarm(alarm))
    }
    
    deinit {
        Logger.verbose()
    }
}
