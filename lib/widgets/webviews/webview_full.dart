import 'dart:async';
import 'dart:collection';
import 'package:animations/animations.dart';
import 'package:bot_toast/bot_toast.dart';
import 'package:bubble_showcase/bubble_showcase.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:speech_bubble/speech_bubble.dart';
import 'package:torn_pda/models/items_model.dart';
import 'package:torn_pda/models/travel/foreign_stock_out.dart';
import 'package:torn_pda/providers/settings_provider.dart';
import 'package:torn_pda/providers/trades_provider.dart';
import 'package:torn_pda/providers/user_details_provider.dart';
import 'package:torn_pda/providers/theme_provider.dart';
import 'package:torn_pda/utils/api_caller.dart';
import 'package:torn_pda/utils/js_snippets.dart';
import 'package:torn_pda/utils/shared_prefs.dart';
import 'package:torn_pda/pages/city/city_options.dart';
import 'package:torn_pda/widgets/city/city_widget.dart';
import 'package:torn_pda/widgets/crimes/crimes_widget.dart';
import 'package:torn_pda/pages/crimes/crimes_options.dart';
import 'package:torn_pda/widgets/quick_items/quick_items_widget.dart';
import 'package:torn_pda/pages/quick_items/quick_items_options.dart';
import 'package:http/http.dart' as http;
import 'package:torn_pda/pages/trades/trades_options.dart';
import 'package:torn_pda/widgets/trades/trades_widget.dart';
import 'package:torn_pda/widgets/webviews/custom_appbar.dart';
import 'package:torn_pda/widgets/other/profile_check.dart';
import 'package:torn_pda/providers/quick_items_provider.dart';
import 'package:torn_pda/widgets/webviews/webview_url_dialog.dart';
import 'package:dotted_border/dotted_border.dart';

class VaultsOptions {
  String description;

  VaultsOptions({this.description}) {
    switch (description) {
      case "Personal vault":
        break;
      case "Faction vault":
        break;
      case "Company vault":
        break;
    }
  }
}

class WebViewFull extends StatefulWidget {
  final String customTitle;
  final String customUrl;
  final Function customCallBack;
  final bool dialog;

  WebViewFull({
    this.customUrl = 'https://www.torn.com',
    this.customTitle = '',
    this.customCallBack,
    this.dialog = false,
  });

  @override
  _WebViewFullState createState() => _WebViewFullState();
}

class _WebViewFullState extends State<WebViewFull> {
  InAppWebViewController webView;
  URLRequest _initialUrl;
  String _pageTitle = "";
  String _currentUrl = '';

  bool _backButtonPopsContext = true;

  var _travelAbroad = false;

  var _crimesActive = false;
  var _crimesController = ExpandableController();

  var _tradesFullActive = false;
  var _tradesIconActive = false;
  Widget _tradesExpandable = SizedBox.shrink();
  bool _tradesPreferencesLoaded = false;
  bool _tradeCalculatorEnabled = false;

  DateTime _lastTradeCall = DateTime.now();
  // Sometimes the first call to trades will not detect that we are in, hence
  // travel icon won't show and [_decideIfCallTrades] won't trigger again. This
  // way we allow it to trigger again.
  bool _lastTradeCallWasIn = false;

  var _cityEnabled = false;
  var _cityIconActive = false;
  bool _cityPreferencesLoaded = false;
  var _errorCityApi = false;
  var _cityItemsFound = <Item>[];
  Widget _cityExpandable = SizedBox.shrink();

  var _bazaarActive = false;
  var _bazaarFillActive = false;

  var _chatRemovalEnabled = false;
  var _chatRemovalActive = false;

  var _quickItemsActive = false;
  var _quickItemsController = ExpandableController();

  // Allow onProgressChanged to call several sections, for better responsiveness,
  // while making sure that we don't call the API each time
  bool _crimesTriggered = false;
  bool _quickItemsTriggered = false;
  bool _cityTriggered = false;
  bool _tradesTriggered = false;

  Widget _profileAttackExpandable = SizedBox.shrink();
  var _profileAttackController = ExpandableController();
  var _profileTriggered = false;
  var _attackTriggered = false;

  var _showOne = GlobalKey();
  UserDetailsProvider _userProvider;

  final _popupOptionsChoices = <VaultsOptions>[
    VaultsOptions(description: "Personal vault"),
    VaultsOptions(description: "Faction vault"),
    VaultsOptions(description: "Company vault"),
  ];

  bool _scrollAfterLoad = false;
  int _scrollY = 0;
  int _scrollX = 0;

  double progress = 0;

  SettingsProvider _settingsProvider;
  ThemeProvider _themeProvider;

  String path;

  @override
  void initState() {
    super.initState();
    _loadChatPreferences();
    _settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    _initialUrl = URLRequest(
        url: Uri.parse(widget.customUrl),
        headers: <String, String>{'test_header': 'flutter_test_header'});
    _pageTitle = widget.customTitle;
  }

  @override
  Widget build(BuildContext context) {
    _userProvider = Provider.of<UserDetailsProvider>(context, listen: false);
    _themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    return WillPopScope(
      onWillPop: _willPopCallback,
      // If we are launching from a dialog, it's important not to add the show case, in
      // case this is the first time, as there is no appBar to be found and it would
      // failed to open
      child: widget.dialog
          ? BubbleShowcase(
              // KEEP THIS UNIQUE
              bubbleShowcaseId: 'webview_dialog_showcase',
              // WILL SHOW IF VERSION CHANGED
              bubbleShowcaseVersion: 1,
              showCloseButton: false,
              doNotReopenOnClose: true,
              counterText: "",
              bubbleSlides: [
                AbsoluteBubbleSlide(
                  positionCalculator: (size) => Position(
                    top: 0,
                    right: 0,
                    bottom: 0,
                    left: 0,
                  ),
                  child: AbsoluteBubbleSlideChild(
                    positionCalculator: (size) => Position(
                      top: size.height / 2,
                      left: (size.width - 200) / 2,
                    ),
                    widget: SpeechBubble(
                      width: 200,
                      nipLocation: NipLocation.BOTTOM,
                      nipHeight: 0,
                      color: Colors.green[800],
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Text(
                          'NEW!\n\n'
                          'Did you know?\n\n'
                          'Long press the bottom bar of the quick browser to open a '
                          'menu with additional options\n\n'
                          'GIVE IT A TRY!',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              child: buildScaffold(context),
            )
          : BubbleShowcase(
              // KEEP THIS UNIQUE
              bubbleShowcaseId: 'webview_full_showcase',
              // WILL SHOW IF VERSION CHANGED
              bubbleShowcaseVersion: 2,
              showCloseButton: false,
              doNotReopenOnClose: true,
              counterText: "",
              bubbleSlides: [
                RelativeBubbleSlide(
                  shape: Rectangle(spreadRadius: 10),
                  widgetKey: _showOne,
                  child: RelativeBubbleSlideChild(
                    direction: _settingsProvider.appBarTop
                        ? AxisDirection.down
                        : AxisDirection.up,
                    widget: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SpeechBubble(
                        nipLocation: _settingsProvider.appBarTop
                            ? NipLocation.TOP
                            : NipLocation.BOTTOM,
                        color: Colors.green[800],
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: Text(
                            'NEW!\n\n'
                            'Did you know?\n\n'
                            'Tap page title to open a menu with additional options\n\n'
                            'Swipe page title left/right to browse forward/back\n\n'
                            'GIVE IT A TRY!',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              child: buildScaffold(context),
            ),
    );
  }

  Widget buildScaffold(BuildContext context) {
    return Container(
      color: _themeProvider.currentTheme == AppTheme.light
          ? Colors.blueGrey
          : Colors.grey[900],
      child: SafeArea(
        top: _settingsProvider.appBarTop ? false : true,
        bottom: true,
        child: Scaffold(
          appBar: widget.dialog
              // Show appBar only if we are not showing the webView in a dialog
              ? null
              : _settingsProvider.appBarTop
                  ? buildCustomAppBar()
                  : null,
          bottomNavigationBar: widget.dialog
              // Show appBar only if we are not showing the webView in a dialog
              ? null
              : !_settingsProvider.appBarTop
                  ? SizedBox(
                      height: AppBar().preferredSize.height,
                      child: buildCustomAppBar(),
                    )
                  : null,
          body: Container(
            // Background color for all browser widgets
            color: Colors.grey[900],
            child: widget.dialog
                ? Column(
                    children: [
                      Expanded(child: mainWebViewColumn()),
                      Container(
                        color: _themeProvider.currentTheme == AppTheme.light
                            ? Colors.white
                            : _themeProvider.background,
                        height: 38,
                        child: GestureDetector(
                          onLongPress: () => _openCustomUrlDialog(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 100,
                                child: Row(
                                  children: [
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        customBorder: new CircleBorder(),
                                        splashColor: Colors.blueGrey,
                                        child: SizedBox(
                                          width: 40,
                                          child: Icon(
                                            Icons.arrow_back_ios_outlined,
                                            size: 20,
                                          ),
                                        ),
                                        onTap: () async {
                                          _tryGoBack();
                                        },
                                      ),
                                    ),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        customBorder: new CircleBorder(),
                                        splashColor: Colors.blueGrey,
                                        child: SizedBox(
                                          width: 40,
                                          child: Icon(
                                            Icons.arrow_forward_ios_outlined,
                                            size: 20,
                                          ),
                                        ),
                                        onTap: () async {
                                          _tryGoForward();
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: TextButton(
                                    child: Text("Close"),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                ),
                              ),
                              SizedBox(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    _travelHomeIcon(),
                                    _chatRemovalEnabled
                                        ? _hideChatIcon()
                                        : SizedBox.shrink(),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          customBorder: new CircleBorder(),
                                          splashColor: Colors.blueGrey,
                                          child: Icon(Icons.refresh),
                                          onTap: () async {
                                            _scrollX =
                                                await webView.getScrollX();
                                            _scrollY =
                                                await webView.getScrollY();
                                            await webView.reload();
                                            _scrollAfterLoad = true;
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : mainWebViewColumn(),
          ),
        ),
      ),
    );
  }

  Column mainWebViewColumn() {
    return Column(
      children: [
        _settingsProvider.loadBarBrowser
            ? Container(
                height: 2,
                child: progress < 1.0
                    ? LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.blueGrey[100],
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.deepOrange[300]),
                      )
                    : Container(height: 2),
              )
            : SizedBox.shrink(),
        // Crimes widget. NOTE: this one will open at the bottom if
        // appBar is at the bottom, so it's duplicated below the actual
        // webView widget
        _profileAttackExpandable,
        _settingsProvider.appBarTop
            ? ExpandablePanel(
                theme: ExpandableThemeData(
                  hasIcon: false,
                  tapBodyToCollapse: false,
                  tapHeaderToExpand: false,
                ),
                collapsed: SizedBox.shrink(),
                controller: _crimesController,
                header: SizedBox.shrink(),
                expanded: _crimesActive
                    ? CrimesWidget(
                        controller: webView,
                        appBarTop: _settingsProvider.appBarTop,
                        browserDialog: widget.dialog,
                      )
                    : SizedBox.shrink(),
              )
            : SizedBox.shrink(),
        // Quick items widget. NOTE: this one will open at the bottom if
        // appBar is at the bottom, so it's duplicated below the actual
        // webView widget
        _settingsProvider.appBarTop
            ? ExpandablePanel(
                theme: ExpandableThemeData(
                  hasIcon: false,
                  tapBodyToCollapse: false,
                  tapHeaderToExpand: false,
                ),
                collapsed: SizedBox.shrink(),
                controller: _quickItemsController,
                header: SizedBox.shrink(),
                expanded: _quickItemsActive
                    ? QuickItemsWidget(
                        inAppWebViewController: webView,
                        appBarTop: _settingsProvider.appBarTop,
                        browserDialog: widget.dialog,
                        webviewType: 'inapp',
                      )
                    : SizedBox.shrink(),
              )
            : SizedBox.shrink(),
        // Trades widget
        _tradesExpandable,
        // City widget
        _cityExpandable,
        // Actual WebView
        Expanded(
          child: InAppWebView(
            initialUrlRequest: _initialUrl,
            initialUserScripts: UnmodifiableListView<UserScript>([lala]),
            initialOptions: InAppWebViewGroupOptions(
              crossPlatform: InAppWebViewOptions(
                  // This is deactivated as it interferes with hospital timer,
                  // company applications, etc.
                  //useShouldInterceptAjaxRequest: true,
                  ),
              android: AndroidInAppWebViewOptions(
                useHybridComposition: true,
              ),
            ),
            /*
            shouldInterceptAjaxRequest:
                (InAppWebViewController c, AjaxRequest x) async {
              // This will intercept ajax calls performed when the bazaar reached 100 items
              // and needs to be reloaded, so that we can remove and add again the fill buttons
              if (x == null) return x;
              if (x.data == null) return x;
              if (x.url == null) return x;

              if (x.data.contains("step=getList&type=All&start=") &&
                  x.url.contains('inventory.php') &&
                  _bazaarActive &&
                  _bazaarFillActive) {
                webView.evaluateJavascript(
                    source: removeBazaarFillButtonsJS());
                Future.delayed(const Duration(seconds: 2))
                    .then((value) {
                  webView.evaluateJavascript(
                      source: addBazaarFillButtonsJS());
                });
              }
              return x;
            },
            */
            onWebViewCreated: (InAppWebViewController c) {
              webView = c;
            },
            onLoadStart: (InAppWebViewController c, Uri url) async {
              _hideChat();

              _currentUrl = url.path;

              var html = await webView.getHtml();
              var document = parse(html);
              _assessGeneral(document);
            },
            onProgressChanged: (InAppWebViewController c, int progress) async {
              if (_settingsProvider.removeAirplane) {
                webView.evaluateJavascript(source: travelRemovePlaneJS());
              }

              _hideChat();

              setState(() {
                this.progress = progress / 100;
              });

              // onProgressChanged gets called before onLoadStart, so it works
              // both to add or remove widgets. It is much faster.
              _assessSectionsWithWidgets();
              // We reset here the triggers for the sections that are called every
              // time so that they can be called again
              _resetSectionsWithWidgets();
            },
            onLoadStop: (InAppWebViewController c, Uri url) async {
              _currentUrl = url.path;

              _hideChat();
              _highlightChat();

              var html = await webView.getHtml();
              var document = parse(html);
              // Force to show title
              _getPageTitle(document, showTitle: true);
              _assessGeneral(document);

              // This is used in case the user presses reload. We need to wait for the page
              // load to be finished in order to scroll
              if (_scrollAfterLoad) {
                webView.scrollTo(x: _scrollX, y: _scrollY, animated: false);
                _scrollAfterLoad = false;
              }
            },
            // Allows IOS to open links with target=_blank
            onCreateWindow: (InAppWebViewController c, CreateWindowAction r) {
              webView.loadUrl(urlRequest: r.request);
              return;
            },
            onConsoleMessage: (InAppWebViewController c, consoleMessage) async {
              if (consoleMessage.message != "")
                print("TORN PDA JS CONSOLE: " + consoleMessage.message);

              /// TRADES
              /// We are calling trades from here because onLoadStop does not
              /// work inside of Trades for iOS. Also, both in Android and iOS
              /// we need to catch deletions that happen with a console message
              /// of "hash.step".
              if (consoleMessage.message.contains('hash.step') &&
                  _currentUrl.contains('trade.php')) {
                _tradesTriggered = true;
                _currentUrl = (await webView.getUrl()).path;
                var html = await webView.getHtml();
                var document = parse(html);
                var pageTitle = (await _getPageTitle(document)).toLowerCase();
                _assessTrades(document, pageTitle);
              }

              /// FORUMS URL FOR IOS (not triggered in other WebView events).
              /// Needed for URL copy and shortcuts.
              if (consoleMessage.message.contains('CONTENT LOADED')) {
                await webView.getUrl().then((value) {
                  _currentUrl = value.path;
                });
              }
            },
          ),
        ),
        // Widgets that go at the bottom if we have changes appbar to bottom
        !_settingsProvider.appBarTop
            ? ExpandablePanel(
                theme: ExpandableThemeData(
                  hasIcon: false,
                  tapBodyToCollapse: false,
                  tapHeaderToExpand: false,
                ),
                collapsed: SizedBox.shrink(),
                controller: _crimesController,
                header: SizedBox.shrink(),
                expanded: _crimesActive
                    ? CrimesWidget(
                        controller: webView,
                        appBarTop: _settingsProvider.appBarTop,
                        browserDialog: widget.dialog,
                      )
                    : SizedBox.shrink(),
              )
            : SizedBox.shrink(),
        !_settingsProvider.appBarTop
            ? ExpandablePanel(
                theme: ExpandableThemeData(
                  hasIcon: false,
                  tapBodyToCollapse: false,
                  tapHeaderToExpand: false,
                ),
                collapsed: SizedBox.shrink(),
                controller: _quickItemsController,
                header: SizedBox.shrink(),
                expanded: _quickItemsActive
                    ? QuickItemsWidget(
                        inAppWebViewController: webView,
                        appBarTop: _settingsProvider.appBarTop,
                        browserDialog: widget.dialog,
                        webviewType: 'inapp',
                      )
                    : SizedBox.shrink(),
              )
            : SizedBox.shrink(),
      ],
    );
  }

  void _highlightChat() {
    if (!_currentUrl.contains('torn.com')) return;

    var intColor = Color(_settingsProvider.highlightColor);
    var background =
        'rgba(${intColor.red}, ${intColor.green}, ${intColor.blue}, ${intColor.opacity})';
    var senderColor =
        'rgba(${intColor.red}, ${intColor.green}, ${intColor.blue}, 1)';
    String hlMap =
        '[ { name: "${_userProvider.basic.name}", highlight: "$background", sender: "$senderColor" } ]';

    if (_settingsProvider.highlightChat) {
      webView.evaluateJavascript(
        source: (chatHighlightJS(highlightMap: hlMap)),
      );
    }
  }

  void _hideChat() {
    if (_chatRemovalEnabled && _chatRemovalActive) {
      webView.evaluateJavascript(source: removeChatOnLoadStartJS());
    }
  }

  CustomAppBar buildCustomAppBar() {
    return CustomAppBar(
      onHorizontalDragEnd: (DragEndDetails details) async {
        await _goBackOrForward(details);
      },
      genericAppBar: AppBar(
        elevation: _settingsProvider.appBarTop ? 2 : 0,
        brightness: Brightness.dark,
        leading: IconButton(
            icon: _backButtonPopsContext
                ? Icon(Icons.close)
                : Icon(Icons.arrow_back_ios),
            onPressed: () async {
              // Normal behaviour is just to pop and go to previous page
              if (_backButtonPopsContext) {
                if (widget.customCallBack != null) {
                  widget.customCallBack();
                }
                Navigator.pop(context);
              } else {
                // But we can change and go back to previous page in certain
                // situations (e.g. when going for the vault while trading),
                // in which case we need to return to previous target
                var backPossible = await webView.canGoBack();
                if (backPossible) {
                  webView.goBack();
                } else {
                  Navigator.pop(context);
                }
                _backButtonPopsContext = true;
              }
            }),
        title: GestureDetector(
          onTap: () {
            _openCustomUrlDialog();
          },
          child: DottedBorder(
            borderType: BorderType.Rect,
            padding: EdgeInsets.all(6),
            dashPattern: [1, 4],
            color: Colors.white70,
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              child: Row(
                key: _showOne,
                children: [
                  Flexible(
                      child: Text(
                    _pageTitle,
                    overflow: TextOverflow.fade,
                  )),
                ],
              ),
            ),
          ),
        ),
        actions: <Widget>[
          _travelHomeIcon(),
          _crimesInfoIcon(),
          _crimesMenuIcon(),
          _quickItemsMenuIcon(),
          _vaultsPopUpIcon(),
          _tradesMenuIcon(),
          _cityMenuIcon(),
          _bazaarFillIcon(),
          _chatRemovalEnabled ? _hideChatIcon() : SizedBox.shrink(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: new CircleBorder(),
                splashColor: Colors.orange,
                child: Icon(Icons.refresh),
                onTap: () async {
                  _scrollX = await webView.getScrollX();
                  _scrollY = await webView.getScrollY();
                  await webView.reload();
                  _scrollAfterLoad = true;

                  BotToast.showText(
                    text: "Reloading...",
                    textStyle: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    contentColor: Colors.grey[600],
                    duration: Duration(seconds: 1),
                    contentPadding: EdgeInsets.all(10),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future _goBackOrForward(DragEndDetails details) async {
    if (details.primaryVelocity < 0) {
      await _tryGoForward();
    } else if (details.primaryVelocity > 0) {
      await _tryGoBack();
    }
  }

  Future _tryGoBack() async {
    var canBack = await webView.canGoBack();
    if (canBack) {
      await webView.goBack();
      BotToast.showText(
        text: "Back",
        textStyle: TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
        contentColor: Colors.grey[600],
        duration: Duration(seconds: 1),
        contentPadding: EdgeInsets.all(10),
      );
    } else {
      BotToast.showText(
        text: "Can\'t go back!",
        textStyle: TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
        contentColor: Colors.grey[600],
        duration: Duration(seconds: 1),
        contentPadding: EdgeInsets.all(10),
      );
    }
  }

  Future _tryGoForward() async {
    var canForward = await webView.canGoForward();
    if (canForward) {
      await webView.goForward();
      BotToast.showText(
        text: "Forward",
        textStyle: TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
        contentColor: Colors.grey[600],
        duration: Duration(seconds: 1),
        contentPadding: EdgeInsets.all(10),
      );
    } else {
      BotToast.showText(
        text: "Can\'t go forward!",
        textStyle: TextStyle(
          fontSize: 14,
          color: Colors.white,
        ),
        contentColor: Colors.grey[600],
        duration: Duration(seconds: 1),
        contentPadding: EdgeInsets.all(10),
      );
    }
  }

  /// Note: several other modules are called in onProgressChanged, since it's
  /// faster. The ones here probably would not benefit from it.
  Future _assessGeneral(dom.Document document) async {
    _assessBackButtonBehaviour();
    _assessTravel(document);
    _assessBazaar(document);
  }

  Future _assessSectionsWithWidgets() async {
    bool anySectionTriggered = false;
    bool getItems = false;
    bool getCrimes = false;
    bool getCity = false;
    bool getTrades = false;
    bool getProfile = false;
    bool getAttack = false;

    if ((_currentUrl.contains('item.php') && !_quickItemsTriggered) ||
        (!_currentUrl.contains('item.php') && _quickItemsTriggered)) {
      anySectionTriggered = true;
      getItems = true;
    }

    if ((_currentUrl.contains('crimes.php') && !_crimesTriggered) ||
        (!_currentUrl.contains('crimes.php') && _crimesTriggered)) {
      anySectionTriggered = true;
      getCrimes = true;
    }

    if ((_currentUrl.contains('city.php') && !_cityTriggered) ||
        (!_currentUrl.contains('city.php') && _cityTriggered)) {
      anySectionTriggered = true;
      getCity = true;
    }

    if (!_currentUrl.contains("trade.php") && _tradesTriggered) {
      // This is different to the others, here we call only so that trades is deactivated
      anySectionTriggered = true;
      getTrades = true;
    }

    if ((!_currentUrl.contains('torn.com/profiles.php?XID=') &&
            _profileTriggered) ||
        (_currentUrl.contains('torn.com/profiles.php?XID=') &&
            !_profileTriggered)) {
      anySectionTriggered = true;
      getProfile = true;
    }

    if ((!_currentUrl.contains('loader.php?sid=attack&user2ID=') &&
            _attackTriggered) ||
        (_currentUrl.contains('loader.php?sid=attack&user2ID=') &&
            !_attackTriggered)) {
      anySectionTriggered = true;
      getAttack = true;
    }

    if (anySectionTriggered) {
      dom.Document doc;
      var pageTitle = "";
      var html = await webView.getHtml();
      doc = parse(html);
      pageTitle = (await _getPageTitle(doc)).toLowerCase();

      if (getItems) _assessQuickItems(pageTitle);
      if (getCrimes) _assessCrimes(pageTitle);
      if (getCity) _assessCity(doc, pageTitle);
      if (getTrades) _decideIfCallTrades(doc: doc, pageTitle: pageTitle);
      if (getProfile) _assessProfileAttack();
      if (getAttack) _assessProfileAttack();
    }
  }

  void _resetSectionsWithWidgets() {
    if (_currentUrl.contains('item.php') && _quickItemsTriggered) {
      _crimesTriggered = false;
      _cityTriggered = false;
      _tradesTriggered = false;
      _profileTriggered = false;
      _attackTriggered = false;
    } else if (_currentUrl.contains('crimes.php') && _crimesTriggered) {
      _quickItemsTriggered = false;
      _cityTriggered = false;
      _tradesTriggered = false;
      _profileTriggered = false;
      _attackTriggered = false;
    } else if (_currentUrl.contains('city.php') && _cityTriggered) {
      _crimesTriggered = false;
      _quickItemsTriggered = false;
      _tradesTriggered = false;
      _profileTriggered = false;
      _attackTriggered = false;
    } else if (_currentUrl.contains("trade.php") && _tradesTriggered) {
      _crimesTriggered = false;
      _quickItemsTriggered = false;
      _cityTriggered = false;
      _profileTriggered = false;
      _attackTriggered = false;
    } else if (_currentUrl.contains("torn.com/profiles.php?XID=") &&
        _profileTriggered) {
      _crimesTriggered = false;
      _quickItemsTriggered = false;
      _tradesTriggered = false;
      _cityTriggered = false;
      _attackTriggered = false;
    } else if (_currentUrl.contains("loader.php?sid=attack&user2ID=") &&
        _attackTriggered) {
      _crimesTriggered = false;
      _quickItemsTriggered = false;
      _tradesTriggered = false;
      _cityTriggered = false;
      _profileTriggered = false;
    } else {
      _crimesTriggered = false;
      _quickItemsTriggered = false;
      _cityTriggered = false;
      _tradesTriggered = false;
      _profileTriggered = false;
      _attackTriggered = false;
    }
  }

  void _assessBackButtonBehaviour() async {
    // If we are NOT moving to a place with a vault, we show an X and close upon button press
    if (!_currentUrl.contains('properties.php#/p=options&tab=vault') &&
        !_currentUrl.contains(
            'factions.php?step=your#/tab=armoury&start=0&sub=donate') &&
        !_currentUrl.contains('companies.php#/option=funds')) {
      _backButtonPopsContext = true;
    }
    // However, if we are in a place with a vault AND we come from Trades, we'll change
    // the back button behaviour to ensure we are returning to Trades
    else {
      var history = await webView.getCopyBackForwardList();
      // Check if we have more than a single page in history (otherwise we don't come from Trades)
      if (history.currentIndex > 0) {
        if (history.list[history.currentIndex - 1].url.path
            .contains('trade.php')) {
          _backButtonPopsContext = false;
        }
      }
    }
  }

  /// This will try first with H4 (works for most Torn sections) and revert
  /// to the URL if it doesn't find anything
  /// [showTitle] show ideally only be set to true in onLoadStop, or full
  /// URLs might show up while loading the page in onProgressChange
  Future<String> _getPageTitle(
    dom.Document document, {
    bool showTitle = false,
  }) async {
    String title = '';
    var h4 = document.querySelector(".content-title > h4");
    if (h4 != null) {
      title = h4.innerHtml.substring(0).trim();
    }

    if (h4 == null && showTitle) {
      title = await webView.getTitle();
      if (title.contains(' |')) {
        title = title.split(' |')[0];
      }
    }

    // If title is missing, we only show the domain
    if (title.contains('https://www.')) {
      title = title.replaceAll('https://www.', '');
    } else if (title.contains('https://')) {
      title = title.replaceAll('https://', '');
    }

    if (title != null) {
      if (title.toLowerCase().contains('error') ||
          title.toLowerCase().contains('please validate')) {
        if (mounted) {
          setState(() {
            _pageTitle = 'Torn';
          });
        }
      } else {
        if (mounted && showTitle) {
          setState(() {
            _pageTitle = title;
          });
        }
      }
    }
    return title;
  }

  // TRAVEL
  Future _assessTravel(dom.Document document) async {
/*    var traveling = document.querySelector(".travel-agency-travelling .stage");
    if (traveling != null) {
      await webView.evaluateJavascript(source: travelRemovePlaneJS());
    }*/

    var abroad = document.querySelectorAll(".travel-home");
    if (abroad.length > 0) {
      _insertTravelFillMaxButtons();
      _sendStockInformation(document);
      if (mounted) {
        setState(() {
          _travelAbroad = true;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _travelAbroad = false;
        });
      }
    }
  }

  Future _insertTravelFillMaxButtons() async {
    await webView.evaluateJavascript(source: buyMaxJS());
  }

  void _sendStockInformation(dom.Document document) async {
    var elements = document.querySelectorAll('.item-info-wrap');

    if (elements.length > 0) {
      try {
        // Parse stocks
        var stockModel = ForeignStockOutModel();
        stockModel.authorName = _userProvider.basic.name;
        stockModel.authorId = _userProvider.basic.playerId;

        stockModel.country = document
            .querySelector(".content-title > h4")
            .innerHtml
            .substring(0, 4)
            .toLowerCase()
            .trim();

        RegExp expId = new RegExp(r"[0-9]+");
        for (var el in elements) {
          var stockItem = ForeignStockOutItem();
          stockItem.id =
              int.parse(expId.firstMatch(el.querySelector('[id^=item]').id)[0]);
          stockItem.quantity = int.parse(el
              .querySelector(".stck-amount")
              .innerHtml
              .replaceAll(RegExp(r"[^0-9]"), ""));
          stockItem.cost = int.parse(el
              .querySelector(".c-price")
              .innerHtml
              .replaceAll(RegExp(r"[^0-9]"), ""));
          stockModel.items.add(stockItem);
        }

        // Send to server
        await http.post(
          'https://yata.yt/api/v1/travel/import/',
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
          },
          body: foreignStockOutModelToJson(stockModel),
        );
      } catch (e) {
        // Error parsing
      }
    }
  }

  Widget _travelHomeIcon() {
    if (_travelAbroad) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: new CircleBorder(),
          splashColor: Colors.blueGrey,
          child: Icon(
            Icons.home,
          ),
          onTap: () async {
            await webView.evaluateJavascript(source: travelReturnHomeJS());
          },
        ),
      );
    } else {
      return SizedBox.shrink();
    }
  }

  // CRIMES
  Future _assessCrimes(String pageTitle) async {
    if (mounted) {
      //var pageTitle = (await _getPageTitle(document)).toLowerCase();
      if (!pageTitle.contains('crimes')) {
        setState(() {
          _crimesController.expanded = false;
          _crimesActive = false;
        });
        return;
      }

      // Stops any successive calls once we are sure that the section is the
      // correct one. onLoadStop will reset this for the future.
      //
      if (_crimesTriggered) {
        return;
      }
      _crimesTriggered = true;

      setState(() {
        _crimesController.expanded = true;
        _crimesActive = true;
      });
    }
  }

  Widget _crimesInfoIcon() {
    if (_crimesActive) {
      return IconButton(
        icon: Icon(Icons.info_outline),
        onPressed: () {
          BotToast.showText(
            text: 'If you need more information about a crime, maintain the '
                'quick crime button pressed for a few seconds and a tooltip '
                'will be shown!',
            textStyle: TextStyle(
              fontSize: 14,
              color: Colors.white,
            ),
            contentColor: Colors.grey[700],
            duration: Duration(seconds: 8),
            contentPadding: EdgeInsets.all(10),
          );
        },
      );
    } else {
      return SizedBox.shrink();
    }
  }

  Widget _crimesMenuIcon() {
    if (_crimesActive) {
      return OpenContainer(
        transitionDuration: Duration(milliseconds: 500),
        transitionType: ContainerTransitionType.fadeThrough,
        openBuilder: (BuildContext context, VoidCallback _) {
          return CrimesOptions();
        },
        closedElevation: 0,
        closedShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(56 / 2),
          ),
        ),
        closedColor: Colors.transparent,
        closedBuilder: (BuildContext context, VoidCallback openContainer) {
          return Padding(
            padding: const EdgeInsets.only(right: 5),
            child: SizedBox(
              height: 20,
              width: 20,
              child: Icon(MdiIcons.fingerprint, color: Colors.white),
            ),
          );
        },
      );
    } else {
      return SizedBox.shrink();
    }
  }

  // TRADES
  Future _assessTrades(dom.Document document, String pageTitle) async {
    // Check that we are in Trades, but also inside an existing trade
    // (step=view) or just created one (step=initiateTrade)
    //var pageTitle = (await _getPageTitle(document)).toLowerCase();
    var easyUrl =
        _currentUrl.replaceAll('#', '').replaceAll('/', '').split('&');
    if (pageTitle.contains('trade') && _currentUrl.contains('trade.php')) {
      // Activate trades icon even before starting a trade, so that it can be deactivated
      if (mounted) {
        setState(() {
          _tradesIconActive = true;
        });
      }
      _lastTradeCallWasIn = true;
      if (!easyUrl[0].contains('step=initiateTrade') &&
          !easyUrl[0].contains('step=view')) {
        if (_tradesFullActive) {
          _toggleTradesWidget(active: false);
        }
        return;
      }
    } else {
      if (_tradesFullActive) {
        _toggleTradesWidget(active: false);
      }
      if (mounted) {
        setState(() {
          _tradesIconActive = false;
        });
      }
      _lastTradeCallWasIn = false;
      return;
    }

    // We only get this once and if we are inside a trade
    // It's also in the callback from trades options
    if (!_tradesPreferencesLoaded) {
      _tradeCalculatorEnabled =
          await SharedPreferencesModel().getTradeCalculatorEnabled();
      _tradesPreferencesLoaded = true;
    }
    if (!_tradeCalculatorEnabled) {
      if (_tradesFullActive) {
        _toggleTradesWidget(active: false);
      }
      return;
    }

    String sellerName;
    int tradeId;
    // Element containers
    List<dom.Element> leftMoneyElements;
    List<dom.Element> leftItemsElements;
    List<dom.Element> leftPropertyElements;
    List<dom.Element> leftSharesElements;
    List<dom.Element> rightMoneyElements;
    List<dom.Element> rightItemsElements;
    List<dom.Element> rightPropertyElements;
    List<dom.Element> rightSharesElements;

    // Because only the frame reloads, if we can't find anything
    // we'll wait 1 second, get the html again and query again
    var totalFinds = document.querySelectorAll(
        ".color1 .left , .color2 .left , .color1 .right , .color2 .right");

    try {
      if (totalFinds.length == 0) {
        await Future.delayed(const Duration(seconds: 1));
        var updatedHtml = await webView.getHtml();
        var updatedDoc = parse(updatedHtml);
        leftMoneyElements =
            updatedDoc.querySelectorAll("#trade-container .left .color1 .name");
        leftItemsElements =
            updatedDoc.querySelectorAll("#trade-container .left .color2 .name");
        leftPropertyElements =
            updatedDoc.querySelectorAll("#trade-container .left .color3 .name");
        leftSharesElements =
            updatedDoc.querySelectorAll("#trade-container .left .color4 .name");
        rightMoneyElements = updatedDoc
            .querySelectorAll("#trade-container .right .color1 .name");
        rightItemsElements = updatedDoc
            .querySelectorAll("#trade-container .right .color2 .name");
        rightPropertyElements = updatedDoc
            .querySelectorAll("#trade-container .right .color3 .name");
        rightSharesElements = updatedDoc
            .querySelectorAll("#trade-container .right .color4 .name");
      } else {
        leftMoneyElements =
            document.querySelectorAll("#trade-container .left .color1 .name");
        leftItemsElements =
            document.querySelectorAll("#trade-container .left .color2 .name");
        leftPropertyElements =
            document.querySelectorAll("#trade-container .left .color3 .name");
        leftSharesElements =
            document.querySelectorAll("#trade-container .left .color4 .name");
        rightMoneyElements =
            document.querySelectorAll("#trade-container .right .color1 .name");
        rightItemsElements =
            document.querySelectorAll("#trade-container .right .color2 .name");
        rightPropertyElements =
            document.querySelectorAll("#trade-container .right .color3 .name");
        rightSharesElements =
            document.querySelectorAll("#trade-container .right .color4 .name");
      }
    } catch (e) {
      return;
    }

    // Trade Id
    try {
      RegExp regId = new RegExp(r"(?:&ID=)([0-9]+)");
      var matches = regId.allMatches(_currentUrl);
      tradeId = int.parse(matches.elementAt(0).group(1));
    } catch (e) {
      tradeId = 0;
    }

    // Name of seller
    try {
      sellerName = document.querySelector(".right .title-black").innerHtml;
    } catch (e) {
      sellerName = "";
    }

    // Activate trades widget
    _toggleTradesWidget(active: true);

    // Initialize trades provider, which in turn feeds the trades widget
    var tradesProvider = Provider.of<TradesProvider>(context, listen: false);
    tradesProvider.updateTrades(
      userApiKey: _userProvider.basic.userApiKey,
      playerId: _userProvider.basic.playerId,
      sellerName: sellerName,
      tradeId: tradeId,
      leftMoneyElements: leftMoneyElements,
      leftItemsElements: leftItemsElements,
      leftPropertyElements: leftPropertyElements,
      leftSharesElements: leftSharesElements,
      rightMoneyElements: rightMoneyElements,
      rightItemsElements: rightItemsElements,
      rightPropertyElements: rightPropertyElements,
      rightSharesElements: rightSharesElements,
    );
  }

  _toggleTradesWidget({@required bool active}) {
    if (active) {
      if (mounted) {
        setState(() {
          _tradesFullActive = true;
          _tradesExpandable = TradesWidget();
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _tradesFullActive = false;
          _tradesExpandable = SizedBox.shrink();
        });
      }
    }
  }

  Widget _vaultsPopUpIcon() {
    if (_tradesIconActive) {
      return PopupMenuButton<VaultsOptions>(
        icon: Icon(MdiIcons.cashUsdOutline),
        onSelected: _openVaultsOptions,
        itemBuilder: (BuildContext context) {
          return _popupOptionsChoices.map((VaultsOptions choice) {
            return PopupMenuItem<VaultsOptions>(
              value: choice,
              child: Row(
                children: [
                  Text(choice.description),
                ],
              ),
            );
          }).toList();
        },
      );
    } else {
      return SizedBox.shrink();
    }
  }

  void _openVaultsOptions(VaultsOptions choice) async {
    switch (choice.description) {
      case "Personal vault":
        webView.loadUrl(
          urlRequest: URLRequest(
            url: Uri.parse(
                "https://www.torn.com/properties.php#/p=options&tab=vault"),
          ),
        );
        break;
      case "Faction vault":
        webView.loadUrl(
          urlRequest: URLRequest(
            url: Uri.parse(
                "https://www.torn.com/factions.php?step=your#/tab=armoury&start=0&sub=donate"),
          ),
        );
        break;
      case "Company vault":
        webView.loadUrl(
          urlRequest: URLRequest(
            url: Uri.parse("https://www.torn.com/companies.php#/option=funds"),
          ),
        );
        break;
    }
  }

  Widget _tradesMenuIcon() {
    if (_tradesIconActive) {
      return OpenContainer(
        transitionDuration: Duration(milliseconds: 500),
        transitionType: ContainerTransitionType.fadeThrough,
        openBuilder: (BuildContext context, VoidCallback _) {
          return TradesOptions(
            playerId: _userProvider.basic.playerId,
            callback: _tradesPreferencesLoad,
          );
        },
        closedElevation: 0,
        closedShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(56 / 2),
          ),
        ),
        closedColor: Colors.transparent,
        closedBuilder: (BuildContext context, VoidCallback openContainer) {
          return Padding(
            padding: const EdgeInsets.only(right: 5),
            child: SizedBox(
              height: 20,
              width: 20,
              child: Icon(MdiIcons.accountSwitchOutline),
            ),
          );
        },
      );
    } else {
      return SizedBox.shrink();
    }
  }

  Future _tradesPreferencesLoad() async {
    _tradeCalculatorEnabled =
        await SharedPreferencesModel().getTradeCalculatorEnabled();
    _decideIfCallTrades();
  }

  // Avoid continuous calls to trades from different activators
  Future _decideIfCallTrades({dom.Document doc, String pageTitle = ""}) async {
    var now = DateTime.now();
    var diff = now.difference(_lastTradeCall);
    if (diff.inSeconds > 1 || !_lastTradeCallWasIn) {
      _lastTradeCall = now;

      // Call trades. If we come from onProgressChanged we already have document
      // and title (quicker). Otherwise, we need to get them (if we come from trade options)
      if (mounted) {
        if (doc != null && pageTitle.isNotEmpty) {
          _assessTrades(doc, pageTitle);
        } else {
          _currentUrl = (await webView.getUrl()).path;
          var html = await webView.getHtml();
          var d = parse(html);
          var t = (await _getPageTitle(d)).toLowerCase();
          _assessTrades(d, t);
        }
      }
    }
  }

  // CITY
  Future _assessCity(dom.Document document, String pageTitle) async {
    //var pageTitle = (await _getPageTitle(document)).toLowerCase();
    if (!pageTitle.contains('city')) {
      setState(() {
        _cityIconActive = false;
        _cityExpandable = SizedBox.shrink();
      });
      return;
    }

    if (mounted) {
      setState(() {
        _cityIconActive = true;
      });
    }

    // Stops any successive calls once we are sure that the section is the
    // correct one. onLoadStop will reset this for the future.
    // Otherwise we would call the API every time onProgressChanged ticks
    if (_cityTriggered) {
      return;
    }
    _cityTriggered = true;

    // We only get this once and if we are inside the city
    // It's also in the callback from city options
    if (!_cityPreferencesLoaded) {
      await _cityPreferencesLoad();
      _cityPreferencesLoaded = true;
    }

    // Retry several times and allow the map to load. If the user lands in the city list, this will
    // also trigger and the user will have 60 seconds to load the map (after that, only reloading
    // or browsing out/in of city will force a reload)
    List<dom.Element> query;
    for (var i = 0; i < 60; i++) {
      if (!mounted) break;

      query = document.querySelectorAll("#map .leaflet-marker-pane *");
      if (query.length > 0) {
        print('City tries: $i in $i seconds (max 60 sec)');
        break;
      } else {
        await Future.delayed(const Duration(seconds: 1));
        var updatedHtml = await webView.getHtml();
        document = parse(updatedHtml);
      }
    }
    if (query.length == 0) {
      // Set false so that the page can be reloaded if city widget didn't load
      _cityTriggered = false;
      return;
    }

    // Assess if we need to show the widget, now that we are in the city
    // By placing this check here, we also avoid showing the widget if we entered via Quick Links
    // in the city
    if (mounted) {
      setState(() {
        if (!_cityEnabled) {
          _cityExpandable = SizedBox.shrink();
          return;
        }
      });
    }

    var mapItemsList = <String>[];
    for (var mapFind in query) {
      mapFind.attributes.forEach((key, value) {
        if (key == "src" &&
            value.contains("https://www.torn.com/images/items/")) {
          mapItemsList.add(value.split("items/")[1].split("/")[0]);
        }
      });
    }

    // Pass items to widget (if nothing found, widget's list will be empty)
    try {
      dynamic apiResponse =
          await TornApiCaller.items(_userProvider.basic.userApiKey).getItems;
      if (apiResponse is ItemsModel) {
        var tornItems = apiResponse.items.values.toList();
        var itemsFound = <Item>[];
        for (var mapItem in mapItemsList) {
          Item itemMatch = tornItems[int.parse(mapItem) - 1];
          itemsFound.add(itemMatch);
        }
        if (mounted) {
          setState(() {
            _cityItemsFound = itemsFound;
            _errorCityApi = false;
            _cityExpandable = CityWidget(
              controller: webView,
              cityItems: _cityItemsFound,
              error: _errorCityApi,
            );
          });
        }
        webView.evaluateJavascript(source: highlightCityItemsJS());
      } else {
        if (mounted) {
          setState(() {
            _errorCityApi = true;
          });
        }
      }
    } catch (e) {
      return;
    }
  }

  Widget _cityMenuIcon() {
    if (_cityIconActive) {
      return OpenContainer(
        transitionDuration: Duration(milliseconds: 500),
        transitionType: ContainerTransitionType.fadeThrough,
        openBuilder: (BuildContext context, VoidCallback _) {
          return CityOptions(
            callback: _cityPreferencesLoad,
          );
        },
        closedElevation: 0,
        closedShape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(56 / 2),
          ),
        ),
        closedColor: Colors.transparent,
        closedBuilder: (BuildContext context, VoidCallback openContainer) {
          return Padding(
            padding: const EdgeInsets.only(right: 5),
            child: SizedBox(
              height: 20,
              width: 20,
              child: Icon(MdiIcons.cityVariantOutline),
            ),
          );
        },
      );
    } else {
      return SizedBox.shrink();
    }
  }

  Future _cityPreferencesLoad() async {
    _cityEnabled = await SharedPreferencesModel().getCityEnabled();
    // Reset city so that it can be assessed again
    _cityTriggered = false;
    await webView.reload();
  }

  // BAZAAR
  Future _assessBazaar(dom.Document document) async {
    var easyUrl = _currentUrl.replaceAll('#', '');
    if (easyUrl.contains('bazaar.php/add')) {
      _bazaarActive = true;
    } else {
      _bazaarActive = false;
    }
  }

  Widget _bazaarFillIcon() {
    if (_bazaarActive) {
      return TextButton(
        onPressed: () async {
          _bazaarFillActive
              ? await webView.evaluateJavascript(
                  source: removeBazaarFillButtonsJS())
              : await webView.evaluateJavascript(
                  source: addBazaarFillButtonsJS());

          if (mounted) {
            setState(() {
              _bazaarFillActive
                  ? _bazaarFillActive = false
                  : _bazaarFillActive = true;
            });
          }
        },
        child: Text(
          "FILL",
          style: TextStyle(
            color: _bazaarFillActive ? Colors.yellow[600] : Colors.white,
          ),
        ),
      );
    } else {
      return SizedBox.shrink();
    }
  }

  // QUICK ITEMS
  Future _assessQuickItems(String pageTitle) async {
    if (mounted) {
      //var pageTitle = (await _getPageTitle(document)).toLowerCase();
      if (!pageTitle.contains('items')) {
        setState(() {
          _quickItemsController.expanded = false;
          _quickItemsActive = false;
        });
        return;
      }

      // Stops any successive calls once we are sure that the section is the
      // correct one. onLoadStop will reset this for the future.
      // Otherwise we would call the API every time onProgressChanged ticks
      if (_quickItemsTriggered) {
        return;
      }
      _quickItemsTriggered = true;

      var quickItemsProvider = context.read<QuickItemsProvider>();
      var key = _userProvider.basic.userApiKey;
      quickItemsProvider.loadItems(apiKey: key);

      setState(() {
        _quickItemsController.expanded = true;
        _quickItemsActive = true;
      });
    }
  }

  Widget _quickItemsMenuIcon() {
    if (_quickItemsActive) {
      return Padding(
        padding: const EdgeInsets.only(right: 5),
        child: OpenContainer(
          transitionDuration: Duration(milliseconds: 500),
          transitionType: ContainerTransitionType.fadeThrough,
          openBuilder: (BuildContext context, VoidCallback _) {
            return QuickItemsOptions();
          },
          closedElevation: 0,
          closedShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(56 / 2),
            ),
          ),
          closedColor: Colors.transparent,
          closedBuilder: (BuildContext context, VoidCallback openContainer) {
            return SizedBox(
              height: 20,
              width: 20,
              child: Image.asset('images/icons/quick_items.png',
                  color: Colors.white),
            );
          },
        ),
      );
    } else {
      return SizedBox.shrink();
    }
  }

  // ASSESS PROFILES
  Future _assessProfileAttack() async {
    if (mounted) {
      if (!_currentUrl.contains('loader.php?sid=attack&user2ID=') &&
          !_currentUrl.contains('torn.com/profiles.php?XID=')) {
        _profileTriggered = false;
        _profileAttackExpandable = SizedBox.shrink();
        _profileAttackController.expanded = false;
        return;
      }

      int userId = 0;

      if (_currentUrl.contains('torn.com/profiles.php?XID=')) {
        if (_profileTriggered) {
          return;
        }
        _profileTriggered = true;

        try {
          RegExp regId = new RegExp(r"(?:php\?XID=)([0-9]+)");
          var matches = regId.allMatches(_currentUrl);
          userId = int.parse(matches.elementAt(0).group(1));
          setState(() {
            _profileAttackExpandable = ProfileAttackCheckWidget(
              profileId: userId,
            );
            _profileAttackController.expanded = true;
          });
        } catch (e) {
          userId = 0;
        }
      } else if (_currentUrl.contains('loader.php?sid=attack&user2ID=')) {
        if (_attackTriggered) {
          return;
        }
        _attackTriggered = true;

        try {
          RegExp regId = new RegExp(r"(?:&user2ID=)([0-9]+)");
          var matches = regId.allMatches(_currentUrl);
          userId = int.parse(matches.elementAt(0).group(1));
          setState(() {
            _profileAttackExpandable = ProfileAttackCheckWidget(
              profileId: userId,
            );
            _profileAttackController.expanded = true;
          });
        } catch (e) {
          userId = 0;
        }
      }
    }
  }

  // HIDE CHAT
  Widget _hideChatIcon() {
    if (!_chatRemovalActive) {
      return Padding(
        padding: const EdgeInsets.only(left: 15),
        child: GestureDetector(
          child: Icon(MdiIcons.chatOutline),
          onTap: () async {
            webView.evaluateJavascript(source: removeChatJS());
            SharedPreferencesModel().setChatRemovalActive(true);
            setState(() {
              _chatRemovalActive = true;
            });
          },
        ),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.only(left: 15),
        child: GestureDetector(
          child: Icon(
            MdiIcons.chatRemoveOutline,
            color: Colors.orange[500],
          ),
          onTap: () async {
            webView.evaluateJavascript(source: restoreChatJS());
            SharedPreferencesModel().setChatRemovalActive(false);
            setState(() {
              _chatRemovalActive = false;
            });
          },
        ),
      );
    }
  }

  Future _loadChatPreferences() async {
    var removalEnabled = await SharedPreferencesModel().getChatRemovalEnabled();
    var removalActive = await SharedPreferencesModel().getChatRemovalActive();
    setState(() {
      _chatRemovalEnabled = removalEnabled;
      _chatRemovalActive = removalActive;
    });
  }

  Future<void> _openCustomUrlDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return WebviewUrlDialog(
          title: _pageTitle,
          url: _currentUrl,
          webview: webView,
        );
      },
    );
  }

  // UTILS
  Future<bool> _willPopCallback() async {
    await _tryGoBack();
    return false;
  }
}

UserScript lala = UserScript(
  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
  source: r"""
// ==UserScript==
// @name         TornCAT Faction Player Filters
// @namespace    torncat
// @version      1.1.0

// @description  This script adds player filters on various pages (see matches below).
// @author       Wingmanjd[2127679]
// @match        https://www.torn.com/factions.php*
// @match        https://www.torn.com/hospitalview.php*
// @match        https://www.torn.com/jailview.php*
// @match        https://www.torn.com/index.php?page=people*
// @match        https://www.torn.com/*list.php*
// ==/UserScript==

'use strict';

let GM_addStyle = function(s)
{
    let style = document.createElement("style");
    style.type = "text/css";
    style.innerHTML = s;
    
    document.head.appendChild(style);
}

// Class declarations
/************************************** */
class PlayerIDQueue {
    constructor() {
        this.playerIDs = this.findPlayerIDs();
        this.queries = 0;
        this.start = new Date();
    }
    enqueue(el) {
        this.playerIDs.push(el);
    }
    dequeue() {
        return this.playerIDs.shift();
    }
    findPlayerIDs() {
        let users = $('.user.name');
        let players = users.toArray();
        let playerIDs = [];

        players.forEach(function(el){
            let regex = /(XID=)(\d*)/;
            let found = el.href.match(regex);
            let playerID = Number(found[0].slice(4));

            // Push to new array if not already present.
            if (playerIDs.indexOf(playerID) == -1){
                playerIDs.push(playerID);
            }
        });
        return playerIDs;
    }
    isEmpty() {
        return this.playerIDs.length == 0;
    }
    peek() {
        return !this.isEmpty() ? this.playerIDs[0] : undefined;
    }
    length() {
        return this.playerIDs.length;
    }
    requeue() {
        let element = this.peek();
        this.dequeue();
        this.enqueue(element);
    }
    clear() {
        if(develCheck) console.debug('API Cache Dump:', apiDataCache);
        this.playerIDs = [];
    }
}

// Global script variables:
/************************************** */

// Development flag.
let develCheck = false;
let localStorageLocation = 'torncat.factionFilters';

// Local cache for api data.
let apiDataCache = {};
var data = data || {};

// Player queue
let queue = new PlayerIDQueue();

// Torn API query limit, to prevent flood protection rejections.
let apiQueryLimit = 60;

// Calculated values of checkboxes;
var reviveCheck = false;
var attackCheck = false;
var offlineCheck = false;


// Main script.
/************************************** */
(function() {
    'use strict';

    console.log('Faction Player Filters (FPF) started');
    // Load localStorage;
    loadData();
    // Save data back to localStorage;
    save();


    // Automatically display widget for pages that load user lists via AJAX.
    $( document ).ajaxComplete(function( event, xhr, settings ) {
        if (hideAjaxUrl(settings.url) == false) {
            renderFilterBar();
            reapplyFilters();
        }
    });

    // Manually display the filter widget if current url matches an item in the manualList array.
    // Following pages don't load the user list via AJAX.
    let manualList = [
        'page=people',
        'step=profile',
        'blacklist.php',
        'friendlist.php'

    ];

    manualList.forEach(el =>{
        if (window.location.href.match(el)){
            renderFilterBar();
        }
    });

})();


/**
 * Load localStorage data.
 */
function loadData(){
    data = localStorage.getItem(localStorageLocation);
    console.log(localStorageLocation);

    if(data == null) {
        console.log("LOADED!");
        // Default settings
        data = {
            apiKey : '',
            apiQueryDelay : 250,
            hideFactionDescription: false,
            queries: 0,
            start: '0'
        };
    } else {
        console.log("NOT LOADED!");
        data = JSON.parse(data);
        if (data.apiQueryDelay == undefined){
            data.apiQueryDelay = 250;
        }
    }


    // Calculate values of checkboxes.

    // eslint-disable-next-line no-undef
    reviveCheck = $('#tc-filter-revive').prop('checked');
    // eslint-disable-next-line no-undef
    attackCheck = $('#tc-filter-attack').prop('checked');
    // eslint-disable-next-line no-undef
    offlineCheck = $('#tc-filter-offline').prop('checked');
    develCheck = $('#tc-devmode').prop('checked');

}

/**
 * Save localStorage data.
 */
function save(){
    console.log('FPF local data saved');
    try {
      localStorage.setItem('torncat.factionFilters', JSON.stringify(data));
      console.log(JSON.stringify(data));
    } catch (e) {
      console.log("ERRORRRRR");
      console.log(e);
    }
    
}

/**
 * Renders HTML filter elements above the user list.
 */
function renderFilterBar() {
    // Generate HTMl.
    let reviveCheck = '#tc-filter-revive';
    let attackCheck = '#tc-filter-attack';
    let offlineCheck = '#tc-filter-offline';
    let refreshCheck = '#tc-refresh';
    let widgetLocationsSelector = '';

    let widgetHTML = `
        <div class="torncat-player-filter-bar">
            <div class="info-msg-cont border-round m-top10">
                <div class="info-msg border-round">
                    <a class="torncat-icon" title="Open Settings"></a>
                    <div class="torncat-filters">
                        <div class="msg right-round" tabindex="0" role="alert">
                            <label class="torncat-filter">
                                <span class="torncat-label">Revive Mode</span>
                                <input class="torncat-checkbox" id="tc-filter-revive" type="checkbox">
                            </label>
                            <label class="torncat-filter">
                                <span class="torncat-label">Attack Mode</span>
                                <input class="torncat-checkbox" id="tc-filter-attack" type="checkbox">
                            </label>
                            <label class="torncat-filter">
                                <span class="torncat-label">Hide Offline</span>
                                <input class="torncat-checkbox" id="tc-filter-offline" type="checkbox">
                            </label>
                            <label class="torncat-filter">
                                <span class="torncat-label">Auto Refresh (API)</span>
                                <input class="torncat-checkbox" id="tc-refresh" type="checkbox">
                            </label>
                        </div>
                    </div>
                </div>
            </div>
            <hr class="page-head-delimiter m-top10 m-bottom10 ">
        </div>
    `;
    let filterBar = $('.torncat-player-filter-bar');

    // Only insert if there isn't already a filter bar on the page.

    if ($(filterBar).length != 1){

        if (window.location.href.match('factions.php')){
            widgetLocationsSelector = '#faction-info-members';
        } else {
            widgetLocationsSelector = '.users-list-title';
        }

        var widgetLocationsLength = $(widgetLocationsSelector).length;
        $(widgetHTML).insertBefore($(widgetLocationsSelector)[widgetLocationsLength - 1]);

        // Scroll mobile view.
        if ($(window).width() < 1000 && data.hideFactionDescription ) {
            setTimeout(() => {
                document.querySelector('.torncat-player-filter-bar').scrollIntoView({
                    behavior: 'smooth'
                });
            },2000);
        }

        /* Add event listeners. */
        $('.torncat-player-filter-bar a.torncat-icon').click(function () {
            $('.api-key-prompt').toggle();
        });

        // Disable filters on Hospital/ Jail pages.
        if (
            window.location.href.startsWith('https://www.torn.com/hospital') ||
            window.location.href.startsWith('https://www.torn.com/jail')
        ){
            $('#tc-filter-revive').prop('checked', true);
            $('#tc-filter-revive').parent().hide();
            $('#tc-filter-attack').parent().hide();
        }

        // Watch for event changes on the revive mode checkbox.
        $(reviveCheck).change(() => {
            toggleUserRow('revive');
            if ($(attackCheck).prop('checked')){
                $(attackCheck).prop('checked', false);
                toggleUserRow('attack');
            }
        });

        // Watch for event changes on the attack mode checkbox.
        $(attackCheck).change(() =>  {
            loadData();
            toggleUserRow('attack');
            if ($(reviveCheck).prop('checked')){
                $(reviveCheck).prop('checked', false);
                toggleUserRow('revive');
            }
        });

        // Watch for event changes on the Hide Offline mode checkbox.
        $(offlineCheck).change(() => {
            loadData();
            toggleUserRow('offline');
        });

        // Watch for event changes on the Auto-refresh checkbox.
        $('#tc-refresh').change(() => {
            if ($(refreshCheck).prop('checked')) {
                console.log('FPF: Starting auto-refresh');
                let queue = new PlayerIDQueue();
                processRefreshQueue(queue);
            } else {
                console.log('FPF: Stopped processing queue. Queue cleared');
                loadData();
                if(develCheck) console.debug(data);
                queue.clear();
            }


        });
    }

    if ($('.api-key-prompt').length != 1){
        renderSettings();
    }

}

/**
 * Renders API key and other filter settings.
 */
function renderSettings(forceCheck) {
    // Generate HTMl.
    let saveAPIKeyButton = '<button class="torn-btn" id="JApiKeyBtn">Save</button>';
    let hideFactionDescription = '<br/><input class="torncat-checkbox" id="tc-hideFactionDescription" type="checkbox"> <span class="torncat-label">Hide Faction Description</span><br /><br />';
    let devButton = '<input class="torncat-checkbox" id="tc-devmode" type="checkbox"> <span class="torncat-label">Devel Mode </span><br /><br />';
    let clearAPIKeyButton = '<button class="torn-btn" onclick="localStorage.removeItem(\'torncat.factionFilters\');location.reload();">Clear API Key</button><br /><br />';
    let input = '<input type="text" id="JApiKeyInput" style="';
    input += 'border-radius: 8px 0 0 8px;';
    input += 'margin: 4px 0px;';
    input += 'padding: 5px;';
    input += 'font-size: 16px;height: 20px';
    input += '" placeholder="  API Key"></input><br/><br/>';

    let delayOption = '<label for="tc-delay">Delay time between API calls (ms):</label>';
    delayOption += '<select name="tc-delay" id="tc-delay">';
    switch (data.apiQueryDelay){

    case '100':
        delayOption += '  <option value="100" selected="selected">Short (100)</option>';
        delayOption += '  <option value="250">Medium (250)</option>';
        delayOption += '  <option value="500">Long (500)</option>';
        break;
    case '250':
        delayOption += '  <option value="100">Short (100)</option>';
        delayOption += '  <option value="250" selected="selected">Medium (250)</option>';
        delayOption += '  <option value="500">Long (500)</option>';
        break;
    case '500':
        delayOption += '  <option value="100">Short (100)</option>';
        delayOption += '  <option value="250">Medium (250)</option>';
        delayOption += '  <option value="500" selected="selected">Long (500)</option>';
        break;
    default:
        // If for some reason, data.apiQueryDelay isn't set, this will set a sane value.
        data.apiQueryDelay = 500;
        save();
        delayOption += '  <option value="100">Short (100)</option>';
        delayOption += '  <option value="250">Medium (250)</option>';
        delayOption += '  <option value="500" selected="selected">Long (500)</option>';
    }
    delayOption += '</select><br/>';

    let block = '<div class="api-key-prompt profile-wrapper medals-wrapper m-top10">';
    block += '<div class="menu-header">TornCAT - Player Filters</div>';
    block += '<div class="profile-container"><div class="profile-container-description" style="padding: 10px">';
    block += '<p><strong>Click the black icon in the filter row above to toggle this pane.</strong></p><br />';
    block += '<p>Auto Refresh requires a <a href="https://www.torn.com/preferences.php#tab=api">Torn API</a> key.  It will never be transmitted anywhere outside of Torn</p>';
    block += input;
    block += delayOption;
    block += hideFactionDescription;
    block += devButton;
    block += saveAPIKeyButton + ' | ';
    block += clearAPIKeyButton;
    block += '</div></div></div>';
    setTimeout(()=>{
        if ($('.api-key-prompt').length != 1){
            $(block).insertAfter('.torncat-player-filter-bar');

            // Re-enter saved data.
            if (data.apiKey != ''){
                $('#JApiKeyInput').val(data.apiKey);
            }

            if (data.hideFactionDescription) {
                $('#tc-hideFactionDescription').prop('checked', true);
                $('.faction-description').hide();
            }

            // Add event listeners.

            $('#JApiKeyBtn').click(function(){
                data.apiKey = $('#JApiKeyInput').val();
                save();
                $('.api-key-prompt').toggle();
            });

            $('#tc-delay').change(()=>{
                data.apiQueryDelay = $('#tc-delay').val();
                save();
                if (develCheck) console.debug('Changed apiQueryDelay to ' + data.apiQueryDelay + 'ms');
            });


            $('#tc-devmode').change(() => {
                loadData();
                console.debug('FPF Devel mode set to ' + develCheck);
                console.debug('data:', data);
                console.debug('apiDataCache', apiDataCache);
                console.debug('queue', queue);
            });

            $('#tc-hideFactionDescription').change(()=>{
                data.hideFactionDescription = $('#tc-hideFactionDescription').attr('checked') ? true : false;
                save();
                if (data.hideFactionDescription){
                    $('.faction-description').hide();
                } else {
                    $('.faction-description').show();
                }
                document.querySelector('.torncat-player-filter-bar').scrollIntoView({
                    behavior: 'smooth'
                });
            });
        }

        if (forceCheck == true){
            $('.api-key-prompt').show();
        } else {
            $('.api-key-prompt').hide();
        }
    }, 500);

}

/**
 * Re-applies the selected filters if the page data is reloaded via AJAX.
 */
function reapplyFilters(){
    let checked = [
        'revive',
        'attack',
        'offline'
    ];
    checked.forEach((filter)=>{
        let filterName = '#tc-filter-' + filter;
        if ($(filterName).prop('checked')){
            toggleUserRow(filter);
        }
    });
    if ($('#tc-refresh').prop('checked')){
        $('#tc-refresh').prop('checked', false);
        queue.clear();
        console.log('FPF: Restarting auto-refresh');
        queue = new PlayerIDQueue();
        $('#tc-refresh').prop('checked', true);
        processRefreshQueue(queue);
    }
}


/**
 * Async loop for processing next item in player queue.
 *
 * @param {PlayerIDQueue} queue
 */
async function processRefreshQueue(queue) {
    let refreshCheck = '#tc-refresh';
    let limited = false;
    while (!queue.isEmpty()){
        if(develCheck) console.debug('Current API calls: ' + data.queries);
        loadData();
        let playerID = queue.peek();
        // Call cache, if API queries threshold not hit.
        let now = new Date();

        if  ( now.getMinutes() != data.start ){
            console.log('FPF: Reset API call limit.  Highwater mark: ' + data.queries + ' API calls.');
            data.queries = 0;
            data.start = now.getMinutes();
            queue.start = now;
            save();
        }

        if (data.queries > apiQueryLimit && limited == false){
            let delay = (60 - now.getSeconds());
            console.log('Hit local API query limit of (' + apiQueryLimit + '). Waiting ' + delay + 's');
            limited = true;
            // Disable queue.
            queue.clear();
            $('#tc-refresh').attr('disabled', true);
            setInterval(()=>{
                // Reinitiate queue.
                $('#tc-refresh').prop('checked', false);
                $('#tc-refresh').attr('disabled', false);
                queue.clear();
                console.log('FPF: Restarting auto-refresh');
                queue = new PlayerIDQueue();
                $('#tc-refresh').prop('checked', true);
                processRefreshQueue(queue);
            }, delay * 1000);

            continue;
        } else if (!limited){
            limited = false;
            try{
                let playerData = await callCache(playerID);
                // Find player row in userlist.
                let selector = $('a.user.name[href$="' + playerID + '"]').parent().closest('li');

                updatePlayerContent(selector, playerData);
                // Update player row data.
                if(!queue.isEmpty() && ($('#tc-refresh').prop('checked') == true)) {
                    queue.requeue();
                } else {
                    queue.clear();
                }
            }
            catch(err){
                queue.clear();
                $(refreshCheck).prop('checked', false);
                renderSettings(true);
                console.error(err);
            }
        }
    }
}

/**
 * Returns cached player data, calling Torn API if cache hit is missed.
 *
 * @param {string} playerID
 */
async function callCache(playerID, recurse = false){
    let factionData = {};
    let playerData = {};
    let faction_id = 0;

    if (!(playerID in apiDataCache) || recurse == true){
        if (develCheck) console.debug('Missed cache for ' + playerID);
        // Call faction API endpoint async, if applicable.
        if (window.location.href.startsWith('https://www.torn.com/factions.php')){
            let searchParams = new URLSearchParams(window.location.search);
            if (searchParams.has('ID')){
                faction_id = (searchParams.get('ID'));
            }
            factionData = await callTornAPI('faction', faction_id, 'basic,timestamp');
            saveCacheData(factionData);
        }

        // Call user API endpoint async
        playerData = await callTornAPI('user', playerID, 'basic,profile,timestamp');
    } else {
        if (develCheck) console.debug('Cache hit for ' + apiDataCache[playerID].name + ' (' + playerID + ')');
        let now = new Date();
        playerData = apiDataCache[playerID];

        // Check timestamp for old data.
        let delta = (Math.round(now / 1000) - playerData.timestamp);
        if (delta > 30){
            if (develCheck) console.debug('Cache expired for ' + apiDataCache[playerID].name + ' (' + playerID + ')');
            playerData = await callCache(playerID, true);
        }
    }

    saveCacheData(playerData);

    return new Promise((resolve) => {
        setTimeout(()=>{
            resolve(playerData);
        }, data.apiQueryDelay);
    });
}

/**
 * Calls Torn API Endpoints.
 *
 * @param {string} type
 * @param {string} id
 * @param {string} selections
 */
function callTornAPI(type, id = '', selections=''){
    loadData();
    return new Promise((resolve, reject ) => {
        setTimeout(async () => {
            let baseURL = 'https://api.torn.com/';
            let streamURL = baseURL + type + '/' + id + '?selections=' + selections + '&key=' + data.apiKey;
            if (develCheck) console.debug('Making an API call to ' + streamURL);

            // Reject if key isn't set.
            if (data.apiKey == undefined || data.apiKey == '') {
                let error = {
                    code: 1,
                    error: 'Key is empty'
                };
                reject(error);
            }

            $.getJSON(streamURL)
                .done((result) => {
                    if (result.error != undefined){
                        reject(result.error);
                    } else {
                        data.queries++;
                        save();
                        resolve(result);
                    }
                })
                .fail(function( jqxhr, textStatus, error ) {
                    var err = textStatus + ', ' + error;
                    reject(err);
                });

        }, data.apiQueryDelay);
    });
}

/**
 * Saves Torn API data to local cache.
 *
 * @param {Object} data
 */
function saveCacheData(response){
    let playerData = {};
    if ('members' in response){
        // Process faction members' data.
        let keys = Object.keys(response.members);
        keys.forEach(playerID =>{
            playerData = response.members[playerID];
            playerData.timestamp = response.timestamp;
            apiDataCache[playerID] = playerData;
        });
    } else {
        // Process single player data.
        apiDataCache[response.player_id] = response;
    }
}

/**
 * Only returns if the AJAX URL is on the known list.
 * @param {string} url
 */
function hideAjaxUrl(url) {
    // Known AJAX URL's to ignore.
    let hideURLList = [
        'api.torn.com',
        'autocompleteHeaderAjaxAction.php',
        'competition.php',
        'missionChecker.php',
        'onlinestatus.php',
        'revive.php',
        'sidebarAjaxAction.php',
        'tornMobileApp.php',
        'torn-proxy.com',
        'websocket.php'
    ];

    // Known valid AJAX URl's, saved here for my own notes.
    // eslint-disable-next-line no-unused-vars
    let validURLList = [
        'userlist.php',
        'factions.php'
    ];

    for (let el of hideURLList) {
        if (url.match(el)) {
            return true;
        }
    }
    return false;
}

/**
 * Toggles classes on user rows based on toggleType.
 * @param {string} toggleType
 */
function toggleUserRow(toggleType){
    var greenStatusList = $('.status .t-green').toArray();
    var redStatusList = $('.status .t-red').toArray();
    var blueStatusList = $('.status .t-blue').toArray();

    if (toggleType == 'offline') {
        var idleList = $('li [id^=icon62_').toArray();
        var offlineList = $('li [id^=icon2_]').toArray();

        var awayList = idleList.concat(offlineList);
        awayList.forEach(el =>{
            $(el).parent().closest('li').toggleClass('torncat-hide-' + toggleType);
        });
        return;
    }

    blueStatusList.forEach(el => {
        var line = $(el).parent().closest('li');
        $(line).toggleClass('torncat-hide-' + toggleType);
    });


    greenStatusList.forEach(el => {
        var line = $(el).parent().closest('li');
        if(toggleType == 'revive'){
            $(line).toggleClass('torncat-hide-' + toggleType);
        }
    });

    redStatusList.forEach(el => {
        var matches = [
            'Traveling',
            'Fallen',
            'Federal'
        ];

        if (toggleType == 'attack') {
            var line = $(el).parent().closest('li');
            $(line).toggleClass('torncat-hide-' + toggleType);
        } else {
            matches.forEach(match => {
                if ($(el).html().endsWith(match) || $(el).html().endsWith(match + ' ')) {
                    var line = $(el).closest('li');
                    $(line).toggleClass('torncat-hide-' + toggleType);
                }
            });
        }
    });

}

/**
 * Updates a player's row content with API data.
 */
function updatePlayerContent(selector, playerData){
    let statusColor = playerData.status.color;
    let offlineCheck = $('#tc-filter-offline').prop('checked');
    // Apply highlight.
    $(selector).toggleClass('torncat-update');

    // Remove highlight after a delay.
    setTimeout(()=>{
        $(selector).toggleClass('torncat-update');
    }, data.apiQueryDelay * 2);

    // Update row HTML.
    let newHtml = '<span class="d-hide bold">Status:</span><span class="t-' + statusColor + '">' + playerData.status.state + '</span>';
    $(selector).find('div.status').html(newHtml);
    $(selector).find('div.status').css('color', statusColor);

    // Update status icon.
    switch (playerData.last_action.status) {
    case 'Offline':
        $(selector).find('ul#iconTray.singleicon').find('li').first().attr('id','icon2_');
        if (offlineCheck && !($(selector).first().hasClass('torncat-hide-offline'))){
            $(selector).first().addClass('torncat-hide-offline');
            if (develCheck) console.log('FPF: ' + playerData.name + ' went offline');
        }
        break;
    case 'Online':
        $(selector).find('ul#iconTray.singleicon').find('li').first().attr('id','icon1_');
        if (offlineCheck && ($(selector).first().hasClass('torncat-hide-offline'))){
            $(selector).first().removeClass('torncat-hide-offline');
            if (develCheck) console.log('FPF: ' + playerData.name + ' came online');
        }
        break;
    case 'Idle':
        $(selector).find('ul#iconTray.singleicon').find('li').first().attr('id','icon62_');
        if (offlineCheck && !($(selector).first().hasClass('torncat-hide-offline'))){
            $(selector).first().addClass('torncat-hide-offline');
            if (develCheck) console.log('FPF: ' + playerData.name + ' became idle');
        }
        break;
    }

    // Update HTML classes to show/ hide row.
    if ($('#tc-filter-revive').prop('checked')) {
        // Hide traveling
        if (playerData.status.color == 'blue') {
            if (!($(selector).first().hasClass('torncat-hide-revive'))){
                $(selector).first().addClass('torncat-hide-revive');
                if (develCheck) console.debug('FPF: ' + playerData.name + ' is now travelling');
            }
        }
        // Hide Okay
        if (playerData.status.color == 'green') {
            if (!($(selector).first().hasClass('torncat-hide-revive'))){
                $(selector).first().addClass('torncat-hide-revive');
                if (develCheck) console.debug('FPF: ' + playerData.name + ' is Okay and no longer a revivable target.');
            }
        }
        return;
    }

    if ($('#tc-filter-attack').prop('checked')) {
        // Hide traveling
        if (playerData.status.color == 'blue') {
            if (!($(selector).first().hasClass('torncat-hide-attack'))){
                $(selector).first().addClass('torncat-hide-attack');
                if (develCheck) console.debug('FPF: ' + playerData.name + ' is now travelling');
            }
        }
        // Hide anyone else not OK
        if (playerData.status.color == 'red') {
            if (!($(selector).first().hasClass('torncat-hide-revive'))){
                $(selector).first().addClass('torncat-hide-revive');
                if (develCheck) console.debug('FPF: ' + playerData.name + ' is no longer an attackable target.');
            }
        }
    }
}

var styles= `
.torncat-filters div.msg {
    display: flex;
    justify-content: center;
}

.torncat-filters {
    width: 100%
}

.torncat-filter {
    display: inline-block;
    margin: 0 10px 0 10px;
    text-align: center;
}

.torncat-update {
    background: rgba(76, 200, 76, 0.2) !important;
}
.torncat-hide-revive {
    display:none !important;
}
.torncat-hide-attack {
    display:none !important
}
.torncat-hide-offline {
    display:none !important
}

.torncat-icon {
    background-image: url("data:image/svg+xml,%3Csvg data-v-fde0c5aa='' xmlns='http://www.w3.org/2000/svg' viewBox='0 0 300 300' class='icon'%3E%3C!----%3E%3Cdefs data-v-fde0c5aa=''%3E%3C!----%3E%3C/defs%3E%3C!----%3E%3C!----%3E%3Cdefs data-v-fde0c5aa=''%3E%3C!----%3E%3C/defs%3E%3Cg data-v-fde0c5aa='' id='761e8856-1551-45a8-83d8-eb3e49301c32' fill='black' stroke='none' transform='matrix(2.200000047683716,0,0,2.200000047683716,39.999999999999986,39.99999999999999)'%3E%3Cpath d='M93.844 43.76L52.389 70.388V85.92L100 55.314zM0 55.314L47.611 85.92V70.384L6.174 43.718zM50 14.08L9.724 39.972 50 65.887l40.318-25.888L50 14.08zm0 15.954L29.95 42.929l-5.027-3.228L50 23.576l25.077 16.125-5.026 3.228L50 30.034z'%3E%3C/path%3E%3C/g%3E%3C!----%3E%3C/svg%3E");
    background-position: center center;
    background-repeat: no-repeat;
    border-top-left-radius: 5px;
    border-bottom-left-radius: 5px;
    display: inline-block;
    width: 32px;
}

`;
// eslint-disable-next-line no-undef
GM_addStyle(styles);

  """,
);
