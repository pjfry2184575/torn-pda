import 'dart:async';
import 'dart:io';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';
import 'package:torn_pda/models/profile/own_profile_basic.dart';
import 'package:torn_pda/pages/about.dart';
import 'package:torn_pda/pages/alerts.dart';
import 'package:torn_pda/pages/chaining_page.dart';
import 'package:torn_pda/pages/friends_page.dart';
import 'package:torn_pda/pages/loot.dart';
import 'package:torn_pda/pages/awards_page.dart';
import 'package:torn_pda/pages/profile_page.dart';
import 'package:torn_pda/pages/settings_page.dart';
import 'package:torn_pda/main.dart';
import 'package:torn_pda/pages/travel_page.dart';
import 'package:torn_pda/providers/settings_provider.dart';
import 'package:torn_pda/providers/user_details_provider.dart';
import 'package:torn_pda/providers/theme_provider.dart';
import 'package:torn_pda/providers/userscripts_provider.dart';
import 'package:torn_pda/utils/api_caller.dart';
import 'package:torn_pda/utils/changelog.dart';
import 'package:torn_pda/utils/firebase_auth.dart';
import 'package:torn_pda/utils/firebase_firestore.dart';
import 'package:torn_pda/utils/notification.dart';
import 'package:torn_pda/utils/shared_prefs.dart';
import 'package:torn_pda/widgets/webviews/webview_full.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quick_actions/quick_actions.dart';
import 'main.dart';
import 'package:flutter/services.dart';
import 'package:torn_pda/widgets/webviews/webview_dialog.dart';
import 'package:torn_pda/pages/tips_page.dart';
import 'package:torn_pda/widgets/settings/app_exit_dialog.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';

class DrawerPage extends StatefulWidget {
  @override
  _DrawerPageState createState() => _DrawerPageState();
}

class _DrawerPageState extends State<DrawerPage> with WidgetsBindingObserver {
  int _settingsPosition = 7;
  int _aboutPosition = 8;
  var _allowSectionsWithoutKey = [];

  // !! Note: if order is changed, remember to look for other pages calling [_callSectionFromOutside]
  // via callback, as it might need to be changed as well
  final _drawerItemsList = [
    "Profile",
    "Travel",
    "Chaining",
    "Loot",
    "Friends",
    "Awards",
    "Alerts",
    "Settings",
    "About",
    "Tips"
  ];

  ThemeProvider _themeProvider;
  UserDetailsProvider _userProvider;
  SettingsProvider _settingsProvider;
  UserScriptsProvider _userScriptsProvider;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseAnalytics analytics = FirebaseAnalytics();

  Future _finishedWithPreferences;

  int _activeDrawerIndex = 0;
  int _selected = 0;

  Timer _tenSecTimer;
  DateTime _currentTctTime = DateTime.now().toUtc();

  bool _changelogIsActive = false;
  bool _forceFireUserReload = false;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Allows to space alerts when app is on the foreground
  DateTime _lastMessageReceived;
  int concurrent = 0;
  // Assigns different ids to alerts when the app is on the foreground
  var notId = 900;

  // Platform channel with MainActivity.java
  static const platform = const MethodChannel('tornpda.channel');

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // STARTS QUICK ACTIONS
      final QuickActions quickActions = QuickActions();

      quickActions.setShortcutItems(<ShortcutItem>[
        // NOTE: keep the same file name for both platforms
        const ShortcutItem(
            type: 'open_torn',
            localizedTitle: 'Torn Home',
            icon: "action_torn"),
      ]);

      quickActions.initialize((String shortcutType) async {
        if (shortcutType == 'open_torn') {
          var browserType = _settingsProvider.currentBrowser;
          switch (browserType) {
            case BrowserSetting.app:
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (BuildContext context) => WebViewFull(
                    customUrl: 'https://www.torn.com',
                    customTitle: 'Torn',
                  ),
                ),
              );
              break;
            case BrowserSetting.external:
              var url = 'https://www.torn.com';
              if (await canLaunch(url)) {
                await launch(url, forceSafariVC: false);
              }
              break;
          }
        }
      });
    });
    // ENDS QUICK ACTIONS

    WidgetsBinding.instance.addObserver(this);
    _allowSectionsWithoutKey = [
      _settingsPosition,
      _aboutPosition,
    ];

    _handleChangelog();
    _finishedWithPreferences = _loadInitPreferences();

    // This starts a stream that listens for tap on local notifications (i.e.:
    // when the app is open)
    _fireOnTapLocalNotifications();

    // Configure all notifications channels so that Firebase alerts have already
    // and assign channel where to land
    if (Platform.isAndroid) {
      configureNotificationChannels();
    }

    // Configures Firebase notification behaviours
    _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _lastMessageReceived = DateTime.now();

    _messaging.getInitialMessage().then((RemoteMessage message) {
      if (message != null && message.data.isNotEmpty) {
        _fireLaunchResumeNotifications(message.data);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      if (message != null && message.data.isNotEmpty) {
        _fireLaunchResumeNotifications(message.data);
      }
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      // This allows for notifications other than predefined ones in functions
      if (message.data.isEmpty) {
        message.data["title"] = message.notification.title;
        message.data["body"] = message.notification.body;
      }

      // Spaces out several notifications so that all of them show if
      // the app is open (otherwise only 1 of them shows)
      if (DateTime.now().difference(_lastMessageReceived).inSeconds < 2) {
        concurrent++;
        await Future.delayed(Duration(seconds: 8 * concurrent));
      } else {
        concurrent = 0;
      }
      _lastMessageReceived = DateTime.now();
      // Assigns a different id two alerts that come together (otherwise one
      // deletes the previous one)
      notId++;
      if (notId > 990) notId = 900;
      // This will eventually fire a local notification
      return showNotification(message.data, notId);
    });

    _clearBadge();

    _tenSecTimer = new Timer.periodic(
        Duration(seconds: 10), (Timer t) => _refreshTctClock());
  }

  @override
  void dispose() {
    selectNotificationSubject.close();
    WidgetsBinding.instance.removeObserver(this);
    _tenSecTimer.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      // Update Firebase active parameter
      _updateLastActiveTime();

      _clearBadge();

      // Get rid of notifications
      if (Platform.isAndroid && _settingsProvider.removeNotificationsOnLaunch) {
        // Gets the active (already shown) notifications
        final List<ActiveNotification> activeNotifications =
            await flutterLocalNotificationsPlugin
                .resolvePlatformSpecificImplementation<
                    AndroidFlutterLocalNotificationsPlugin>()
                ?.getActiveNotifications();

        for (var not in activeNotifications) {
          // Platform channel to cancel direct Firebase notifications (we can call
          // "cancelAll()" there without affecting scheduled notifications, which is
          // a problem with the local plugin
          if (not.id == 0) {
            await platform.invokeMethod('cancelNotifications');
          }
          // This cancels the Firebase alerts that have been triggered locally
          else {
            flutterLocalNotificationsPlugin.cancel(not.id);
          }
        }
      }
    }
  }

  // TODO Missing bits:
  // IMPORTANT: onResume/Launch only trigger with "FLUTTER_NOTIFICATION_CLICK"
  // from Functions, but not directly from Firebase's Messaging console.
  //  - Give the option to choose different places? Like in nerve,
  //    crimes vs jail. Energy: gym vs dump vs do not open.

  Future<void> _fireLaunchResumeNotifications(Map message) async {
    bool launchBrowser = false;
    var browserUrl = '';

    bool travel = false;
    bool hospital = false;
    bool restocks = false;
    bool racing = false;
    bool messages = false;
    bool events = false;
    bool trades = false;
    bool nerve = false;
    bool energy = false;
    bool drugs = false;

    var channel = '';
    var messageId = '';
    var tradeId = '';

    if (Platform.isIOS) {
      channel = message["channelId"];
      messageId = message["tornMessageId"];
      tradeId = message["tornTradeId"];
    } else if (Platform.isAndroid) {
      channel = message["channelId"];
      messageId = message["tornMessageId"];
      tradeId = message["tornTradeId"];
    }

    if (channel.contains("Alerts travel")) {
      travel = true;
    } else if (channel.contains("Alerts hospital")) {
      hospital = true;
    } else if (channel.contains("Alerts restocks")) {
      restocks = true;
    } else if (channel.contains("Alerts racing")) {
      racing = true;
    } else if (channel.contains("Alerts messages")) {
      messages = true;
    } else if (channel.contains("Alerts events")) {
      events = true;
    } else if (channel.contains("Alerts trades")) {
      trades = true;
    } else if (channel.contains("Alerts nerve")) {
      nerve = true;
    } else if (channel.contains("Alerts energy")) {
      energy = true;
    } else if (channel.contains("Alerts drugs")) {
      drugs = true;
    }

    if (travel) {
      launchBrowser = true;
      browserUrl = "https://www.torn.com";
    } else if (hospital) {
      launchBrowser = true;
      browserUrl = "https://www.torn.com";
    } else if (restocks) {
      launchBrowser = true;
      browserUrl = "https://www.torn.com/travelagency.php";
    } else if (racing) {
      launchBrowser = true;
      browserUrl = "https://www.torn.com/loader.php?sid=racing";
    } else if (messages) {
      launchBrowser = true;
      browserUrl = "https://www.torn.com/messages.php";
      if (messageId != "") {
        browserUrl = "https://www.torn.com/messages.php#/p=read&ID="
            "$messageId&suffix=inbox";
      }
    } else if (events) {
      launchBrowser = true;
      browserUrl = "https://www.torn.com/events.php#/step=all";
    } else if (trades) {
      launchBrowser = true;
      browserUrl = "https://www.torn.com/trade.php";
      if (tradeId != "") {
        browserUrl = "https://www.torn.com/trade.php#step=view&ID="
            "$tradeId";
      }
    } else if (nerve) {
      launchBrowser = true;
      browserUrl = "https://www.torn.com/crimes.php";
    } else if (energy) {
      launchBrowser = true;
      browserUrl = "https://www.torn.com/gym.php";
    } else if (drugs) {
      launchBrowser = true;
      browserUrl = "https://www.torn.com/item.php#drugs-items";
    }

    if (launchBrowser) {
      // iOS seems to open a blank WebView unless we allow some time onResume
      await Future.delayed(Duration(milliseconds: 500));
      // Works best if we get SharedPrefs directly instead of SettingsProvider
      var browserType = await Prefs().getDefaultBrowser();
      switch (browserType) {
        case 'app':
          if (_settingsProvider.useQuickBrowser) {
            openBrowserDialog(
              context,
              browserUrl,
            );
          } else {
            _openTornBrowser(browserUrl);
          }
          break;
        case 'external':
          var url = browserUrl;
          if (await canLaunch(url)) {
            await launch(url, forceSafariVC: false);
          }
          break;
      }
    }
  }

  // Fires if notification from local_notifications package is tapped (i.e.:
  // when the app is open). Also for manual notifications when app is open.
  Future<void> _fireOnTapLocalNotifications() async {
    selectNotificationSubject.stream.listen((String payload) async {
      var launchBrowser = false;
      var browserUrl = '';

      if (payload == 'travel') {
        launchBrowser = true;
        browserUrl = 'https://www.torn.com';
      } else if (payload == 'restocks') {
        launchBrowser = true;
        browserUrl = 'https://www.torn.com/travelagency.php';
      } else if (payload.contains('energy')) {
        launchBrowser = true;
        browserUrl = 'https://www.torn.com/gym.php';
      } else if (payload.contains('nerve')) {
        launchBrowser = true;
        browserUrl = 'https://www.torn.com/crimes.php';
      } else if (payload.contains('drugs')) {
        launchBrowser = true;
        browserUrl = 'https://www.torn.com/item.php#drugs-items';
        // Medical is only in manual notifications, payload comes from Profile
      } else if (payload.contains('medical')) {
        launchBrowser = true;
        browserUrl = 'https://www.torn.com/item.php#medical-items';
        // Booster is only in manual notifications, payload comes from Profile
      } else if (payload.contains('booster')) {
        launchBrowser = true;
        browserUrl = 'https://www.torn.com/item.php#boosters-items';
      } else if (payload.contains('hospital')) {
        launchBrowser = true;
        browserUrl = 'https://www.torn.com';
      } else if (payload.contains('racing')) {
        launchBrowser = true;
        browserUrl = 'https://www.torn.com/loader.php?sid=racing';
      } else if (payload.contains('400-')) {
        launchBrowser = true;
        var npcId = payload.split('-')[1];
        browserUrl =
            'https://www.torn.com/loader.php?sid=attack&user2ID=$npcId';
      } else if (payload.contains('tornMessageId:')) {
        launchBrowser = true;
        var messageId = payload.split(':');
        browserUrl = "https://www.torn.com/messages.php";
        if (messageId[1] != "0") {
          browserUrl = "https://www.torn.com/messages.php#/p=read&ID="
              "${messageId[1]}&suffix=inbox";
        }
      } else if (payload.contains('events')) {
        launchBrowser = true;
        browserUrl = "https://www.torn.com/events.php#/step=all";
      } else if (payload.contains('tornTradeId:')) {
        launchBrowser = true;
        var tradeId = payload.split(':');
        browserUrl = "https://www.torn.com/trade.php";
        if (tradeId[1] != "0") {
          browserUrl =
              "https://www.torn.com/trade.php#step=view&ID=${tradeId[1]}";
        }
      } else if (payload.contains('211')) {
        launchBrowser = true;
        browserUrl = 'https://www.torn.com/travelagency.php';
      }

      if (launchBrowser) {
        var browserType = await Prefs().getDefaultBrowser();
        switch (browserType) {
          case 'app':
            if (_settingsProvider.useQuickBrowser) {
              openBrowserDialog(
                context,
                browserUrl,
              );
            } else {
              _openTornBrowser(browserUrl);
            }
            break;
          case 'external':
            var url = browserUrl;
            if (await canLaunch(url)) {
              await launch(url, forceSafariVC: false);
            }
            break;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    _userProvider = Provider.of<UserDetailsProvider>(context, listen: true);
    return WillPopScope(
      onWillPop: _willPopCallback,
      child: FutureBuilder(
        future: _finishedWithPreferences,
        builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              !_changelogIsActive) {
            return Container(
              color: _themeProvider.currentTheme == AppTheme.light
                  ? Colors.blueGrey
                  : Colors.grey[900],
              child: SafeArea(
                top: _settingsProvider.appBarTop ? false : true,
                bottom: true,
                child: Scaffold(
                  key: _scaffoldKey,
                  body: _getPages(),
                  drawer: Drawer(
                    elevation: 2, // This avoids shadow over SafeArea
                    child: Container(
                      decoration: BoxDecoration(
                          color: _themeProvider.currentTheme == AppTheme.light
                              ? Colors.grey[100]
                              : Colors.transparent,
                          backgroundBlendMode: BlendMode.multiply),
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: <Widget>[
                          _getDrawerHeader(),
                          _getDrawerItems(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          } else {
            return Container(
              color: Colors.black,
              child: SafeArea(
                top: _settingsProvider.appBarTop ? false : true,
                bottom: true,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _getDrawerHeader() {
    return Container(
      height: 300,
      child: DrawerHeader(
        child: Container(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              Flexible(
                child: Image(
                  image: AssetImage('images/icons/torn_pda.png'),
                  fit: BoxFit.fill,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'TORN PDA',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: <Widget>[
                        Text(
                          _themeProvider.currentTheme == AppTheme.light
                              ? 'Light'
                              : 'Dark',
                        ),
                        Padding(
                          padding: EdgeInsets.only(left: 10),
                        ),
                        Switch(
                          value: _themeProvider.currentTheme == AppTheme.dark
                              ? true
                              : false,
                          onChanged: (bool value) {
                            if (value) {
                              _themeProvider.changeTheme = AppTheme.dark;
                            } else {
                              _themeProvider.changeTheme = AppTheme.light;
                            }
                            setState(() {
                              SystemChrome.setSystemUIOverlayStyle(
                                  SystemUiOverlayStyle(
                                statusBarColor: _themeProvider.currentTheme ==
                                        AppTheme.light
                                    ? Colors.blueGrey
                                    : Colors.grey[900],
                              ));
                            });
                          },
                        ),
                      ],
                    ),
                    _tctClock(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tctClock() {
    TimeFormatSetting timePrefs = _settingsProvider.currentTimeFormat;
    DateFormat formatter;
    switch (timePrefs) {
      case TimeFormatSetting.h24:
        formatter = DateFormat('HH:mm');
        break;
      case TimeFormatSetting.h12:
        formatter = DateFormat('hh:mm a');
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(formatter.format(_currentTctTime)),
          Text('TCT'),
        ],
      ),
    );
  }

  Widget _getDrawerItems() {
    var drawerOptions = <Widget>[];
    // If API key is not valid, we just show the Settings + About pages
    // (just don't add the other sections to the list)
    if (!_userProvider.basic.userApiKeyValid) {
      for (var position in _allowSectionsWithoutKey) {
        drawerOptions.add(
          ListTileTheme(
            selectedColor: Colors.red,
            iconColor: _themeProvider.mainText,
            child: Ink(
              color:
                  position == _selected ? Colors.grey[300] : Colors.transparent,
              child: ListTile(
                leading: _returnDrawerIcons(drawerPosition: position),
                title: Text(
                  _drawerItemsList[position],
                  style: TextStyle(
                    fontWeight: position == _selected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                selected: position == _selected,
                onTap: () => _onSelectItem(position),
              ),
            ),
          ),
        );
      }
    } else {
      // Otherwise, if the key is valid, we loop all the sections
      for (var i = 0; i < _drawerItemsList.length; i++) {
        if (_settingsProvider.disableTravelSection &&
            _drawerItemsList[i] == "Travel") {
          continue;
        }

        // Adding divider just before SETTINGS
        if (i == _settingsPosition) {
          drawerOptions.add(Divider());
        }
        drawerOptions.add(
          ListTileTheme(
            selectedColor: Colors.red,
            iconColor: _themeProvider.mainText,
            child: Ink(
              color: i == _selected ? Colors.grey[300] : Colors.transparent,
              child: ListTile(
                leading: _returnDrawerIcons(drawerPosition: i),
                title: Text(
                  _drawerItemsList[i],
                  style: TextStyle(
                    fontWeight:
                        i == _selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: i == _selected,
                onTap: () => _onSelectItem(i),
              ),
            ),
          ),
        );
      }
    }
    return Column(children: drawerOptions);
  }

  Widget _getPages() {
    switch (_activeDrawerIndex) {
      case 0:
        return ProfilePage(
          callBackSection: _callSectionFromOutside,
          disableTravelSection: _onChangeDisableTravelSection,
        );
        break;
      case 1:
        return TravelPage();
        break;
      case 2:
        return ChainingPage();
        break;
      case 3:
        return LootPage();
        break;
      case 4:
        return FriendsPage();
        break;
      case 5:
        return AwardsPage();
        break;
      case 6:
        return AlertsSettings();
        break;
      case 7:
        return SettingsPage();
        break;
      case 8:
        return AboutPage();
        break;
      case 9:
        return TipsPage();
        break;

      default:
        return new Text("Error");
    }
  }

  Widget _returnDrawerIcons({int drawerPosition}) {
    switch (drawerPosition) {
      case 0:
        return Icon(Icons.person);
        break;
      case 1:
        return Icon(Icons.local_airport);
        break;
      case 2:
        return Icon(MdiIcons.linkVariant);
        break;
      case 3:
        return Icon(MdiIcons.knifeMilitary);
        break;
      case 4:
        return Icon(Icons.people);
        break;
      case 5:
        return Icon(MdiIcons.trophy);
        break;
      case 6:
        return Icon(Icons.notifications_active);
        break;
      case 7:
        return Icon(Icons.settings);
        break;
      case 8:
        return Icon(Icons.info_outline);
        break;
      case 9:
        return Icon(Icons.question_answer_outlined);
        break;
      default:
        return SizedBox.shrink();
    }
  }

  _onSelectItem(int index) async {
/*    await analytics.logEvent(
        name: 'section_changed',
        parameters: {'section': _drawerItemsList[index]});*/

    Navigator.of(context).pop();
    setState(() {
      _selected = index;
      _activeDrawerIndex = index;
    });
  }

  Future<void> _loadInitPreferences() async {
    // Set up SettingsProvider so that user preferences are applied
    _settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    await _settingsProvider.loadPreferences();

    // Set up UserScriptsProvider so that user preferences are applied
    _userScriptsProvider =
        Provider.of<UserScriptsProvider>(context, listen: false);
    await _userScriptsProvider.loadPreferences();

    // Set up UserProvider. If key is empty, redirect to the Settings page.
    // Else, open the default
    _userProvider = Provider.of<UserDetailsProvider>(context, listen: false);
    await _userProvider.loadPreferences();

    if (!_userProvider.basic.userApiKeyValid) {
      _selected = _settingsPosition;
      _activeDrawerIndex = _settingsPosition;
    } else {
      var defaultSection = await Prefs().getDefaultSection();
      _selected = int.parse(defaultSection);
      _activeDrawerIndex = int.parse(defaultSection);

      // Firestore get auth and init
      var user = await firebaseAuth.currentUser();
      if (user == null) {
        _updateFirebaseDetails();
      } else {
        var uid = await firebaseAuth.getUID();
        firestore.setUID(uid);
      }

      // Update last used time in Firebase when the app opens (we'll do the same in onResumed,
      // since some people might leave the app opened for weeks in the background)
      _updateLastActiveTime();
    }
  }

  void _updateLastActiveTime() async {
    // Calculate difference between last recorded use and current time
    var now = DateTime.now().millisecondsSinceEpoch;
    var dTimeStamp = now - _settingsProvider.lastAppUse;
    var duration = Duration(milliseconds: dTimeStamp);

    // If the recorded check is over 2 days, upload it to Firestore. 2 days allow for several
    // retries, even if Firebase makes inactive at 7 days (2 days here + 5 advertised)
    // Also update full user in case something is missing!
    if (duration.inDays > 2 || _forceFireUserReload) {
      await _updateFirebaseDetails();
      // This is triggered to true if the changelog activates.
      _forceFireUserReload = false;
    }
  }

  Future<void> _updateFirebaseDetails() async {
    // We save the key because the API call will reset it
    // Then get user's profile and update
    var savedKey = _userProvider.basic.userApiKey;
    dynamic prof = await TornApiCaller.ownBasic(savedKey).getProfileBasic;
    if (prof is OwnProfileBasic) {
      // Update profile with the two fields it does not contain
      prof
        ..userApiKey = savedKey
        ..userApiKeyValid = true;

      // Upload information to Firebase (this includes the token)
      User mFirebaseUser = await firebaseAuth.signInAnon();
      firestore.setUID(mFirebaseUser.uid);
      await firestore.uploadUsersProfileDetail(prof, userTriggered: true);
    }

    // Uploads last active time to Firebase
    var now = DateTime.now().millisecondsSinceEpoch;
    var success = await firestore.uploadLastActiveTime(now);
    if (success) {
      _settingsProvider.updateLastUsed(now);
    }
  }

  void _handleChangelog() async {
    String savedVersion = await Prefs().getAppVersion();
    if (savedVersion != appVersion) {
      Prefs().setAppVersion(appVersion);

      // Exceptions were we don't show a changelog
      /*
      if (savedVersion == '1.6.0') {
        return;
      }
      */

      _changelogIsActive = true;
      _showChangeLogDialog(context);

      // Will trigger an extra upload to Firebase when version changes
      _forceFireUserReload = true;
    }
  }

  void _showChangeLogDialog(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ChangeLog();
      },
    );

    setState(() {
      _changelogIsActive = false;
    });
  }

  void _refreshTctClock() {
    if (mounted) {
      setState(() {
        _currentTctTime = DateTime.now().toUtc();
      });
    }
  }

  void _callSectionFromOutside(int section) {
    setState(() {
      _selected = section;
      _activeDrawerIndex = section;
    });
    _getPages();
  }

  Future _openTornBrowser(String page) async {
    var browserType = _settingsProvider.currentBrowser;

    switch (browserType) {
      case BrowserSetting.app:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (BuildContext context) => WebViewFull(
              customUrl: page,
              customTitle: 'Torn',
            ),
          ),
        );
        break;
      case BrowserSetting.external:
        var url = page;
        if (await canLaunch(url)) {
          await launch(url, forceSafariVC: false);
        }
        break;
    }
  }

  Future<bool> _willPopCallback() async {
    var appExit = _settingsProvider.onAppExit;
    if (appExit == 'exit') {
      return true;
    } else if (appExit == 'stay') {
      // Open drawer instead
      _scaffoldKey.currentState.openDrawer();
      return false;
    } else {
      var action;
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return OnAppExitDialog();
        },
      ).then((choice) {
        action = choice;
      });
      if (action == 'exit') {
        await Future.delayed(Duration(milliseconds: 300));
        return true;
      } else {
        // Open drawer instead
        _scaffoldKey.currentState.openDrawer();
        return false;
      }
    }
  }

  _onChangeDisableTravelSection(bool disable) {
    setState(() {
      _settingsProvider.changeDisableTravelSection = disable;
    });
  }

  void _clearBadge() {
    if (Platform.isIOS) {
      try {
        FlutterAppBadger.removeBadge();
      } catch (e) {
        // Not supported?
      }
    }
  }
}
