import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('te'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Abhaya'**
  String get appName;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @safeRoute.
  ///
  /// In en, this message translates to:
  /// **'Safe Route'**
  String get safeRoute;

  /// No description provided for @safetyLearning.
  ///
  /// In en, this message translates to:
  /// **'Safety Learning'**
  String get safetyLearning;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @nightMode.
  ///
  /// In en, this message translates to:
  /// **'Night Mode'**
  String get nightMode;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @guardianActive.
  ///
  /// In en, this message translates to:
  /// **'Guardian Active'**
  String get guardianActive;

  /// No description provided for @guardianOffline.
  ///
  /// In en, this message translates to:
  /// **'Guardian Offline'**
  String get guardianOffline;

  /// No description provided for @sosDispatchActive.
  ///
  /// In en, this message translates to:
  /// **'SOS Dispatch Active'**
  String get sosDispatchActive;

  /// No description provided for @threatAndMood.
  ///
  /// In en, this message translates to:
  /// **'Threat & Mood'**
  String get threatAndMood;

  /// No description provided for @liveTelemetry.
  ///
  /// In en, this message translates to:
  /// **'Live Telemetry'**
  String get liveTelemetry;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @emergencyTools.
  ///
  /// In en, this message translates to:
  /// **'Emergency Tools'**
  String get emergencyTools;

  /// No description provided for @loudSiren.
  ///
  /// In en, this message translates to:
  /// **'Loud Siren'**
  String get loudSiren;

  /// No description provided for @stopSiren.
  ///
  /// In en, this message translates to:
  /// **'Stop Siren'**
  String get stopSiren;

  /// No description provided for @fakeCall.
  ///
  /// In en, this message translates to:
  /// **'Fake Call'**
  String get fakeCall;

  /// No description provided for @silentSos.
  ///
  /// In en, this message translates to:
  /// **'Silent SOS'**
  String get silentSos;

  /// No description provided for @strobe.
  ///
  /// In en, this message translates to:
  /// **'Strobe'**
  String get strobe;

  /// No description provided for @flashOff.
  ///
  /// In en, this message translates to:
  /// **'Flash Off'**
  String get flashOff;

  /// No description provided for @sendEmergencySos.
  ///
  /// In en, this message translates to:
  /// **'SEND EMERGENCY SOS NOW'**
  String get sendEmergencySos;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select your preferred language'**
  String get selectLanguage;

  /// No description provided for @highContrastMode.
  ///
  /// In en, this message translates to:
  /// **'High Contrast Mode'**
  String get highContrastMode;

  /// No description provided for @enhancedColors.
  ///
  /// In en, this message translates to:
  /// **'Enhanced colours for better visibility'**
  String get enhancedColors;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text Size'**
  String get textSize;

  /// No description provided for @adjustTextScale.
  ///
  /// In en, this message translates to:
  /// **'Adjust text scale for readability'**
  String get adjustTextScale;

  /// No description provided for @nightSafetyMode.
  ///
  /// In en, this message translates to:
  /// **'Night Safety Mode'**
  String get nightSafetyMode;

  /// No description provided for @autoActivates.
  ///
  /// In en, this message translates to:
  /// **'Auto-activates between 6 PM and 6 AM'**
  String get autoActivates;

  /// No description provided for @enhancedProtection.
  ///
  /// In en, this message translates to:
  /// **'Enhanced protection active'**
  String get enhancedProtection;

  /// No description provided for @tapToEnable.
  ///
  /// In en, this message translates to:
  /// **'Tap to enable night protection'**
  String get tapToEnable;

  /// No description provided for @shareLocation.
  ///
  /// In en, this message translates to:
  /// **'Share Location with Guardians'**
  String get shareLocation;

  /// No description provided for @shareLocationDesc.
  ///
  /// In en, this message translates to:
  /// **'Guardians can see your live location during journeys'**
  String get shareLocationDesc;

  /// No description provided for @audioDetection.
  ///
  /// In en, this message translates to:
  /// **'Audio Distress Detection'**
  String get audioDetection;

  /// No description provided for @audioDetectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Allows AI to listen for distress signals locally'**
  String get audioDetectionDesc;

  /// No description provided for @anonymousAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Anonymous Usage Analytics'**
  String get anonymousAnalytics;

  /// No description provided for @anonymousAnalyticsDesc.
  ///
  /// In en, this message translates to:
  /// **'Help improve Abhaya with anonymized data'**
  String get anonymousAnalyticsDesc;

  /// No description provided for @deleteAllData.
  ///
  /// In en, this message translates to:
  /// **'Delete All My Data'**
  String get deleteAllData;

  /// No description provided for @deleteAllDataDesc.
  ///
  /// In en, this message translates to:
  /// **'Permanently removes all stored data'**
  String get deleteAllDataDesc;

  /// No description provided for @preciseLocation.
  ///
  /// In en, this message translates to:
  /// **'Precise Location'**
  String get preciseLocation;

  /// No description provided for @preciseLocationDesc.
  ///
  /// In en, this message translates to:
  /// **'Required for SOS and safe route features'**
  String get preciseLocationDesc;

  /// No description provided for @microphone.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get microphone;

  /// No description provided for @microphoneDesc.
  ///
  /// In en, this message translates to:
  /// **'AI distress detection — on-device only'**
  String get microphoneDesc;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @notificationsDesc.
  ///
  /// In en, this message translates to:
  /// **'Emergency alerts and guardian check-ins'**
  String get notificationsDesc;

  /// No description provided for @granted.
  ///
  /// In en, this message translates to:
  /// **'Granted'**
  String get granted;

  /// No description provided for @denied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get denied;

  /// No description provided for @blocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get blocked;

  /// No description provided for @request.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get request;

  /// No description provided for @whereToGo.
  ///
  /// In en, this message translates to:
  /// **'Where do you want to go?'**
  String get whereToGo;

  /// No description provided for @safest.
  ///
  /// In en, this message translates to:
  /// **'Safest'**
  String get safest;

  /// No description provided for @fastest.
  ///
  /// In en, this message translates to:
  /// **'Fastest'**
  String get fastest;

  /// No description provided for @startNavigation.
  ///
  /// In en, this message translates to:
  /// **'START NAVIGATION'**
  String get startNavigation;

  /// No description provided for @aiActive.
  ///
  /// In en, this message translates to:
  /// **'AI ACTIVE'**
  String get aiActive;

  /// No description provided for @enterDestination.
  ///
  /// In en, this message translates to:
  /// **'Enter a destination above to see AI-powered safe route options with real-time safety intelligence.'**
  String get enterDestination;

  /// No description provided for @knowledgeIsShield.
  ///
  /// In en, this message translates to:
  /// **'Knowledge is your best shield'**
  String get knowledgeIsShield;

  /// No description provided for @startLearning.
  ///
  /// In en, this message translates to:
  /// **'Start Learning →'**
  String get startLearning;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @safeContacts.
  ///
  /// In en, this message translates to:
  /// **'Safe Contacts'**
  String get safeContacts;

  /// No description provided for @addContact.
  ///
  /// In en, this message translates to:
  /// **'Add Contact'**
  String get addContact;

  /// No description provided for @noContacts.
  ///
  /// In en, this message translates to:
  /// **'No contacts added yet. Add trusted contacts to receive your SOS alerts.'**
  String get noContacts;

  /// No description provided for @nightSettings.
  ///
  /// In en, this message translates to:
  /// **'Night Settings'**
  String get nightSettings;

  /// No description provided for @sirenVolume.
  ///
  /// In en, this message translates to:
  /// **'Siren Volume'**
  String get sirenVolume;

  /// No description provided for @autoSos.
  ///
  /// In en, this message translates to:
  /// **'Auto SOS on No Response'**
  String get autoSos;

  /// No description provided for @stealthMode.
  ///
  /// In en, this message translates to:
  /// **'Stealth Mode'**
  String get stealthMode;

  /// No description provided for @autoSosDelay.
  ///
  /// In en, this message translates to:
  /// **'Auto SOS Delay'**
  String get autoSosDelay;
  String get profile;
  String get editName;
  String get name;
  String get email;
  String get phone;
  String get age;
  String get gender;
  String get notSet;
  String get backgroundSensing;
  String get moodSharing;
  String get signOut;
  String get signOutConfirm;
  String get cancel;
  String get confirm;
  String get tapToChangePhoto;
  String get guardians;
  String get myGuardians;
  String get addGuardian;
  String get noGuardians;
  String get addGuardianDesc;
  String get alerts;
  String get communityAlerts;
  String get areaSafety;
  String get incidentHistory;
  String get emergencyEvents;
  String get myReports;
  String get noIncidents;
  String get noReports;
  String get reportIncident;
  String get submitReport;
  String get incidentType;
  String get description;
  String get anonymous;
  String get location;
  String get journeyHistory;
  String get noPastJourneys;
  String get safeZone;
  String get criticalThreat;
  String get elevatedHazard;
  String get moderateContext;
  String get engine;
  String get refresh;
  String get loading;
  String get error;
  String get retry;
  String get appBarTitle;

  // ── Home Screen ───────────────────────────────────────────────────────────
  String get sosActive;
  String get active;
  String get idle;
  String get critical;
  String get elevated;
  String get safe;
  String get offlineStatus;
  String get calm;
  String get audioDistressSignal;
  String get motion;
  String get locationRisk;
  String get heartRateLabel;
  String get timeContext;
  String get stepsLabel;
  String get sensorLive;
  String get enableSensors;
  String get deactivateGuardian;
  String get initiateTracking;
  String get initializing;
  String get actionRequired;
  String get enableLocationAccess;
  String get openSettings;
  String get companion;
  String get journeys;
  String get reportLabel;
  String get emergencyDetected;
  String get aiDetectedThreat;
  String get activateEmergencySos;
  String get imSafeDismiss;
  String get sosDispatched;
  String get suddenImpact;
  String get rapidRotation;
  String get position;
  String get speedLabel;
  String get altitudeLabel;
  String get accuracyLabel;
  String get acquiringGps;
  String get batteryLabel;
  String get locationLabel;

  String get guardianNetwork;
  String get profileTitle;
  
  // ── Profile Screen ────────────────────────────────────────────────────────
  String get aiSafeRouteWeights;
  String get isolateCrimeHotspots;
  String get isolateCrimeHotspotsDesc;
  String get prioritizeCctv;
  String get prioritizeCctvDesc;
  String get nightModeThreatElevation;
  String get nightModeThreatElevationDesc;
  String get privacySensing;
  String get backgroundSensingDesc;
  String get moodSharingDesc;
  String get biometricAppLock;
  String get biometricAppLockDesc;
  String get hardwareSync;
  String get noBandConnected;
  String get scanForBand;
  String get scan;
  String get toolsResources;
  String get safetyLearningDesc;
  String get privacySettings;
  String get privacySettingsDesc;
  String get signOutDesc;
  String get userRole;
  String get save;
  String get paired;
  String get disconnectLabel;
  String get connectingStatus;
  String get scanningDevices;
  String get foundDevices;
  String get failedToUpdateSettings;
  String get uploadFailed;
  String get failedToUpdateName;

  // ── Guardians Screen ──────────────────────────────────────────────────────
  String get myTrustCircle;
  String get trustCircleDesc;
  String get linkedNodes;
  String get securelyLinkNewNode;
  String get guardianPhoneHint;
  String get sendRequest;
  String get connectionRequestSent;
  String get loadingGuardianNetwork;
  String get noNodesLinked;
  String get nodesLinkedActive;
  String get synced;
  String get liveGuardianView;
  String get locationSharingEnabled;

  // ── Community / Alerts Screen ─────────────────────────────────────────────
  String get alertsIntel;
  String get safetyIntelDesc;
  String get liveThreatLevel;
  String get guardianActiveMonitoring;
  String get guardianOfflineEnable;
  String get incidentFeed;
  String get records;
  String get noIncidentsYouAreSafe;
  String get manualSos;
  String get crisisChatAlert;
  String get audioDistressAlertLabel;
  String get motionAnomaly;

  // ── Incident History ──────────────────────────────────────────────────────
  String get emergenciesTab;
  String get reportsTab;
  String get noEmergenciesRecorded;
  String get noUserReports;
  String get failedToLoadHistory;
  String get motionAnomalyDetected;
  String get resolved;
  String get dismissed;
  String get incidentDetails;
  String get attachedMedia;
  String get resolutionNotesLabel;
  String get markResolved;
  String get resolvingStatus;
  String get incidentStillActive;
  String get noNotesProvided;
  String get todayLabel;
  String get yesterdayLabel;
  String get severity;

  // ── Journey ───────────────────────────────────────────────────────────────
  String get unknownDestination;
  String get unknownDate;

  // ── Chat ───────────────────────────────────────────────────────────────────
  String get aiCompanion;
  String get iFeelAnxious;
  String get trackMyRoute;
  String get typeMessage;
  String get thinking;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'hi', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'hi': return AppLocalizationsHi();
    case 'te': return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
