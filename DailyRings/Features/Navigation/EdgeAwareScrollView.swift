import SwiftUI

struct EdgeAwareScrollView<Content: View>: View {
    let panelID: Int
    @Binding var topOverscroll: CGFloat
    @Binding var bottomOverscroll: CGFloat
    var onTransition: (VerticalEdge) -> Void
    var onHorizontalSwipe: ((Int) -> Void)?
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            content()
                .frame(maxWidth: .infinity)
                .background(
                    OverscrollMonitor(
                        panelID: panelID,
                        topOverscroll: $topOverscroll,
                        bottomOverscroll: $bottomOverscroll,
                        onTransition: onTransition,
                        onHorizontalSwipe: onHorizontalSwipe
                    )
                )
        }
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
    }
}

// MARK: - OverscrollMonitor

private struct OverscrollMonitor: UIViewRepresentable {
    let panelID: Int
    @Binding var topOverscroll: CGFloat
    @Binding var bottomOverscroll: CGFloat
    var onTransition: (VerticalEdge) -> Void
    var onHorizontalSwipe: ((Int) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> MonitorView {
        let view = MonitorView()
        view.coordinator = context.coordinator
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: MonitorView, context: Context) {
        context.coordinator.parent = self
        DispatchQueue.main.async {
            context.coordinator.findAndAttach(from: uiView)
        }
        if context.coordinator.currentPanelID != panelID {
            context.coordinator.currentPanelID = panelID
            context.coordinator.resetScrollPosition()
        }
    }

    // MARK: - MonitorView

    final class MonitorView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in
                self?.coordinator?.findAndAttach(from: self)
            }
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        var parent: OverscrollMonitor
        weak var scrollView: UIScrollView?
        var currentPanelID: Int

        private var offsetObservation: NSKeyValueObservation?
        private var transitionFired = false
        private var peakTop: CGFloat = 0
        private var peakBottom: CGFloat = 0
        private var addedGestures: [UIGestureRecognizer] = []

        private let overscrollThreshold: CGFloat = 55
        private let velocityThreshold: CGFloat = 800

        init(parent: OverscrollMonitor) {
            self.parent = parent
            self.currentPanelID = parent.panelID
        }

        deinit { detach() }

        func findAndAttach(from view: UIView?) {
            guard let sv = view?.findAncestorScrollView(),
                  sv !== scrollView else { return }
            detach()
            attach(to: sv)
        }

        func resetScrollPosition() {
            scrollView?.setContentOffset(.zero, animated: false)
            transitionFired = false
            peakTop = 0
            peakBottom = 0
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.parent.topOverscroll = 0
                self.parent.bottomOverscroll = 0
            }
        }

        // MARK: - Attach / Detach

        private func attach(to sv: UIScrollView) {
            scrollView = sv

            offsetObservation = sv.observe(\.contentOffset, options: .new) {
                [weak self] scrollView, _ in
                self?.onScroll(scrollView)
            }

            sv.panGestureRecognizer.addTarget(self, action: #selector(onPan))

            let left = UISwipeGestureRecognizer(
                target: self, action: #selector(onSwipeLeft)
            )
            left.direction = .left
            sv.addGestureRecognizer(left)
            addedGestures.append(left)

            let right = UISwipeGestureRecognizer(
                target: self, action: #selector(onSwipeRight)
            )
            right.direction = .right
            sv.addGestureRecognizer(right)
            addedGestures.append(right)
        }

        private func detach() {
            offsetObservation?.invalidate()
            offsetObservation = nil
            if let sv = scrollView {
                sv.panGestureRecognizer.removeTarget(
                    self, action: #selector(onPan)
                )
                for g in addedGestures {
                    sv.removeGestureRecognizer(g)
                }
            }
            addedGestures.removeAll()
            scrollView = nil
        }

        // MARK: - Scroll Tracking

        private func onScroll(_ sv: UIScrollView) {
            let y = sv.contentOffset.y
            let maxY = max(sv.contentSize.height - sv.bounds.height, 0)

            let top: CGFloat = y < 0 ? -y : 0
            let bottom: CGFloat = y > maxY ? y - maxY : 0

            peakTop = max(peakTop, top)
            peakBottom = max(peakBottom, bottom)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if top != self.parent.topOverscroll { self.parent.topOverscroll = top }
                if bottom != self.parent.bottomOverscroll { self.parent.bottomOverscroll = bottom }
            }
        }

        // MARK: - Pan Gesture (transition detection)

        @objc private func onPan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                transitionFired = false
                peakTop = 0
                peakBottom = 0
            case .ended, .cancelled:
                guard !transitionFired, let sv = scrollView else { return }
                let vy = gesture.velocity(in: sv).y

                if peakTop > overscrollThreshold
                    || (peakTop > 20 && vy > velocityThreshold) {
                    transitionFired = true
                    DispatchQueue.main.async { [weak self] in
                        self?.parent.onTransition(.top)
                    }
                } else if peakBottom > overscrollThreshold
                            || (peakBottom > 20 && vy < -velocityThreshold) {
                    transitionFired = true
                    DispatchQueue.main.async { [weak self] in
                        self?.parent.onTransition(.bottom)
                    }
                }
            default:
                break
            }
        }

        // MARK: - Horizontal Swipe (day navigation)

        @objc private func onSwipeLeft() {
            DispatchQueue.main.async { [weak self] in
                self?.parent.onHorizontalSwipe?(1)
            }
        }

        @objc private func onSwipeRight() {
            DispatchQueue.main.async { [weak self] in
                self?.parent.onHorizontalSwipe?(-1)
            }
        }
    }
}

// MARK: - UIView Ancestor Lookup

private extension UIView {
    func findAncestorScrollView() -> UIScrollView? {
        var current = superview
        while let view = current {
            if let sv = view as? UIScrollView { return sv }
            current = view.superview
        }
        return nil
    }
}
