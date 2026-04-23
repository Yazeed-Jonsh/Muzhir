// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'مزهر';

  @override
  String get home => 'الرئيسية';

  @override
  String get diagnose => 'تشخيص';

  @override
  String get map => 'الخريطة';

  @override
  String get history => 'السجل';

  @override
  String get diseaseMap => 'خريطة الأمراض';

  @override
  String get scanHistory => 'سجل الفحوصات';

  @override
  String get recentDiagnosis => 'أحدث التشخيصات';

  @override
  String get viewAll => 'عرض الكل';

  @override
  String get languageToggleLabel => 'AR/EN';

  @override
  String get languageChangedToEnglish => 'تم تغيير اللغة إلى الإنجليزية';

  @override
  String get languageChangedToArabic => 'تم تغيير اللغة إلى العربية';

  @override
  String get analysisInProgress => 'التحليل قيد التنفيذ';

  @override
  String get noDiagnosisYet => 'لا يوجد تشخيص بعد';

  @override
  String get justNow => 'الآن';

  @override
  String minutesAgo(int minutes) {
    return 'منذ $minutes دقيقة';
  }

  @override
  String hoursAgo(int hours) {
    return 'منذ $hours ساعة';
  }

  @override
  String daysAgo(int days) {
    return 'منذ $days يوم';
  }

  @override
  String get diagnoseYourPlant => 'شخّص نبتتك';

  @override
  String get diagnoseHeaderDescription => 'قم برفع أو التقاط صورة للنبتة لاكتشاف الأمراض باستخدام محرك التحليل النباتي الذكي.';

  @override
  String get tapToUploadOrCaptureImage => 'اضغط لرفع الصورة أو التقاطها';

  @override
  String get supportsJpgPng => 'يدعم JPG وPNG حتى 10 ميجابايت';

  @override
  String get captureTip => 'تأكد أن الورقة واضحة وإضاءتها جيدة للحصول على أفضل نتيجة';

  @override
  String get quickCapture => 'التقاط سريع';

  @override
  String get camera => 'الكاميرا';

  @override
  String get gallery => 'المعرض';

  @override
  String get mobile => 'الهاتف';

  @override
  String get drone => 'الدرون';

  @override
  String selectedVia(String source) {
    return 'تم الاختيار عبر: $source';
  }

  @override
  String get analyzePlant => 'تحليل النبتة';

  @override
  String get pleaseSelectImage => 'يرجى اختيار صورة لتفعيل التحليل';

  @override
  String get scanAnother => 'فحص صورة أخرى';

  @override
  String get getTreatmentAdvice => 'عرض نصائح العلاج';

  @override
  String get hideTreatmentAdvice => 'إخفاء نصائح العلاج';

  @override
  String get healthyNoTreatment => 'نبتتك بصحة جيدة! لا حاجة للعلاج.';

  @override
  String get noRecentScans => 'لا توجد فحوصات حديثة بعد. شغّل تحليلاً بالأعلى لترى النتائج هنا.';

  @override
  String get scanRemovedSuccessfully => 'تم حذف الفحص بنجاح';

  @override
  String couldNotOpenScan(String error) {
    return 'تعذر فتح الفحص: $error';
  }

  @override
  String analysisFailed(String error) {
    return 'فشل التحليل: $error';
  }

  @override
  String couldNotDeleteScan(String error) {
    return 'تعذر حذف الفحص: $error';
  }

  @override
  String get couldNotLoadHistory => 'تعذر تحميل السجل';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get noScanHistoryYet => 'لا يوجد سجل فحوصات بعد';

  @override
  String get historyEmptyDescription => 'ستظهر تشخيصاتك المكتملة هنا. افتح تبويب التشخيص لتحليل نبتة.';

  @override
  String get deleteScan => 'حذف الفحص';

  @override
  String get deleteScanConfirm => 'هل أنت متأكد أنك تريد حذف هذا الفحص؟';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get diagnosis => 'التشخيص';

  @override
  String get deleteScanTooltip => 'حذف الفحص';

  @override
  String get couldNotLoadScan => 'تعذر تحميل الفحص.';

  @override
  String get noDiagnosisData => 'لا توجد بيانات تشخيص.';

  @override
  String get diagnosisResult => 'نتيجة التشخيص';

  @override
  String get crop => 'المحصول';

  @override
  String get labelCropType => 'نوع المحصول';

  @override
  String get labelCropName => 'اسم المحصول';

  @override
  String get selectCropTypeHint => 'اختر نوع المحصول';

  @override
  String get disease => 'المرض';

  @override
  String get confidence => 'الثقة';

  @override
  String get source => 'المصدر';

  @override
  String get location => 'الموقع';

  @override
  String get treatmentAdvice => 'نصائح العلاج';

  @override
  String get close => 'إغلاق';

  @override
  String get recommendation => 'التوصية';

  @override
  String get recommendationUnavailable => 'لا توجد توصية متاحة.';

  @override
  String get goodMorning => 'صباح الخير';

  @override
  String get goodAfternoon => 'مساء الخير';

  @override
  String get goodEvening => 'مساء الخير';

  @override
  String get farmer => 'مزارع';

  @override
  String get diseased => 'مصاب';

  @override
  String get healthy => 'سليم';

  @override
  String get totalScans => 'إجمالي الفحوصات';

  @override
  String get jeddahSaudiArabia => 'جدة، المملكة العربية السعودية';

  @override
  String get wind => 'الرياح';

  @override
  String get humidity => 'الرطوبة';

  @override
  String get recentScans => 'الفحوصات الأخيرة';

  @override
  String get yesterday => 'أمس';

  @override
  String get all => 'الكل';

  @override
  String get tomato => 'طماطم';

  @override
  String get corn => 'ذرة';

  @override
  String get wheat => 'قمح';

  @override
  String get couldNotLoadMapMarkers => 'تعذر تحميل علامات الخريطة.';

  @override
  String get couldNotOpenMaps => 'تعذر فتح الخرائط.';

  @override
  String get loadingFieldScans => 'جاري تحميل فحوصات الحقول…';

  @override
  String get findingYourLocation => 'جاري تحديد موقعك…';

  @override
  String get showAllMarkers => 'إظهار جميع العلامات';

  @override
  String get myLocation => 'موقعي';

  @override
  String get unhealthy => 'غير سليم';

  @override
  String get scanDetails => 'تفاصيل الفحص';

  @override
  String get healthStatus => 'الحالة الصحية';

  @override
  String get cropType => 'نوع المحصول';

  @override
  String get timestamp => 'الوقت';

  @override
  String get coordinates => 'الإحداثيات';

  @override
  String get viewDetails => 'عرض التفاصيل';

  @override
  String get navigate => 'تنقل';

  @override
  String get account => 'الحساب';

  @override
  String get language => 'اللغة';

  @override
  String get role => 'الدور';

  @override
  String get roleFarmer => 'مزارع';

  @override
  String get roleMember => 'عضو';

  @override
  String get memberSince => 'عضو منذ';

  @override
  String get settingsAndActions => 'الإعدادات والإجراءات';

  @override
  String get backendHealthOk => 'نجح فحص صحة الخادم.';

  @override
  String get backendHealthFailed => 'الخادم غير متاح أو غير سليم. راجع السجل لمزيد من التفاصيل.';

  @override
  String get testBackendConnection => 'اختبار اتصال الخادم';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get authWelcomeBack => 'مرحباً بعودتك';

  @override
  String get authSignInSubtitle => 'سجّل الدخول لإدارة مزرعتك برؤى مدعومة بالذكاء الاصطناعي.';

  @override
  String get authEmailAddress => 'البريد الإلكتروني';

  @override
  String get authPassword => 'كلمة المرور';

  @override
  String get authHintEmail => 'بريدك@example.com';

  @override
  String get authHintPassword => 'أدخل كلمة المرور';

  @override
  String get authEmailRequired => 'البريد الإلكتروني مطلوب';

  @override
  String get authEmailInvalid => 'أدخل بريداً إلكترونياً صالحاً';

  @override
  String get authPasswordRequired => 'كلمة المرور مطلوبة';

  @override
  String get authShowPassword => 'إظهار كلمة المرور';

  @override
  String get authHidePassword => 'إخفاء كلمة المرور';

  @override
  String get authForgotPassword => 'نسيت كلمة المرور؟';

  @override
  String get authLogin => 'تسجيل الدخول';

  @override
  String get authSignedInSuccessfully => 'تم تسجيل الدخول بنجاح';

  @override
  String get authEnterEmailFirst => 'يرجى إدخال بريدك الإلكتروني أولاً';

  @override
  String get authPasswordResetSent => 'تم إرسال رسالة إعادة تعيين كلمة المرور!';

  @override
  String get authDontHaveAccount => 'ليس لديك حساب؟ ';

  @override
  String get authSignUp => 'إنشاء حساب';

  @override
  String get authCreateAccount => 'إنشاء حساب';

  @override
  String get authCreateAccountSubtitle => 'ابدأ بحماية نباتاتك من أمراض النبات باستخدام الكشف المدعوم بالذكاء الاصطناعي.';

  @override
  String get authFullName => 'الاسم الكامل';

  @override
  String get authHintYourName => 'اسمك';

  @override
  String get authFullNameRequired => 'أدخل اسمك';

  @override
  String get authHintPasswordMin => '6 أحرف على الأقل';

  @override
  String get authPasswordRequiredSignup => 'أدخل كلمة مرور';

  @override
  String get authPasswordTooShort => 'يجب أن تكون كلمة المرور 6 أحرف على الأقل';

  @override
  String get authAccountCreated => 'تم إنشاء الحساب بنجاح';

  @override
  String get authWeakPassword => 'كلمة المرور ضعيفة. استخدم 6 أحرف على الأقل.';

  @override
  String get authEmailAlreadyInUse => 'يوجد حساب مرتبط بهذا البريد الإلكتروني.';

  @override
  String get authTermsIntro => 'بالتسجيل، أنت توافق على ';

  @override
  String get authTermsOfService => 'شروط الخدمة';

  @override
  String get authTermsAnd => ' و';

  @override
  String get authPrivacyPolicy => 'سياسة الخصوصية';

  @override
  String get authTermsOutro => '.';

  @override
  String get authAlreadyHaveAccount => 'لديك حساب بالفعل؟ ';

  @override
  String get authLogIn => 'تسجيل الدخول';
}
