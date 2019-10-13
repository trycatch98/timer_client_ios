//
//  TimeSetProcessViewController.swift
//  timer
//
//  Created by JSilver on 12/08/2019.
//  Copyright © 2019 Jeong Jin Eun. All rights reserved.
//

import RxSwift
import RxCocoa
import ReactorKit
import RxDataSources

class TimeSetProcessViewController: BaseHeaderViewController, View {
    // MARK: - view properties
    private var timeSetProcessView: TimeSetProcessView { return view as! TimeSetProcessView }
    
    private var titleLabel: UILabel { return timeSetProcessView.titleLabel }
    private var stateLabel: UILabel { return timeSetProcessView.stateLabel }
    private var timeLabel: UILabel { return timeSetProcessView.timeLabel }
    
    private var memoButton: RoundButton { return timeSetProcessView.memoButton }
    private var repeatButton: RoundButton { return timeSetProcessView.repeatButton }
    private var addTimeButton: RoundButton { return timeSetProcessView.addTimeButton }
    
    private var extraTimeLabel: UILabel { return timeSetProcessView.extraTimeLabel }
    
    private var allTimeLabel: UILabel { return timeSetProcessView.allTimeLabel }
    private var endOfTimeSetLabel: UILabel { return timeSetProcessView.endOfTimeSetLabel }
    private var alarmLabel: UILabel { return timeSetProcessView.alarmLabel }
    private var commentTextView: UITextView { return timeSetProcessView.commentTextView }
    
    private var timerBadgeCollectionView: TimerBadgeCollectionView { return timeSetProcessView.timerBadgeCollectionView }
    
    private var startButton: FooterButton { return timeSetProcessView.startButton }
    private var stopButton: FooterButton { return timeSetProcessView.stopButton }
    private var quitButton: FooterButton { return timeSetProcessView.quitButton }
    private var pauseButton: FooterButton { return timeSetProcessView.pauseButton }
    
    private var footerView: Footer { return timeSetProcessView.footerView }
    
    private var timeSetPopup: TimeSetPopup? {
        didSet { oldValue?.removeFromSuperview() }
    }
    private var timeSetAlert: TimeSetAlert? {
        didSet {
            oldValue?.removeFromSuperview()
            timerBadgeCollectionView.isScrollEnabled = timeSetAlert == nil
        }
    }
    
    // MARK: - properties
    var coordinator: TimeSetProcessViewCoordinator
    
    private lazy var dataSource = RxCollectionViewSectionedAnimatedDataSource<TimerBadgeSectionModel>(configureCell: { (dataSource, collectionView, indexPath, cellType) -> UICollectionViewCell in
        switch cellType {
        case let .regular(reactor):
            guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TimerBadgeCollectionViewCell.name, for: indexPath) as? TimerBadgeCollectionViewCell else { fatalError() }
            cell.reactor = reactor
            return cell
            
        case .extra(_):
            fatalError("This view can't present extra cells of timer badge collection view")
        }
    })
    
    // Dispose bags
    private var popupDisposeBag = DisposeBag()
    private var alertDisposeBag = DisposeBag()
    
    // MARK: - constructor
    init(coordinator: TimeSetProcessViewCoordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - lifecycle
    override func loadView() {
        view = TimeSetProcessView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.setNeedsLayout()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Set navigation controller's pop gesture disable
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Set navigation controller's pop gesture enable
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    // MARK: - bine
    func bind(reactor: TimeSetProcessViewReactor) {
        // MARK: action
        rx.viewWillAppear
            .map { Reactor.Action.viewWillAppear }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        // Init badge
        rx.viewDidLayoutSubviews
            .takeUntil(rx.viewDidAppear)
            .withLatestFrom(reactor.state.map { $0.selectedIndex })
            .map { IndexPath(item: $0, section: TimerBadgeSectionType.regular.rawValue) }
            .subscribe(onNext: { [weak self] in self?.timerBadgeCollectionView.scrollToBadge(at: $0, animated: false) })
            .disposed(by: disposeBag)
        
        memoButton.rx.tap
            .do(onNext: { UIImpactFeedbackGenerator(style: .light).impactOccurred() })
            .subscribe(onNext: { [weak self] in
                guard let viewController = self?.coordinator.present(for: .timeSetMemo(reactor.timeSet.info)) as? TimeSetMemoViewController else { return }
                self?.bind(memo: viewController)
            })
            .disposed(by: disposeBag)
        
        repeatButton.rx.tap
            .do(onNext: { UIImpactFeedbackGenerator(style: .light).impactOccurred() })
            .map { Reactor.Action.toggleRepeat }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        addTimeButton.rx.tap
            .do(onNext: { UIImpactFeedbackGenerator(style: .light).impactOccurred() })
            .map { Reactor.Action.addExtraTime(TimeInterval(Constants.Time.minute)) }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        timerBadgeCollectionView.rx.itemSelected
            .do(onNext: { _ in UIImpactFeedbackGenerator(style: .light).impactOccurred() })
            .filter { $0.section == TimerBadgeSectionType.regular.rawValue }
            .withLatestFrom(reactor.state.map { $0.timeSetState }.distinctUntilChanged(), resultSelector: { ($0, $1) })
            .compactMap { [weak self] in self?.badgeSelect(at: $0.0, withTimeSetState: $0.1) }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        startButton.rx.tap
            .map { Reactor.Action.startTimeSet(at: nil) }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        Observable.merge(stopButton.rx.tap.asObservable(),
                         quitButton.rx.tap.asObservable())
            .map { Reactor.Action.stopTimeSet }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        pauseButton.rx.tap
            .map { Reactor.Action.pauseTimeSet }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        // MARK: state
        // Title
        reactor.state
            .map { $0.title }
            .distinctUntilChanged()
            .bind(to: titleLabel.rx.text)
            .disposed(by: disposeBag)
        
        // Time
        reactor.state
            .map { $0.time }
            .distinctUntilChanged()
            .map { getTime(interval: $0) }
            .map { String(format: "time_set_time_format".localized, $0.0, $0.1, $0.2) }
            .bind(to: timeLabel.rx.text)
            .disposed(by: disposeBag)
        
        // Repeat
        reactor.state
            .map { $0.isRepeat }
            .distinctUntilChanged()
            .bind(to: repeatButton.rx.isSelected)
            .disposed(by: disposeBag)
        
        // Add time
//        reactor.state
//            .map { $0.extraTime < TimeSetProcessViewReactor.MAX_EXTRA_TIME }
//            .distinctUntilChanged()
//            .bind(to: addTimeButton.rx.isEnabled)
//            .disposed(by: disposeBag)
        
        // Extra time
        reactor.state
            .map { $0.extraTime == 0 }
            .distinctUntilChanged()
            .bind(to: extraTimeLabel.rx.isHidden)
            .disposed(by: disposeBag)
        
        reactor.state
            .map { $0.extraTime }
            .distinctUntilChanged()
            .map { Int($0 / Constants.Time.minute) }
            .map { String(format: "time_set_process_extra_time_format".localized, $0) }
            .bind(to: extraTimeLabel.rx.text)
            .disposed(by: disposeBag)
        
        // All time
        reactor.state
            .map { $0.allTime }
            .distinctUntilChanged()
            .map { getTime(interval: $0) }
            .map { String(format: "time_set_time_format".localized, $0.0, $0.1, $0.2) }
            .bind(to: allTimeLabel.rx.text)
            .disposed(by: disposeBag)
        
        // End of time set
        Observable.combineLatest(
            reactor.state.map { $0.remainedTime }.distinctUntilChanged(),
            Observable<Int>.timer(.seconds(0), period: .seconds(30), scheduler: ConcurrentDispatchQueueScheduler(qos: .default)))
            .observeOn(MainScheduler.instance)
            .takeUntil( // Take until time set is running
                reactor.state
                    .map { $0.timeSetState }
                    .distinctUntilChanged()
                    .filter { [weak self] in self?.isTimeSetEnded(state: $0) ?? false })
            .map { Date().addingTimeInterval($0.0) }
            .map { getDateString(format: "time_set_end_time_format".localized, date: $0, locale: Locale(identifier: Constants.Locale.USA)) }
            .bind(to: endOfTimeSetLabel.rx.text)
            .disposed(by: disposeBag)
        
        // Alarm
        reactor.state
            .map { $0.timer }
            .distinctUntilChanged { $0 === $1 }
            .map { $0.alarm.title }
            .bind(to: alarmLabel.rx.text)
            .disposed(by: disposeBag)
        
        // Comment
        reactor.state
            .map { $0.timer }
            .distinctUntilChanged { $0 === $1 }
            .map { $0.comment }
            .bind(to: commentTextView.rx.text)
            .disposed(by: disposeBag)
        
        // Timer badge
        reactor.state
            .filter { $0.shouldSectionReload }
            .map { $0.sections }
            .bind(to: timerBadgeCollectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)
        
        reactor.state
            .map { $0.selectedIndex }
            .distinctUntilChanged()
            .map { IndexPath(item: $0, section: TimerBadgeSectionType.regular.rawValue) }
            .subscribe(onNext: { [weak self] in self?.scrollBadgeIfCan(at: $0) })
            .disposed(by: disposeBag)

        // Timer end popup
        reactor.state
            .map { $0.selectedIndex }
            .distinctUntilChanged()
            .skip(1)
            .withLatestFrom(reactor.state.map { ($0.sections[TimerBadgeSectionType.regular.rawValue].items.count, $0.timeSetState) },
                            resultSelector: { ($0, $1.0, $1.1) })
            .filter { $2 == .run(detail: .normal) }
            .subscribe(onNext: { [weak self] in
                self?.showTimeSetPopup(title: String(format: "time_set_popup_timer_end_title_format".localized, $0.0),
                                       subtitle: String(format: "time_set_popup_timer_end_info_format".localized, $0.0, $0.1)) })
            .disposed(by: disposeBag)
        
        // Time set state
        Observable.combineLatest(
            reactor.state.map { $0.countdown }.distinctUntilChanged(),
            reactor.state.map { $0.countdownState }.distinctUntilChanged(),
            reactor.state.map { $0.repeatCount }.distinctUntilChanged(),
            reactor.state.map { $0.timeSetState }.distinctUntilChanged())
            .compactMap { [weak self] in self?.getTimeSetState(countdown: $0.0, countdownState: $0.1, repeatCount: $0.2, timeSetState: $0.3) }
            .bind(to: stateLabel.rx.attributedText)
            .disposed(by: disposeBag)
        
        Observable.combineLatest(
            reactor.state
                .map { $0.timeSetState }
                .distinctUntilChanged(),
            rx.viewWillAppear
                .take(1))
            .map { $0.0 }
            .subscribe(onNext: { [weak self] in self?.updateLayoutByTimeSetState($0) })
            .disposed(by: self.disposeBag)
        
        reactor.state
            .map { $0.countdownState }
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] in self?.updateLayoutByCountdownState($0) })
            .disposed(by: disposeBag)
        
        reactor.state
            .map { $0.shouldDismiss }
            .distinctUntilChanged()
            .filter { $0 }
            .subscribe(onNext: { [weak self] _ in self?.navigationController?.popViewController(animated: true) })
            .disposed(by: disposeBag)
    }
    
    func bind(memo viewController: TimeSetMemoViewController) {
        guard let reactor = reactor else { return }
        
        // Close
        viewController.rx.tapHeader
            .filter { $0 == .close }
            .withLatestFrom(reactor.state.map { $0.timeSetState })
            .filter { $0 == .end(detail: .normal) }
            .subscribe(onNext: { [weak self] _ in
                guard let viewController = self?.coordinator.present(for: .timeSetEnd(reactor.timeSet.info)) as? TimeSetEndViewController else { return }
                self?.bind(end: viewController)
            })
            .disposed(by: disposeBag)
    }
    
    func bind(end viewController: TimeSetEndViewController) {
        guard let reactor = reactor else { return }
        
        // Close
        viewController.rx.tapHeader
            .filter { $0 == .close }
            .subscribe(onNext: { [weak self] _ in self?.dismissOrPopViewController(animated: false) })
            .disposed(by: disposeBag)
        
        // Overtime record
        viewController.rx.tapOvertime
            .map { Reactor.Action.startOvertimeRecord }
            .bind(to: reactor.action)
            .disposed(by: disposeBag)
        
        // Restart
        viewController.rx.tapRestart
            .subscribe(onNext: { [weak self] in _ = self?.coordinator.present(for: .timeSetProcess(reactor.timeSetInfo)) })
            .disposed(by: disposeBag)
    }
    
    func bind(popup: TimeSetPopup) {
        // Dispose previous event stream
        popupDisposeBag = DisposeBag()
        
        Observable<Int>.interval(.seconds(10), scheduler: MainScheduler.instance)
            .take(1)
            .subscribe(onNext: { [weak self] _ in self?.dismissTimeSetPopup() })
            .disposed(by: popupDisposeBag)
        
        popup.confirmButton.rx.tap
            .subscribe(onNext: { [weak self] in self?.dismissTimeSetPopup() })
            .disposed(by: popupDisposeBag)
    }
    
    func bind(alert: TimeSetAlert, confirmHandler: @escaping () -> Void) {
        alertDisposeBag = DisposeBag()

        alert.cancelButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.timeSetAlert = nil
            })
            .disposed(by: alertDisposeBag)
        
        alert.confirmButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.timeSetAlert = nil
                confirmHandler()
            })
            .disposed(by: alertDisposeBag)
    }
    
    // MARK: - action method
    /// Handle badge select action with time set state
    private func badgeSelect(at indexPath: IndexPath, withTimeSetState state: TimeSet.State) -> TimeSetProcessViewReactor.Action? {
        switch state {
        case .initialize,
             .pause,
             .run(detail: .normal):
            timerBadgeCollectionView.scrollToBadge(at: indexPath, animated: true)
            showTimerStartAlert(at: indexPath)
            
        case .run(detail: .overtime),
             .end(detail: _):
            return .selectTimer(at: indexPath.row)
            
        default:
            break
        }
        
        return nil
    }
    
    /// Timer bage view scroll to selected badge if can
    private func scrollToBadgeIfCan(at indexPath: IndexPath) {
        guard timeSetAlert == nil else { return }
        timerBadgeCollectionView.scrollToBadge(at: indexPath, animated: true)
    }
    
    /// Show start timer with selected index alert
    private func showTimerStartAlert(at indexPath: IndexPath) {
        // Create alert & binding
        let timeSetAlert = TimeSetAlert(text: String(format: "time_set_alert_timer_start_title_format".localized, indexPath.row + 1))
        bind(alert: timeSetAlert) { [weak self] in
            self?.reactor?.action.onNext(.startTimeSet(at: indexPath.row))
        }
        
        // Set constraint of alert
        view.addAutolayoutSubview(timeSetAlert)
        timeSetAlert.snp.makeConstraints { make in
            make.leading.equalTo(timerBadgeCollectionView).inset(60.adjust())
            make.bottom.equalTo(timerBadgeCollectionView.snp.top).inset(-3.adjust())
        }

        self.timeSetAlert = timeSetAlert
    }
    
    // MARK: - state method
    /// Get is time set ended
    private func isTimeSetEnded(state: TimeSet.State) -> Bool {
        guard case .end(detail: _) = state else { return false }
        return true
    }
    
    /// Scroll badge if view can scroll
    private func scrollBadgeIfCan(at indexPath: IndexPath) {
        guard timeSetAlert == nil else { return }
        timerBadgeCollectionView.scrollToBadge(at: indexPath, animated: true)
    }
    
    /// Get current time set state string
    /// - parameters:
    ///   - countdown: remained countdown time of the time set
    ///   - countdownState: current state of the countdown timer
    ///   - repeatCount: repeated count of the time set
    ///   - timeSetState: current state of the time set
    /// - returns: the attributed string text of current time set state
    private func getTimeSetState(countdown: Int, countdownState: TMTimer.State, repeatCount: Int, timeSetState: TimeSet.State) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: Constants.Font.Regular.withSize(10.adjust()),
            .foregroundColor: Constants.Color.codGray]
        
        switch countdownState {
        case .run:
            if countdown > 0 {
                return NSAttributedString(string: String(format: "time_set_state_countdown_format".localized, countdown), attributes: attributes)
            }
            
        case .pause:
            return NSAttributedString(string: "time_set_state_pause_title".localized, attributes: attributes)
            
        default:
            break
        }
        
        var currentState: String
        switch timeSetState {
        case .pause:
            return NSAttributedString(string: "time_set_state_pause_title".localized, attributes: attributes)
            
        case .run(detail: .overtime),
             .end(detail: .overtime):
            currentState = "time_set_state_overtime_title".localized
            attributes = [
                .font: Constants.Font.Bold.withSize(10.adjust()),
                .foregroundColor: Constants.Color.carnation]
            
        default:
            currentState = ""
        }
        
        if repeatCount > 0 {
            if !currentState.isEmpty {
                currentState += ", "
            }
            
            currentState += String(format: "time_set_state_repeat_format".localized, repeatCount)
        }
        
        return NSAttributedString(string: currentState, attributes: attributes)
    }
    
    /// Update layout by countdown state
    private func updateLayoutByCountdownState(_ state: TMTimer.State) {
        switch state {
        case .run:
            footerView.buttons = [stopButton, pauseButton]
            
        case .pause:
            footerView.buttons = [stopButton, startButton]
            
        default:
            break
        }
    }
    
    /// Update layout by current state of time set
    private func updateLayoutByTimeSetState(_ state: TimeSet.State) {
        UIApplication.shared.isIdleTimerDisabled = false
        
        switch state {
        case let .stop(repeat: count):
            if count > 0 {
                // Show time set repeat popup
                showTimeSetPopup(title: "time_set_popup_time_set_repeat_title".localized,
                                 subtitle: String(format: "time_set_popup_time_set_repeat_info_format".localized, count))
            }
            
        case let .run(detail: runState):
            // Prevent screen off when timer running
            UIApplication.shared.isIdleTimerDisabled = true
            
            if runState == .normal {
                // Running time set
                footerView.buttons = [stopButton, pauseButton]
                
                // Set view enable
                timeSetProcessView.isEnabled = true
            } else {
                // Running overtime recording
                footerView.buttons = [quitButton, pauseButton]
                
                // Set view disabled
                timeSetProcessView.isEnabled = false
                timeLabel.textColor = Constants.Color.carnation
            }
            
        case .pause:
            // Update hightlight button to restart button
            guard let button = footerView.buttons.first else { return }
            footerView.buttons = [button, startButton]
        
        case .end(detail: .normal):
            // Remove alert
            timeSetAlert = nil
            
            guard self.presentedViewController == nil,
                let reactor = reactor,
                let viewController = coordinator.present(for: .timeSetEnd(reactor.timeSet.info)) as? TimeSetEndViewController else { return }
            bind(end: viewController)
            
        default:
            break
        }
    }
    
    // MARK: - private method
    /// Show timer & time set info popup
    private func showTimeSetPopup(title: String, subtitle: String) {
        // Create popup view
        let timeSetPopup = TimeSetPopup(origin: CGPoint(x: 0, y: UIScreen.main.bounds.height))
        timeSetPopup.frame.origin.x = (view.bounds.width - timeSetPopup.frame.width) / 2
        
        // Set properties
        timeSetPopup.title = title
        timeSetPopup.subtitle = subtitle
        
        // Add subview & binding
        view.addSubview(timeSetPopup)
        bind(popup: timeSetPopup)

        // Show view with animation
        timeSetPopup.show {
            self.timeSetPopup = timeSetPopup
        }
    }
    
    /// Dismiss timer & time set info popup
    private func dismissTimeSetPopup() {
        // Dismiss view with animation
        timeSetPopup?.dismiss {
            self.timeSetPopup = nil
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
    deinit {
        Logger.verbose()
    }
}