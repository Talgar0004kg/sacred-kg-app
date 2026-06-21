import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('ru'), Locale('ky')];
  static const delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const _values = <String, Map<String, String>>{
    'en': {
      'appTitle': 'Sacred KG',
      'tagline': 'Sacred routes of Kyrgyzstan',
      'onboardingTitle': 'Sacred places, respectful routes, living stories.',
      'onboardingBody':
          'Explore Kyrgyzstan through mock cultural guides, region cards, local posts, booking requests, and an assistant ready for a future AI backend.',
      'login': 'Log in',
      'createAccount': 'Create account',
      'continueAsGuest': 'Continue as guest',
      'welcomeBack': 'Welcome back',
      'loginSubtitle':
          'Sign in to plan your trips across Kyrgyzstan and save your favourite places.',
      'loginGreeting': 'Welcome to Sacred KG',
      'logoutAction': 'Sign out',
      'languageMenu': 'Language',
      'email': 'Email',
      'password': 'Password',
      'bothFieldsRequired': 'Please enter your email and password.',
      'invalidEmail': 'Invalid email',
      'enterEmail': 'Enter your email',
      'minSixChars': 'At least 6 characters',
      'passwordsDoNotMatch': 'Passwords do not match',
      'minTwoChars': 'At least 2 characters',
      'confirmRules': 'Please confirm the rules of visit',
      'emailAlreadyInUse': 'This email is already in use',
      'registration': 'Registration',
      'createTravellerAccount': 'Create a traveller account',
      'registerCaption':
          'Save favourites, booking requests and your chats with the Apashka and Atashka AI guides.',
      'repeatPassword': 'Repeat password',
      'helperMinSix': 'At least 6 characters',
      'agreeRules':
          'I agree to the rules of visiting sacred places and to the processing of my personal data',
      'registerSubtitle': 'A local profile is enough for the prototype.',
      'name': 'Name',
      'register': 'Register',
      'alreadyHaveAccount': 'I already have an account',
      'allFieldsRequired': 'All fields are required.',
      'home': 'Home',
      'regions': 'Regions',
      'places': 'Places',
      'ai': 'AI',
      'account': 'Account',
      'settings': 'Settings',
      'darkTheme': 'Dark theme',
      'savedLocally': 'Saved locally',
      'language': 'Language',
      'english': 'English',
      'russian': 'Russian',
      'kyrgyz': 'Kyrgyz',
      'music': 'Music',
      'mockSettingOnly': 'Mock setting only',
      'contactSupport': 'Contact support',
      'about': 'About',
      'aboutText':
          'Sacred KG is your companion for exploring the sacred places, petroglyphs and natural wonders of Kyrgyzstan. Discover ancestral routes, read living stories and plan your journeys with respect for the traditions of the land.',
      'favorites': 'Favorites',
      'favoritePlacesEmpty': 'Favorite places will appear here.',
      'myBookings': 'My bookings',
      'shortcuts': 'Shortcuts',
      'communityFeed': 'Community feed',
      'visitorTips': 'Visitor tips and local updates',
      'bookingRequests': 'Booking requests',
      'planAnotherVisit': 'Plan another visit',
      'themeLanguageMusic': 'Theme, language, music',
      'logout': 'Logout',
      'deleteAccountQuestion': 'Delete account?',
      'deleteAccountBody':
          'This clears the local mock session and saved settings on this device.',
      'cancel': 'Cancel',
      'delete': 'Delete',
      'deleteAccount': 'Delete account',
      'tours': 'Tours',
      'toursCaption': 'Routes from our travel agents',
      'needAccountTitle': 'Account required',
      'needAccountBody': 'To {action}, sign in or create an account.',
      'notLoggedIn': 'You are not signed in',
      'notLoggedInBody':
          'Sign in or register to save favourites, send requests, and leave comments.',
      'notifications': 'Notifications',
      'markAllRead': 'Mark all as read',
      'noNotifications':
          'No notifications yet. They will appear when someone replies to your comment or the admin decides on your request.',
      'comments': 'Comments',
      'commentsEmpty': 'No comments yet. Be the first.',
      'loginToComment': 'Sign in to leave comments',
      'yourComment': 'Your comment…',
      'yourReply': 'Your reply…',
      'send': 'Send',
      'reply': 'Reply',
      'edit': 'Edit',
      'report': 'Report',
    },
    'ru': {
      'appTitle': 'Sacred KG',
      'tagline': 'Священные маршруты Кыргызстана',
      'onboardingTitle':
          'Священные места, уважительные маршруты, живые истории.',
      'onboardingBody':
          'Изучайте Кыргызстан через демо-гидов, карточки регионов, местные публикации, заявки на посещение и ассистента для будущего AI-бэкенда.',
      'login': 'Войти',
      'createAccount': 'Регистрация',
      'continueAsGuest': 'Войти как гость',
      'welcomeBack': 'С возвращением',
      'loginSubtitle':
          'Войдите, чтобы планировать поездки по Кыргызстану и сохранять любимые места.',
      'loginGreeting': 'Добро пожаловать в Sacred KG',
      'logoutAction': 'Выйти',
      'languageMenu': 'Язык',
      'email': 'Email',
      'password': 'Пароль',
      'bothFieldsRequired': 'Введите email и пароль.',
      'invalidEmail': 'Некорректный email',
      'enterEmail': 'Введите email',
      'minSixChars': 'Минимум 6 символов',
      'passwordsDoNotMatch': 'Пароли не совпадают',
      'minTwoChars': 'Минимум 2 символа',
      'confirmRules': 'Подтвердите согласие с правилами',
      'emailAlreadyInUse': 'Этот email уже используется',
      'registration': 'Регистрация',
      'createTravellerAccount': 'Создайте аккаунт путешественника',
      'registerCaption':
          'Сохраняйте избранное, заявки и переписку с ИИ-гидами Апашкой и Аташкой.',
      'repeatPassword': 'Повторите пароль',
      'helperMinSix': 'Не короче 6 символов',
      'agreeRules':
          'Согласен с правилами посещения сакральных мест и обработкой персональных данных',
      'registerSubtitle': 'Для прототипа достаточно локального профиля.',
      'name': 'Имя',
      'register': 'Зарегистрироваться',
      'alreadyHaveAccount': 'У меня уже есть аккаунт',
      'allFieldsRequired': 'Заполните все поля.',
      'home': 'Главная',
      'regions': 'Регионы',
      'places': 'Места',
      'ai': 'AI',
      'account': 'Аккаунт',
      'settings': 'Настройки',
      'darkTheme': 'Темная тема',
      'savedLocally': 'Сохраняется локально',
      'language': 'Язык',
      'english': 'Английский',
      'russian': 'Русский',
      'kyrgyz': 'Кыргызский',
      'music': 'Музыка',
      'mockSettingOnly': 'Только демо-настройка',
      'contactSupport': 'Связаться с поддержкой',
      'about': 'О приложении',
      'aboutText':
          'Sacred KG — ваш проводник по священным местам, петроглифам и природным жемчужинам Кыргызстана. Открывайте маршруты предков, читайте живые истории и планируйте поездки с уважением к традициям этой земли.',
      'favorites': 'Избранное',
      'favoritePlacesEmpty': 'Избранные места появятся здесь.',
      'myBookings': 'Мои заявки',
      'shortcuts': 'Быстрые действия',
      'communityFeed': 'Лента сообщества',
      'visitorTips': 'Советы посетителей и местные новости',
      'bookingRequests': 'Заявки на посещение',
      'planAnotherVisit': 'Запланировать еще один визит',
      'themeLanguageMusic': 'Тема, язык, музыка',
      'logout': 'Выйти',
      'deleteAccountQuestion': 'Удалить аккаунт?',
      'deleteAccountBody':
          'Это очистит локальную демо-сессию и сохраненные настройки на устройстве.',
      'cancel': 'Отмена',
      'delete': 'Удалить',
      'deleteAccount': 'Удалить аккаунт',
      'tours': 'Туры',
      'toursCaption': 'Маршруты от наших турагентов',
      'needAccountTitle': 'Нужен аккаунт',
      'needAccountBody':
          'Чтобы {action}, войдите в аккаунт или зарегистрируйтесь.',
      'notLoggedIn': 'Вы не авторизованы',
      'notLoggedInBody':
          'Войдите или зарегистрируйтесь, чтобы сохранять избранное, '
          'отправлять заявки и оставлять комментарии.',
      'notifications': 'Уведомления',
      'markAllRead': 'Прочитать все',
      'noNotifications':
          'Пока нет уведомлений. Они появятся, когда кто-то ответит на ваш '
          'комментарий или админ решит по заявке.',
      'comments': 'Комментарии',
      'commentsEmpty': 'Комментариев пока нет. Будьте первым.',
      'loginToComment': 'Войдите, чтобы оставлять комментарии',
      'yourComment': 'Ваш комментарий…',
      'yourReply': 'Ваш ответ…',
      'send': 'Отправить',
      'reply': 'Ответить',
      'edit': 'Изменить',
      'report': 'Пожаловаться',
    },
    'ky': {
      'appTitle': 'Sacred KG',
      'tagline': 'Кыргызстандын ыйык маршруттары',
      'onboardingTitle': 'Ыйык жерлер, урматтуу маршруттар, жандуу окуялар.',
      'onboardingBody':
          'Кыргызстанды демо маданий гиддер, регион карталары, жергиликтүү билдирүүлөр, зыяратка өтүнмөлөр жана келечектеги AI бэкендге даяр жардамчы аркылуу изилдеңиз.',
      'login': 'Кирүү',
      'createAccount': 'Катталуу',
      'continueAsGuest': 'Конок катары кирүү',
      'welcomeBack': 'Кайра кош келиңиз',
      'loginSubtitle':
          'Кыргызстан боюнча саякатыңызды пландоо жана сүйүктүү жерлерди сактоо үчүн кириңиз.',
      'loginGreeting': 'Sacred KG тиркемесине кош келиңиз',
      'logoutAction': 'Чыгуу',
      'languageMenu': 'Тил',
      'email': 'Email',
      'password': 'Сырсөз',
      'bothFieldsRequired': 'Email жана сырсөздү жазыңыз.',
      'invalidEmail': 'Email туура эмес',
      'enterEmail': 'Email жазыңыз',
      'minSixChars': 'Кеминде 6 белги',
      'passwordsDoNotMatch': 'Сырсөздөр дал келбейт',
      'minTwoChars': 'Кеминде 2 белги',
      'confirmRules': 'Эрежелер менен макул экениңизди ырастаңыз',
      'emailAlreadyInUse': 'Бул email мурунтан колдонулууда',
      'registration': 'Катталуу',
      'createTravellerAccount': 'Саякатчы аккаунтун түзүңүз',
      'registerCaption':
          'Сүйүктүү жерлерди, өтүнмөлөрдү жана Апашка менен Аташка ИИ-гиддер менен баарлашууну сактаңыз.',
      'repeatPassword': 'Сырсөздү кайталаңыз',
      'helperMinSix': '6 белгиден кем эмес',
      'agreeRules':
          'Ыйык жерлерге баруу эрежелерине жана жеке маалыматтарды иштетүүгө макулмун',
      'registerSubtitle': 'Прототип үчүн локалдык профиль жетиштүү.',
      'name': 'Аты',
      'register': 'Катталуу',
      'alreadyHaveAccount': 'Менде аккаунт бар',
      'allFieldsRequired': 'Бардык талааларды толтуруңуз.',
      'home': 'Башкы',
      'regions': 'Региондор',
      'places': 'Жерлер',
      'ai': 'AI',
      'account': 'Аккаунт',
      'settings': 'Орнотуулар',
      'darkTheme': 'Караңгы тема',
      'savedLocally': 'Локалдык сакталат',
      'language': 'Тил',
      'english': 'Англисче',
      'russian': 'Орусча',
      'kyrgyz': 'Кыргызча',
      'music': 'Музыка',
      'mockSettingOnly': 'Демо жөндөө гана',
      'contactSupport': 'Колдоо кызматы менен байланыш',
      'about': 'Тиркеме тууралуу',
      'aboutText':
          'Sacred KG — Кыргызстандын ыйык жерлерине, петроглифтерине жана табият кооздуктарына болгон жол көрсөткүчүңүз. Ата-бабалардын жолдорун ачыңыз, жандуу окуяларды окуңуз жана бул жердин салтын урматтоо менен саякатыңызды пландаңыз.',
      'favorites': 'Тандалгандар',
      'favoritePlacesEmpty': 'Тандалган жерлер бул жерде көрүнөт.',
      'myBookings': 'Менин өтүнмөлөрүм',
      'shortcuts': 'Ыкчам өтүүлөр',
      'communityFeed': 'Коомчулук лентасы',
      'visitorTips': 'Зыяратчылардын кеңештери жана жергиликтүү жаңылыктар',
      'bookingRequests': 'Зыярат өтүнмөлөрү',
      'planAnotherVisit': 'Дагы бир зыярат пландаңыз',
      'themeLanguageMusic': 'Тема, тил, музыка',
      'logout': 'Чыгуу',
      'deleteAccountQuestion': 'Аккаунтту өчүрөсүзбү?',
      'deleteAccountBody':
          'Бул түзмөктөгү локалдык демо-сессияны жана сакталган жөндөөлөрдү тазалайт.',
      'cancel': 'Жокко чыгаруу',
      'delete': 'Өчүрүү',
      'deleteAccount': 'Аккаунтту өчүрүү',
      'tours': 'Турлар',
      'toursCaption': 'Турагенттерибиздин маршруттары',
      'needAccountTitle': 'Аккаунт керек',
      'needAccountBody':
          'Бул иш-аракетти {action} үчүн аккаунтуңузга кириңиз же катталыңыз.',
      'notLoggedIn': 'Аккаунтуңузга кирген жоксуз',
      'notLoggedInBody':
          'Сүйүктүүлөрдү сактоо, өтүнмө жөнөтүү жана комментарий калтыруу '
          'үчүн кириңиз же катталыңыз.',
      'notifications': 'Билдирүүлөр',
      'markAllRead': 'Баарын окулду деп белгилөө',
      'noNotifications':
          'Билдирүүлөр азырынча жок. Бирөө комментарийиңизге жооп бергенде '
          'же админ өтүнмөңүзгө чечим чыгарганда көрүнөт.',
      'comments': 'Комментарийлер',
      'commentsEmpty': 'Комментарийлер жок. Биринчи болуңуз.',
      'loginToComment': 'Комментарий калтыруу үчүн кириңиз',
      'yourComment': 'Сиздин комментарий…',
      'yourReply': 'Сиздин жооп…',
      'send': 'Жөнөтүү',
      'reply': 'Жооп берүү',
      'edit': 'Өзгөртүү',
      'report': 'Даттануу',
    },
  };

  String text(String key) {
    return _values[locale.languageCode]?[key] ?? _values['en']![key]!;
  }

  String get appTitle => text('appTitle');
  String get tagline => text('tagline');
  String get onboardingTitle => text('onboardingTitle');
  String get onboardingBody => text('onboardingBody');
  String get login => text('login');
  String get createAccount => text('createAccount');
  String get continueAsGuest => text('continueAsGuest');
  String get welcomeBack => text('welcomeBack');
  String get loginSubtitle => text('loginSubtitle');
  String get loginGreeting => text('loginGreeting');
  String get logoutAction => text('logoutAction');
  String get languageMenu => text('languageMenu');
  String get email => text('email');
  String get password => text('password');
  String get bothFieldsRequired => text('bothFieldsRequired');
  String get invalidEmail => text('invalidEmail');
  String get enterEmail => text('enterEmail');
  String get minSixChars => text('minSixChars');
  String get passwordsDoNotMatch => text('passwordsDoNotMatch');
  String get minTwoChars => text('minTwoChars');
  String get confirmRules => text('confirmRules');
  String get emailAlreadyInUse => text('emailAlreadyInUse');
  String get registration => text('registration');
  String get createTravellerAccount => text('createTravellerAccount');
  String get registerCaption => text('registerCaption');
  String get repeatPassword => text('repeatPassword');
  String get helperMinSix => text('helperMinSix');
  String get agreeRules => text('agreeRules');
  String get registerSubtitle => text('registerSubtitle');
  String get name => text('name');
  String get register => text('register');
  String get alreadyHaveAccount => text('alreadyHaveAccount');
  String get allFieldsRequired => text('allFieldsRequired');
  String get home => text('home');
  String get regions => text('regions');
  String get places => text('places');
  String get ai => text('ai');
  String get account => text('account');
  String get settings => text('settings');
  String get darkTheme => text('darkTheme');
  String get savedLocally => text('savedLocally');
  String get language => text('language');
  String get english => text('english');
  String get russian => text('russian');
  String get kyrgyz => text('kyrgyz');
  String get music => text('music');
  String get mockSettingOnly => text('mockSettingOnly');
  String get contactSupport => text('contactSupport');
  String get about => text('about');
  String get aboutText => text('aboutText');
  String get favorites => text('favorites');
  String get favoritePlacesEmpty => text('favoritePlacesEmpty');
  String get myBookings => text('myBookings');
  String get shortcuts => text('shortcuts');
  String get communityFeed => text('communityFeed');
  String get visitorTips => text('visitorTips');
  String get bookingRequests => text('bookingRequests');
  String get planAnotherVisit => text('planAnotherVisit');
  String get themeLanguageMusic => text('themeLanguageMusic');
  String get logout => text('logout');
  String get deleteAccountQuestion => text('deleteAccountQuestion');
  String get deleteAccountBody => text('deleteAccountBody');
  String get cancel => text('cancel');
  String get delete => text('delete');
  String get deleteAccount => text('deleteAccount');
  String get tours => text('tours');
  String get toursCaption => text('toursCaption');
  String get needAccountTitle => text('needAccountTitle');
  String needAccountBody(String action) =>
      text('needAccountBody').replaceAll('{action}', action);
  String get notLoggedIn => text('notLoggedIn');
  String get notLoggedInBody => text('notLoggedInBody');
  String get notifications => text('notifications');
  String get markAllRead => text('markAllRead');
  String get noNotifications => text('noNotifications');
  String get comments => text('comments');
  String get commentsEmpty => text('commentsEmpty');
  String get loginToComment => text('loginToComment');
  String get yourComment => text('yourComment');
  String get yourReply => text('yourReply');
  String get send => text('send');
  String get reply => text('reply');
  String get edit => text('edit');
  String get report => text('report');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(Locale(normalizeLanguageCode(locale.languageCode)));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

String normalizeLanguageCode(String? value) {
  switch (value?.toLowerCase()) {
    case 'en':
      return 'en';
    case 'ru':
      return 'ru';
    case 'kg':
    case 'ky':
      return 'ky';
    default:
      return 'ky';
  }
}

String languageLabel(BuildContext context, String code) {
  final l10n = context.l10n;
  switch (code) {
    case 'ru':
      return l10n.russian;
    case 'ky':
      return l10n.kyrgyz;
    default:
      return l10n.english;
  }
}
