import 'package:flutter/material.dart';

/// ===============================
/// ManagedTab
/// ===============================
class ManagedTab {
  final String title;
  final Widget child;
  final bool enabled;

  const ManagedTab({
    required this.title,
    required this.child,
    this.enabled = true,
  });
}

/// ===============================
/// TabManagerController
/// ===============================
class TabManagerController extends ChangeNotifier {
  int _index;

  TabManagerController({int initialIndex = 0}) : _index = initialIndex;

  int get index => _index;

  void jumpTo(int newIndex) {
    if (newIndex == _index) return;
    _index = newIndex;
    notifyListeners();
  }
}

/// ===============================
/// TabManager
/// ===============================
class TabManager extends StatefulWidget {
  final List<ManagedTab> tabs;
  final TabManagerController? controller;

  /// Swipe between tabs? Defaults to true.
  final bool swipeEnabled;

  /// PageView animation duration
  final Duration animationDuration;

  /// PageView animation curve
  final Curve animationCurve;

  const TabManager({
    super.key,
    required this.tabs,
    this.controller,
    this.swipeEnabled = true,
    this.animationDuration = const Duration(milliseconds: 250),
    this.animationCurve = Curves.easeOut,
  });

  @override
  State<TabManager> createState() => _TabManagerState();
}

class _TabManagerState extends State<TabManager> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.controller?.index ?? 0;
    _pageController = PageController(initialPage: _currentIndex);
    widget.controller?.addListener(_handleExternalChange);
  }

  void _handleExternalChange() {
    final index = widget.controller!.index;
    if (index == _currentIndex) return;

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: widget.animationDuration,
        curve: widget.animationCurve,
      );
    }
    setState(() => _currentIndex = index);
  }

  void _onTabTap(int index) {
    if (!widget.tabs[index].enabled) return;

    widget.controller?.jumpTo(index);

    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: widget.animationDuration,
        curve: widget.animationCurve,
      );
    }

    setState(() => _currentIndex = index);
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleExternalChange);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasBoundedHeight = constraints.maxHeight.isFinite;

        final content = hasBoundedHeight
            ? PageView(
                controller: _pageController,
                physics: widget.swipeEnabled
                    ? const PageScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  widget.controller?.jumpTo(index);
                  setState(() => _currentIndex = index);
                },
                children: widget.tabs.map((t) => t.child).toList(),
              )
            : widget.tabs[_currentIndex].child; // fallback for unbounded height

        return Column(
          mainAxisSize:
              hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
          children: [
            _buildHeader(context),
            hasBoundedHeight ? Expanded(child: content) : content,
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: List.generate(widget.tabs.length, (index) {
        final tab = widget.tabs[index];
        final active = index == _currentIndex;

        return Expanded(
          child: InkWell(
            onTap: tab.enabled ? () => _onTabTap(index) : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tab.title,
                    style: TextStyle(
                      fontWeight:
                          active ? FontWeight.bold : FontWeight.normal,
                      color: tab.enabled
                          ? (active ? Colors.blue : Colors.grey)
                          : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 3,
                    width: active ? 28 : 0,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
