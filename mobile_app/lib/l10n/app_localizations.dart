import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

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
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Muzhir'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @diagnose.
  ///
  /// In en, this message translates to:
  /// **'Diagnose'**
  String get diagnose;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @diseaseMap.
  ///
  /// In en, this message translates to:
  /// **'Disease Map'**
  String get diseaseMap;

  /// No description provided for @scanHistory.
  ///
  /// In en, this message translates to:
  /// **'Scan History'**
  String get scanHistory;

  /// No description provided for @recentDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Recent Diagnosis'**
  String get recentDiagnosis;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @languageToggleLabel.
  ///
  /// In en, this message translates to:
  /// **'AR/EN'**
  String get languageToggleLabel;

  /// No description provided for @languageChangedToEnglish.
  ///
  /// In en, this message translates to:
  /// **'Language switched to English'**
  String get languageChangedToEnglish;

  /// No description provided for @languageChangedToArabic.
  ///
  /// In en, this message translates to:
  /// **'Language switched to Arabic'**
  String get languageChangedToArabic;

  /// No description provided for @analysisInProgress.
  ///
  /// In en, this message translates to:
  /// **'Analysis in progress'**
  String get analysisInProgress;

  /// No description provided for @noDiagnosisYet.
  ///
  /// In en, this message translates to:
  /// **'No diagnosis yet'**
  String get noDiagnosisYet;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get justNow;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min ago'**
  String minutesAgo(int minutes);

  /// No description provided for @hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours ago'**
  String hoursAgo(int hours);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String daysAgo(int days);

  /// No description provided for @diagnoseYourPlant.
  ///
  /// In en, this message translates to:
  /// **'Diagnose Your Plant'**
  String get diagnoseYourPlant;

  /// No description provided for @diagnoseHeaderDescription.
  ///
  /// In en, this message translates to:
  /// **'Upload or capture a plant image to detect diseases using our advanced AI botanical analysis engine.'**
  String get diagnoseHeaderDescription;

  /// No description provided for @tapToUploadOrCaptureImage.
  ///
  /// In en, this message translates to:
  /// **'Tap to upload or capture image'**
  String get tapToUploadOrCaptureImage;

  /// No description provided for @supportsJpgPng.
  ///
  /// In en, this message translates to:
  /// **'Supports JPG, PNG up to 10MB'**
  String get supportsJpgPng;

  /// No description provided for @captureTip.
  ///
  /// In en, this message translates to:
  /// **'Ensure the leaf is clear and well-lit for best results'**
  String get captureTip;

  /// No description provided for @quickCapture.
  ///
  /// In en, this message translates to:
  /// **'QUICK CAPTURE'**
  String get quickCapture;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @mobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile'**
  String get mobile;

  /// No description provided for @drone.
  ///
  /// In en, this message translates to:
  /// **'Drone'**
  String get drone;

  /// No description provided for @selectedVia.
  ///
  /// In en, this message translates to:
  /// **'Selected via: {source}'**
  String selectedVia(String source);

  /// No description provided for @analyzePlant.
  ///
  /// In en, this message translates to:
  /// **'Analyze Plant'**
  String get analyzePlant;

  /// No description provided for @pleaseSelectImage.
  ///
  /// In en, this message translates to:
  /// **'Please select an image to enable analysis'**
  String get pleaseSelectImage;

  /// No description provided for @scanAnother.
  ///
  /// In en, this message translates to:
  /// **'Scan Another'**
  String get scanAnother;

  /// No description provided for @getTreatmentAdvice.
  ///
  /// In en, this message translates to:
  /// **'Get Treatment Advice'**
  String get getTreatmentAdvice;

  /// No description provided for @hideTreatmentAdvice.
  ///
  /// In en, this message translates to:
  /// **'Hide treatment advice'**
  String get hideTreatmentAdvice;

  /// No description provided for @healthyNoTreatment.
  ///
  /// In en, this message translates to:
  /// **'Your plant is healthy! No treatment needed.'**
  String get healthyNoTreatment;

  /// No description provided for @noRecentScans.
  ///
  /// In en, this message translates to:
  /// **'No recent scans yet. Run an analysis above to see your latest results here.'**
  String get noRecentScans;

  /// No description provided for @scanRemovedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Scan removed successfully'**
  String get scanRemovedSuccessfully;

  /// No description provided for @couldNotOpenScan.
  ///
  /// In en, this message translates to:
  /// **'Could not open scan: {error}'**
  String couldNotOpenScan(String error);

  /// No description provided for @analysisFailed.
  ///
  /// In en, this message translates to:
  /// **'Analysis failed: {error}'**
  String analysisFailed(String error);

  /// No description provided for @couldNotDeleteScan.
  ///
  /// In en, this message translates to:
  /// **'Could not delete scan: {error}'**
  String couldNotDeleteScan(String error);

  /// No description provided for @couldNotLoadHistory.
  ///
  /// In en, this message translates to:
  /// **'Could not load history'**
  String get couldNotLoadHistory;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @noScanHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No scan history yet'**
  String get noScanHistoryYet;

  /// No description provided for @historyEmptyDescription.
  ///
  /// In en, this message translates to:
  /// **'Your completed diagnoses will show up here. Open the Diagnose tab to analyze a plant.'**
  String get historyEmptyDescription;

  /// No description provided for @deleteScan.
  ///
  /// In en, this message translates to:
  /// **'Delete scan'**
  String get deleteScan;

  /// No description provided for @deleteScanConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this scan?'**
  String get deleteScanConfirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @diagnosis.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis'**
  String get diagnosis;

  /// No description provided for @deleteScanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete scan'**
  String get deleteScanTooltip;

  /// No description provided for @couldNotLoadScan.
  ///
  /// In en, this message translates to:
  /// **'Could not load scan.'**
  String get couldNotLoadScan;

  /// No description provided for @noDiagnosisData.
  ///
  /// In en, this message translates to:
  /// **'No diagnosis data.'**
  String get noDiagnosisData;

  /// No description provided for @diagnosisResult.
  ///
  /// In en, this message translates to:
  /// **'Diagnosis Result'**
  String get diagnosisResult;

  /// No description provided for @crop.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get crop;

  /// No description provided for @labelCropType.
  ///
  /// In en, this message translates to:
  /// **'Crop Type'**
  String get labelCropType;

  /// No description provided for @labelCropName.
  ///
  /// In en, this message translates to:
  /// **'Crop name'**
  String get labelCropName;

  /// No description provided for @selectCropTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Select crop type'**
  String get selectCropTypeHint;

  /// No description provided for @disease.
  ///
  /// In en, this message translates to:
  /// **'Disease'**
  String get disease;

  /// No description provided for @confidence.
  ///
  /// In en, this message translates to:
  /// **'Confidence'**
  String get confidence;

  /// No description provided for @source.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get source;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @treatmentAdvice.
  ///
  /// In en, this message translates to:
  /// **'Treatment advice'**
  String get treatmentAdvice;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @recommendation.
  ///
  /// In en, this message translates to:
  /// **'Recommendation'**
  String get recommendation;

  /// No description provided for @recommendationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No recommendation available.'**
  String get recommendationUnavailable;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// No description provided for @farmer.
  ///
  /// In en, this message translates to:
  /// **'Farmer'**
  String get farmer;

  /// No description provided for @diseased.
  ///
  /// In en, this message translates to:
  /// **'Diseased'**
  String get diseased;

  /// No description provided for @healthy.
  ///
  /// In en, this message translates to:
  /// **'Healthy'**
  String get healthy;

  /// No description provided for @totalScans.
  ///
  /// In en, this message translates to:
  /// **'Total Scans'**
  String get totalScans;

  /// No description provided for @jeddahSaudiArabia.
  ///
  /// In en, this message translates to:
  /// **'Jeddah, Saudi Arabia'**
  String get jeddahSaudiArabia;

  /// No description provided for @wind.
  ///
  /// In en, this message translates to:
  /// **'Wind'**
  String get wind;

  /// No description provided for @humidity.
  ///
  /// In en, this message translates to:
  /// **'Humidity'**
  String get humidity;

  /// No description provided for @recentScans.
  ///
  /// In en, this message translates to:
  /// **'Recent Scans'**
  String get recentScans;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @tomato.
  ///
  /// In en, this message translates to:
  /// **'Tomato'**
  String get tomato;

  /// No description provided for @corn.
  ///
  /// In en, this message translates to:
  /// **'Corn'**
  String get corn;

  /// No description provided for @wheat.
  ///
  /// In en, this message translates to:
  /// **'Wheat'**
  String get wheat;

  /// No description provided for @couldNotLoadMapMarkers.
  ///
  /// In en, this message translates to:
  /// **'Could not load map markers.'**
  String get couldNotLoadMapMarkers;

  /// No description provided for @couldNotOpenMaps.
  ///
  /// In en, this message translates to:
  /// **'Could not open maps.'**
  String get couldNotOpenMaps;

  /// No description provided for @loadingFieldScans.
  ///
  /// In en, this message translates to:
  /// **'Loading field scans…'**
  String get loadingFieldScans;

  /// No description provided for @findingYourLocation.
  ///
  /// In en, this message translates to:
  /// **'Finding your location…'**
  String get findingYourLocation;

  /// No description provided for @showAllMarkers.
  ///
  /// In en, this message translates to:
  /// **'Show all markers'**
  String get showAllMarkers;

  /// No description provided for @myLocation.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get myLocation;

  /// No description provided for @unhealthy.
  ///
  /// In en, this message translates to:
  /// **'Unhealthy'**
  String get unhealthy;

  /// No description provided for @scanDetails.
  ///
  /// In en, this message translates to:
  /// **'Scan details'**
  String get scanDetails;

  /// No description provided for @healthStatus.
  ///
  /// In en, this message translates to:
  /// **'Health status'**
  String get healthStatus;

  /// No description provided for @cropType.
  ///
  /// In en, this message translates to:
  /// **'Crop type'**
  String get cropType;

  /// No description provided for @timestamp.
  ///
  /// In en, this message translates to:
  /// **'Timestamp'**
  String get timestamp;

  /// No description provided for @coordinates.
  ///
  /// In en, this message translates to:
  /// **'Coordinates'**
  String get coordinates;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get viewDetails;

  /// No description provided for @navigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get navigate;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @role.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get role;

  /// No description provided for @roleFarmer.
  ///
  /// In en, this message translates to:
  /// **'Farmer'**
  String get roleFarmer;

  /// No description provided for @roleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get roleMember;

  /// No description provided for @memberSince.
  ///
  /// In en, this message translates to:
  /// **'Member since'**
  String get memberSince;

  /// No description provided for @settingsAndActions.
  ///
  /// In en, this message translates to:
  /// **'Settings & Actions'**
  String get settingsAndActions;

  /// No description provided for @backendHealthOk.
  ///
  /// In en, this message translates to:
  /// **'Backend health check succeeded.'**
  String get backendHealthOk;

  /// No description provided for @backendHealthFailed.
  ///
  /// In en, this message translates to:
  /// **'Backend unreachable or unhealthy. See console for Dio logs.'**
  String get backendHealthFailed;

  /// No description provided for @testBackendConnection.
  ///
  /// In en, this message translates to:
  /// **'Test backend connection'**
  String get testBackendConnection;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get authWelcomeBack;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage your farm with AI-powered insights.'**
  String get authSignInSubtitle;

  /// No description provided for @authEmailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get authEmailAddress;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authHintEmail.
  ///
  /// In en, this message translates to:
  /// **'your@email.com'**
  String get authHintEmail;

  /// No description provided for @authHintPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get authHintPassword;

  /// No description provided for @authEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get authEmailRequired;

  /// No description provided for @authEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get authEmailInvalid;

  /// No description provided for @authPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get authPasswordRequired;

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get authForgotPassword;

  /// No description provided for @authLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get authLogin;

  /// No description provided for @authSignedInSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Signed in successfully'**
  String get authSignedInSuccessfully;

  /// No description provided for @authEnterEmailFirst.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email first'**
  String get authEnterEmailFirst;

  /// No description provided for @authPasswordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent!'**
  String get authPasswordResetSent;

  /// No description provided for @authDontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get authDontHaveAccount;

  /// No description provided for @authSignUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get authSignUp;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get authCreateAccount;

  /// No description provided for @authCreateAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start protecting your plants with AI-powered disease detection.'**
  String get authCreateAccountSubtitle;

  /// No description provided for @authFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get authFullName;

  /// No description provided for @authHintYourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get authHintYourName;

  /// No description provided for @authFullNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get authFullNameRequired;

  /// No description provided for @authHintPasswordMin.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get authHintPasswordMin;

  /// No description provided for @authPasswordRequiredSignup.
  ///
  /// In en, this message translates to:
  /// **'Enter a password'**
  String get authPasswordRequiredSignup;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get authPasswordTooShort;

  /// No description provided for @authAccountCreated.
  ///
  /// In en, this message translates to:
  /// **'Account created successfully'**
  String get authAccountCreated;

  /// No description provided for @authWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password is too weak. Use at least 6 characters.'**
  String get authWeakPassword;

  /// No description provided for @authEmailAlreadyInUse.
  ///
  /// In en, this message translates to:
  /// **'An account already exists with this email.'**
  String get authEmailAlreadyInUse;

  /// No description provided for @authTermsIntro.
  ///
  /// In en, this message translates to:
  /// **'By signing up, you agree to our '**
  String get authTermsIntro;

  /// No description provided for @authTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get authTermsOfService;

  /// No description provided for @authTermsAnd.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get authTermsAnd;

  /// No description provided for @authPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get authPrivacyPolicy;

  /// No description provided for @authTermsOutro.
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get authTermsOutro;

  /// No description provided for @authAlreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get authAlreadyHaveAccount;

  /// No description provided for @authLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log In'**
  String get authLogIn;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar': return AppLocalizationsAr();
    case 'en': return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
