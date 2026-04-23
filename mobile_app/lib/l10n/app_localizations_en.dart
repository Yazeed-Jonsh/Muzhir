// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Muzhir';

  @override
  String get home => 'Home';

  @override
  String get diagnose => 'Diagnose';

  @override
  String get map => 'Map';

  @override
  String get history => 'History';

  @override
  String get diseaseMap => 'Disease Map';

  @override
  String get scanHistory => 'Scan History';

  @override
  String get recentDiagnosis => 'Recent Diagnosis';

  @override
  String get viewAll => 'View All';

  @override
  String get languageToggleLabel => 'AR/EN';

  @override
  String get languageChangedToEnglish => 'Language switched to English';

  @override
  String get languageChangedToArabic => 'Language switched to Arabic';

  @override
  String get analysisInProgress => 'Analysis in progress';

  @override
  String get noDiagnosisYet => 'No diagnosis yet';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String hoursAgo(int hours) {
    return '$hours hours ago';
  }

  @override
  String daysAgo(int days) {
    return '$days days ago';
  }

  @override
  String get diagnoseYourPlant => 'Diagnose Your Plant';

  @override
  String get diagnoseHeaderDescription => 'Upload or capture a plant image to detect diseases using our advanced AI botanical analysis engine.';

  @override
  String get tapToUploadOrCaptureImage => 'Tap to upload or capture image';

  @override
  String get supportsJpgPng => 'Supports JPG, PNG up to 10MB';

  @override
  String get captureTip => 'Ensure the leaf is clear and well-lit for best results';

  @override
  String get quickCapture => 'QUICK CAPTURE';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get mobile => 'Mobile';

  @override
  String get drone => 'Drone';

  @override
  String selectedVia(String source) {
    return 'Selected via: $source';
  }

  @override
  String get analyzePlant => 'Analyze Plant';

  @override
  String get pleaseSelectImage => 'Please select an image to enable analysis';

  @override
  String get scanAnother => 'Scan Another';

  @override
  String get getTreatmentAdvice => 'Get Treatment Advice';

  @override
  String get hideTreatmentAdvice => 'Hide treatment advice';

  @override
  String get healthyNoTreatment => 'Your plant is healthy! No treatment needed.';

  @override
  String get noRecentScans => 'No recent scans yet. Run an analysis above to see your latest results here.';

  @override
  String get scanRemovedSuccessfully => 'Scan removed successfully';

  @override
  String couldNotOpenScan(String error) {
    return 'Could not open scan: $error';
  }

  @override
  String analysisFailed(String error) {
    return 'Analysis failed: $error';
  }

  @override
  String couldNotDeleteScan(String error) {
    return 'Could not delete scan: $error';
  }

  @override
  String get couldNotLoadHistory => 'Could not load history';

  @override
  String get retry => 'Retry';

  @override
  String get noScanHistoryYet => 'No scan history yet';

  @override
  String get historyEmptyDescription => 'Your completed diagnoses will show up here. Open the Diagnose tab to analyze a plant.';

  @override
  String get deleteScan => 'Delete scan';

  @override
  String get deleteScanConfirm => 'Are you sure you want to delete this scan?';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get diagnosis => 'Diagnosis';

  @override
  String get deleteScanTooltip => 'Delete scan';

  @override
  String get couldNotLoadScan => 'Could not load scan.';

  @override
  String get noDiagnosisData => 'No diagnosis data.';

  @override
  String get diagnosisResult => 'Diagnosis Result';

  @override
  String get crop => 'Crop';

  @override
  String get labelCropType => 'Crop Type';

  @override
  String get labelCropName => 'Crop name';

  @override
  String get selectCropTypeHint => 'Select crop type';

  @override
  String get disease => 'Disease';

  @override
  String get confidence => 'Confidence';

  @override
  String get source => 'Source';

  @override
  String get location => 'Location';

  @override
  String get treatmentAdvice => 'Treatment advice';

  @override
  String get close => 'Close';

  @override
  String get recommendation => 'Recommendation';

  @override
  String get recommendationUnavailable => 'No recommendation available.';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String get farmer => 'Farmer';

  @override
  String get diseased => 'Diseased';

  @override
  String get healthy => 'Healthy';

  @override
  String get totalScans => 'Total Scans';

  @override
  String get jeddahSaudiArabia => 'Jeddah, Saudi Arabia';

  @override
  String get wind => 'Wind';

  @override
  String get humidity => 'Humidity';

  @override
  String get recentScans => 'Recent Scans';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get all => 'All';

  @override
  String get tomato => 'Tomato';

  @override
  String get corn => 'Corn';

  @override
  String get wheat => 'Wheat';

  @override
  String get couldNotLoadMapMarkers => 'Could not load map markers.';

  @override
  String get couldNotOpenMaps => 'Could not open maps.';

  @override
  String get loadingFieldScans => 'Loading field scans…';

  @override
  String get findingYourLocation => 'Finding your location…';

  @override
  String get showAllMarkers => 'Show all markers';

  @override
  String get myLocation => 'My location';

  @override
  String get unhealthy => 'Unhealthy';

  @override
  String get scanDetails => 'Scan details';

  @override
  String get healthStatus => 'Health status';

  @override
  String get cropType => 'Crop type';

  @override
  String get timestamp => 'Timestamp';

  @override
  String get coordinates => 'Coordinates';

  @override
  String get viewDetails => 'View details';

  @override
  String get navigate => 'Navigate';

  @override
  String get account => 'Account';

  @override
  String get language => 'Language';

  @override
  String get role => 'Role';

  @override
  String get roleFarmer => 'Farmer';

  @override
  String get roleMember => 'Member';

  @override
  String get memberSince => 'Member since';

  @override
  String get settingsAndActions => 'Settings & Actions';

  @override
  String get backendHealthOk => 'Backend health check succeeded.';

  @override
  String get backendHealthFailed => 'Backend unreachable or unhealthy. See console for Dio logs.';

  @override
  String get testBackendConnection => 'Test backend connection';

  @override
  String get signOut => 'Sign Out';

  @override
  String get authWelcomeBack => 'Welcome Back';

  @override
  String get authSignInSubtitle => 'Sign in to manage your farm with AI-powered insights.';

  @override
  String get authEmailAddress => 'Email Address';

  @override
  String get authPassword => 'Password';

  @override
  String get authHintEmail => 'your@email.com';

  @override
  String get authHintPassword => 'Enter your password';

  @override
  String get authEmailRequired => 'Email is required';

  @override
  String get authEmailInvalid => 'Enter a valid email';

  @override
  String get authPasswordRequired => 'Password is required';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authForgotPassword => 'Forgot Password?';

  @override
  String get authLogin => 'Login';

  @override
  String get authSignedInSuccessfully => 'Signed in successfully';

  @override
  String get authEnterEmailFirst => 'Please enter your email first';

  @override
  String get authPasswordResetSent => 'Password reset email sent!';

  @override
  String get authDontHaveAccount => 'Don\'t have an account? ';

  @override
  String get authSignUp => 'Sign Up';

  @override
  String get authCreateAccount => 'Create Account';

  @override
  String get authCreateAccountSubtitle => 'Start protecting your plants with AI-powered disease detection.';

  @override
  String get authFullName => 'Full Name';

  @override
  String get authHintYourName => 'Your name';

  @override
  String get authFullNameRequired => 'Enter your name';

  @override
  String get authHintPasswordMin => 'At least 6 characters';

  @override
  String get authPasswordRequiredSignup => 'Enter a password';

  @override
  String get authPasswordTooShort => 'Password must be at least 6 characters';

  @override
  String get authAccountCreated => 'Account created successfully';

  @override
  String get authWeakPassword => 'Password is too weak. Use at least 6 characters.';

  @override
  String get authEmailAlreadyInUse => 'An account already exists with this email.';

  @override
  String get authTermsIntro => 'By signing up, you agree to our ';

  @override
  String get authTermsOfService => 'Terms of Service';

  @override
  String get authTermsAnd => ' and ';

  @override
  String get authPrivacyPolicy => 'Privacy Policy';

  @override
  String get authTermsOutro => '.';

  @override
  String get authAlreadyHaveAccount => 'Already have an account? ';

  @override
  String get authLogIn => 'Log In';
}
