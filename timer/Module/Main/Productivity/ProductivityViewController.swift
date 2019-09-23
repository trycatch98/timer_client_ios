//
//  ProductivityViewController.swift
//  timer
//
//  Created by Jeong Jin Eun on 09/04/2019.
//  Copyright © 2019 Jeong Jin Eun. All rights reserved.
//

import RxSwift
import RxCocoa
import ReactorKit
import RxDataSources
import JSReorderableCollectionView

class ProductivityViewController: BaseHeaderViewController, View {
    // MARK: - constants
    private let MAX_TIMER_COUNT: Int = 10
    private let FOOTER_BUTTON_SAVE: Int = 0
    private let FOOTER_BUTTON_START: Int = 1
    
    // MARK: - view properties
    private var productivityView: ProductivityView { return view as! ProductivityView }
    
    override var headerView: CommonHeader { return productivityView.headerView }
    
    private var timerInputView: TimerInputView { return productivityView.timerInputView }
    private var timerClearButton: UIButton { return productivityView.timerInputView.timerClearButton }
    
    private var timeInfoView: UIView { return productivityView.timeInfoView }
    private var allTimeLabel: UILabel { return productivityView.allTimeLabel }
    private var endOfTimeSetLabel: UILabel { return productivityView.endOfTimeSetLabel }
    private var timerInputLabel: UILabel { return productivityView.timeInputLabel }
    
    private var keyPadView: NumberKeyPad { return productivityView.keyPadView }
    
    private var timeKeyView: TimeKeyPad { return productivityView.timeKeyPadView }
    
    private var timerBadgeCollectionView: TimerBadgeCollectionView { return productivityView.timerBadgeCollectionView }
    
    private var saveButton: FooterButton { return productivityView.saveButton }
    private var startButton: FooterButton { return productivityView.startButton }
    private var footerView: Footer { return productivityView.footerView }
    
    // MARK: - properties
    private var isBadgeMoving: Bool = false
    
    var coordinator: ProductivityViewCoordinator
    
    // MARK: - constructor
    init(coordinator: ProductivityViewCoordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - lifecycle
    override func loadView() {
        view = ProductivityView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(longPressHandler(gesture:)))
        timerBadgeCollectionView.addGestureRecognizer(longPressGesture)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // Add footer view when view did appear because footer view should remove after will appear due to animation (add view)
        addFooterView()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        // Remove footer view when view controller disappeared
        showFooterView(isShow: false) {
            self.footerView.removeFromSuperview()
        }
    }
    
    // MARK: - bind
    override func bind() {
        super.bind()
        
        rx.viewDidAppear // For get super view controller
            .take(1)
            .subscribe(onNext: { [unowned self] in
                // Bind navigation controller event & tab bar controller event
                self.navigationController?.rx.didShow
                    .skip(1) // Skip until did finished drawing of tab bar controller
                    .filter { [unowned self] in
                        ($0.viewController as? UITabBarController)?.selectedViewController == self
                    }
                    .subscribe(onNext: { [unowned self] viewController, animated in
                        self.showFooterView(isShow: self.reactor?.currentState.canTimeSetStart ?? false)
                    })
                    .disposed(by: self.disposeBag)
                
                self.tabBarController?.rx.didSelect
                    .filter { [unowned self] in
                        $0 == self
                    }
                    .subscribe(onNext: { [unowned self] viewController in
                        self.showFooterView(isShow: self.reactor?.currentState.canTimeSetStart ?? false)
                    })
                    .disposed(by: self.disposeBag)
            })
            .disposed(by: disposeBag)
    }
    
    func bind(reactor: TimeSetEditViewReactor) {
        // MARK: action
        rx.viewWillAppear
            .map { Reactor.Action.viewWillAppear }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        timerClearButton.rx.tap
            .do(onNext: { UIImpactFeedbackGenerator(style: .light).impactOccurred() })
            .map { Reactor.Action.clearTimer }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
    
        keyPadView.rx.keyPadTap
            .filter { $0 != .cancel }
            .map { [unowned self] in self.updateTime(key: $0) }
            .map { Reactor.Action.updateTime($0) }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        keyPadView.rx.keyPadTap
            .filter { $0 == .cancel }
            .subscribe(onNext: { [weak self] _ in self?.showTimeSetInitWarningAlert() })
            .disposed(by: disposeBag)
        
        timeKeyView.rx.tap
            .map { [unowned self] in self.getBaseTime(from: $0) }
            .map { Reactor.Action.addTime(base: $0) }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        timerBadgeCollectionView.rx.badgeSelected
            .flatMap { [weak self] in self?.selectBadge(at: $0.0, timerIndexPath: $0.1, cellType: $0.2) ?? .empty() }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        timerBadgeCollectionView.rx.badgeMoved
            .map { Reactor.Action.moveTimer(at: $0.0, to: $0.1) }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        saveButton.rx.tap
            .subscribe(onNext: { [weak self] in _ = self?.coordinator.present(for: .timeSetSave(reactor.timeSetInfo)) })
            .disposed(by: disposeBag)
        
        startButton.rx.tap
            .do(onNext: { [weak self] in _ = self?.coordinator.present(for: .timeSetProcess(reactor.timeSetInfo)) })
            .map { Reactor.Action.clearTimeSet }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        // MARK: state
        // Timer
        reactor.state
            .map { $0.endTime }
            .distinctUntilChanged()
            .bind(to: timerInputView.rx.timer)
            .disposed(by: disposeBag)
        
        // Time
        reactor.state
            .map { $0.time }
            .distinctUntilChanged()
            .map { $0 > 0 ? "\("productivity_time_input_prefix_title".localized)\($0)" : "" }
            .bind(to: timerInputLabel.rx.text)
            .disposed(by: disposeBag)
        
        // All time
        reactor.state
            .map { $0.allTime }
            .distinctUntilChanged()
            .map { getTime(interval: $0) }
            .map { String(format: "time_set_all_time_title_format".localized, $0.0, $0.1, $0.2) }
            .bind(to: allTimeLabel.rx.text)
            .disposed(by: disposeBag)
        
        // End of time set
        Observable.combineLatest(
            reactor.state
                .map { $0.allTime }
                .distinctUntilChanged(),
            Observable<Int>.timer(.seconds(0), period: .seconds(30), scheduler: ConcurrentDispatchQueueScheduler(qos: .default)))
            .map { Date().addingTimeInterval($0.0) }
            .map { getDateString(format: "time_set_end_time_format".localized, date: $0, locale: Locale(identifier: Constants.Locale.USA)) }
            .map { String(format: "time_set_end_time_title_format".localized, $0) }
            .bind(to: endOfTimeSetLabel.rx.text)
            .disposed(by: disposeBag)
        
        // Time info view
        reactor.state
            .map { $0.time > 0 || !$0.canTimeSetStart }
            .distinctUntilChanged()
            .bind(to: timeInfoView.rx.isHidden)
            .disposed(by: disposeBag)
        
        // Cancel key pad
        reactor.state
            .map { $0.timers.count <= 1 && !$0.canTimeSetStart }
            .distinctUntilChanged()
            .bind(to: keyPadView.cancelButton.rx.isHidden)
            .disposed(by: disposeBag)
        
        // Enable time key
        reactor.state
            .map { $0.time }
            .distinctUntilChanged()
            .withLatestFrom(reactor.state.map { $0.endTime }, resultSelector: { ($0, $1) })
            .map { [unowned self] in self.getEnableTimeKey(from: $0.0, timer: $0.1) }
            .bind(to: timeKeyView.rx.enableKey)
            .disposed(by: disposeBag)
        
        // View state (timer badge view & footer view visible)
        reactor.state
            .map { $0.canTimeSetStart }
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] in self?.setViewStateFrom(canTimeSetStart: $0) })
            .disposed(by: disposeBag)
        
        // Timer badge view
        reactor.state
            .filter { $0.shouldSectionReload }
            .map { $0.timers }
            .withLatestFrom(reactor.state.map { $0.isRepeat }, resultSelector: { ($0, $1) })
            .flatMap { [weak self] in self?.makeTimerBadgeItems(timers: $0.0, isRepeat: $0.1) ?? .empty() }
            .bind(to: timerBadgeCollectionView.rx.items)
            .disposed(by: disposeBag)
        
        reactor.state
            .map { $0.selectedIndexPath }
            .distinctUntilChanged()
            .do(onNext: { [weak self] in self?.scrollToBadgeIfCan(at: $0) }) // Scroll badge
            .bind(to: timerBadgeCollectionView.rx.selected)
            .disposed(by: disposeBag)
        
        // Alert
        reactor.state
            .map { $0.alertMessage }
            .filter { $0 != nil }
            .map { $0! }
            .subscribe(onNext: { [weak self] in self?.showAlert(message: $0) })
            .disposed(by: disposeBag)
    }

    // MARK: - action method
    override func handleHeaderAction(_ action: CommonHeader.Action) {
        super.handleHeaderAction(action)
        
        switch action {
        case .history:
            // TODO: Present history view
            break
            
        case .setting:
            _ = coordinator.present(for: .setting)
            
        default:
            break
        }
    }
    
    /// Convert number key pad input to time value
    private func updateTime(key: NumberKeyPad.Key) -> Int {
        guard let text = timerInputLabel.text else { return 0 }
        
        let prefix = "productivity_time_input_prefix_title".localized
        let range = Range(uncheckedBounds: (text.range(of: prefix)?.upperBound ?? text.startIndex, text.endIndex))
        var time = String(text[range])
        
        switch key {
        case .cancel:
            break
            
        case .back:
            guard !time.isEmpty else { return 0 }
            time.removeLast()
            
        default:
            time.append(String(key.rawValue))
        }
        
        return Int(time) ?? 0
    }
    
    /// Get base time (second) from key of time key view
    private func getBaseTime(from key: TimeKeyPad.Key) -> TimeInterval {
        switch key {
        case .hour:
            return Constants.Time.hour
        case .minute:
            return Constants.Time.minute
        case .second:
            return 1
        }
    }
    
    /// Convert badge select event to reactor action
    private func selectBadge(at indexPath: IndexPath, timerIndexPath: IndexPath?, cellType: TimerBadgeCellType) -> Observable<TimeSetEditViewReactor.Action> {
        switch cellType {
        case .regular(_):
            guard let timerIndexPath = timerIndexPath else { return .empty() }
            return .just(.selectTimer(at: timerIndexPath))
            
        case let .extra(type):
            switch type {
            case .add:
                return .just(.addTimer)
                
            case .repeat(_):
                return .just(.toggleRepeat)
            }
        }
    }
    
    // MARK: - state method
    /// Get enable time key from values of time & timer
    private func getEnableTimeKey(from time: Int, timer: TimeInterval) -> TimeKeyPad.Key {
        if timer + TimeInterval(time) * Constants.Time.minute > TimeSetEditViewReactor.MAX_TIME_INTERVAL {
            return .second
        } else if timer + TimeInterval(time) * Constants.Time.hour > TimeSetEditViewReactor.MAX_TIME_INTERVAL {
            return .minute
        } else {
            return .hour
        }
    }
    
    /// Timer bage view scroll to selected badge if can
    private func scrollToBadgeIfCan(at indexPath: IndexPath) {
        guard !isBadgeMoving else { return }
        timerBadgeCollectionView.scrollToBadge(at: indexPath, withExtraCells: true, animated: true)
    }
    
    /// Show/Hide view according to `canTimeSetStart` value
    private func setViewStateFrom(canTimeSetStart: Bool) {
        // Prevent tab bar swipe gesture
        if let tabBarController = tabBarController as? MainViewController {
            tabBarController.swipeEnable = !canTimeSetStart
        }
        
        // Show created timers
        timerBadgeCollectionView.isHidden = !canTimeSetStart
        if canTimeSetStart {
            timerBadgeCollectionView.scrollToBadge(at: IndexPath(item: 0, section: 0), animated: false)
        }
        
        // Show timer option footer view
        showFooterView(isShow: canTimeSetStart)
    }

    /// Make timer badge items
    private func makeTimerBadgeItems(timers: [TimerInfo], isRepeat: Bool) -> Observable<([TimerInfo], [TimerBadgeExtraCellType]?, [TimerBadgeExtraCellType]?)> {
        let leftExtraItems: [TimerBadgeExtraCellType]? = [.repeat(isRepeat)]
        let rightExtraItems: [TimerBadgeExtraCellType]? = timers.count < self.MAX_TIMER_COUNT ? [.add] : nil
        
        return .just((timers, leftExtraItems, rightExtraItems))
    }
    
    /// Show popup alert
    private func showAlert(message: String) {
        let alert = AlertBuilder(message: message).build()
        // Alert view controller dismiss after 1 seconds
        alert.rx.viewDidLoad
            .delay(.seconds(1), scheduler: MainScheduler.instance)
            .subscribe(onNext: { [weak alert] in alert?.dismiss(animated: true) })
            .disposed(by: disposeBag)
        
        // Present alert view controller
        present(alert, animated: true)
    }
    
    // MARK: - private method
    /// Show popup alert about warning to init time set
    private func showTimeSetInitWarningAlert() {
        guard let reactor = reactor else { return }
        
        let alert = AlertBuilder(title: "alert_warning_time_set_init_title".localized,
                                 message: "alert_warning_time_set_init_description".localized)
            .addAction(title: "alert_button_cancel".localized, style: .cancel)
            .addAction(title: "alert_button_yes".localized, style: .destructive, handler: { _ in
                reactor.action.onNext(.clearTimers)
            })
            .build()
        // Present warning alert view controller
        present(alert, animated: true)
    }
    
    /// Add footer view into tab bar controller's view to show top of the tab bar hierarchy
    private func addFooterView() {
        guard let tabBarController = tabBarController else { return }
        tabBarController.view.addSubview(footerView)
        
        let tabBar = tabBarController.tabBar
        var frame = tabBar.frame
        
        frame.size.height = tabBar.bounds.height + 10.adjust()
        // Positioning out of screen
        frame.origin.y += frame.height
        footerView.frame = frame
    }
    
    /// Show footer view (save & add & start)
    private func showFooterView(isShow: Bool, completion: (() -> Void)? = nil) {
        guard let tabBar = tabBarController?.tabBar, footerView.superview != nil else { return }
        
        var frame = footerView.frame
        frame.origin.y = isShow ? tabBar.frame.maxY - frame.height : tabBar.frame.minY + tabBar.frame.height
        
        let animator = UIViewPropertyAnimator(duration: 0.3, curve: .easeIn, animations: {
            self.footerView.frame = frame
        })
        
        animator.addCompletion({ position in
            if position == .end {
                completion?()
            }
        })
        
        animator.startAnimation()
    }
    
    // MARK: - selector
    @objc private func longPressHandler(gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: timerBadgeCollectionView.superview)
        
        switch gesture.state {
        case .began:
            isBadgeMoving = true
            timerBadgeCollectionView.beginInteractiveWithLocation(location)
            
        case .changed:
            timerBadgeCollectionView.updateInteractiveWithLocation(location)
            
        default:
            isBadgeMoving = false
            timerBadgeCollectionView.finishInteractive()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
    deinit {
        Logger.verbose()
    }
}
