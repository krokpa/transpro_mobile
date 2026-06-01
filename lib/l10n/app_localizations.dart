import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

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
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'TransPro CI'**
  String get appName;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @see.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get see;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get error;

  /// No description provided for @errorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your connection.'**
  String get errorNetwork;

  /// No description provided for @errorServer.
  ///
  /// In en, this message translates to:
  /// **'Server error. Please try again.'**
  String get errorServer;

  /// No description provided for @errorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get errorUnknown;

  /// No description provided for @successSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully'**
  String get successSaved;

  /// No description provided for @successDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted successfully'**
  String get successDeleted;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete?'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get confirmDeleteBody;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get optional;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get notAvailable;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to your TransPro account'**
  String get loginSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'example@email.com'**
  String get emailHint;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Your password'**
  String get passwordHint;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginButton;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordLink;

  /// No description provided for @noAccountText.
  ///
  /// In en, this message translates to:
  /// **'No account yet?'**
  String get noAccountText;

  /// No description provided for @registerLink.
  ///
  /// In en, this message translates to:
  /// **'Create one'**
  String get registerLink;

  /// No description provided for @loginError.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password'**
  String get loginError;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join TransPro CI'**
  String get registerSubtitle;

  /// No description provided for @firstNameLabel.
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get firstNameLabel;

  /// No description provided for @firstNameHint.
  ///
  /// In en, this message translates to:
  /// **'John'**
  String get firstNameHint;

  /// No description provided for @lastNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get lastNameLabel;

  /// No description provided for @lastNameHint.
  ///
  /// In en, this message translates to:
  /// **'Doe'**
  String get lastNameHint;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneLabel;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'+225 07 00 00 00 00'**
  String get phoneHint;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordLabel;

  /// No description provided for @confirmPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Repeat your password'**
  String get confirmPasswordHint;

  /// No description provided for @passwordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordMismatch;

  /// No description provided for @registerButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerButton;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @loginLink.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get loginLink;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we\'ll send you a reset link'**
  String get forgotPasswordSubtitle;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get backToLogin;

  /// No description provided for @resetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Email sent! Check your inbox.'**
  String get resetEmailSent;

  /// No description provided for @pinLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'PIN Code'**
  String get pinLoginTitle;

  /// No description provided for @pinLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your 4-digit code'**
  String get pinLoginSubtitle;

  /// No description provided for @pinLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Account locked'**
  String get pinLockedTitle;

  /// No description provided for @pinLockedError.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Use your password.'**
  String get pinLockedError;

  /// No description provided for @pinWrongError.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN ({attempts}/{max} attempts)'**
  String pinWrongError(int attempts, int max);

  /// No description provided for @pinSignInAnother.
  ///
  /// In en, this message translates to:
  /// **'Sign in another way'**
  String get pinSignInAnother;

  /// No description provided for @pinSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a PIN'**
  String get pinSetupTitle;

  /// No description provided for @pinSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This PIN will secure access to the app'**
  String get pinSetupSubtitle;

  /// No description provided for @pinConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your PIN'**
  String get pinConfirmTitle;

  /// No description provided for @pinConfirmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the same 4-digit code again'**
  String get pinConfirmSubtitle;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match. Please try again.'**
  String get pinMismatch;

  /// No description provided for @pinSetupBiometricLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable biometrics'**
  String get pinSetupBiometricLabel;

  /// No description provided for @pinSetupBiometricSub.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint / Face ID'**
  String get pinSetupBiometricSub;

  /// No description provided for @pinRetry.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get pinRetry;

  /// No description provided for @biometricReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock TransPro with your biometrics'**
  String get biometricReason;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingStart.
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingStart;

  /// No description provided for @onboarding1Title.
  ///
  /// In en, this message translates to:
  /// **'Find your trip'**
  String get onboarding1Title;

  /// No description provided for @onboarding1Body.
  ///
  /// In en, this message translates to:
  /// **'Search among hundreds of available trips across Côte d\'Ivoire. Choose your date, origin, and destination.'**
  String get onboarding1Body;

  /// No description provided for @onboarding2Title.
  ///
  /// In en, this message translates to:
  /// **'Choose your seat'**
  String get onboarding2Title;

  /// No description provided for @onboarding2Body.
  ///
  /// In en, this message translates to:
  /// **'Pick your spot in the véhicule according to your preferences. Window, aisle, VIP — all at your fingertips.'**
  String get onboarding2Body;

  /// No description provided for @onboarding3Title.
  ///
  /// In en, this message translates to:
  /// **'Pay securely'**
  String get onboarding3Title;

  /// No description provided for @onboarding3Body.
  ///
  /// In en, this message translates to:
  /// **'Pay with Orange Money, MTN MoMo, Wave, or cash. Your QR ticket is available offline for boarding.'**
  String get onboarding3Body;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// No description provided for @navTickets.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get navTickets;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navDepartures.
  ///
  /// In en, this message translates to:
  /// **'Departures'**
  String get navDepartures;

  /// No description provided for @navScanner.
  ///
  /// In en, this message translates to:
  /// **'Scanner'**
  String get navScanner;

  /// No description provided for @navGuichet.
  ///
  /// In en, this message translates to:
  /// **'Counter'**
  String get navGuichet;

  /// No description provided for @navCaisse.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get navCaisse;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get navTrips;

  /// No description provided for @navFleet.
  ///
  /// In en, this message translates to:
  /// **'Fleet'**
  String get navFleet;

  /// No description provided for @navRoutes.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get navRoutes;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance & Security'**
  String get settingsAppearance;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsBiometric.
  ///
  /// In en, this message translates to:
  /// **'Biometrics'**
  String get settingsBiometric;

  /// No description provided for @settingsBiometricSub.
  ///
  /// In en, this message translates to:
  /// **'Fingerprint / Face ID'**
  String get settingsBiometricSub;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get settingsEditProfile;

  /// No description provided for @settingsChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get settingsChangePassword;

  /// No description provided for @settingsLogout.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsLogout;

  /// No description provided for @settingsLogoutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsLogoutConfirm;

  /// No description provided for @settingsLogoutBody.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get settingsLogoutBody;

  /// No description provided for @settingsLogoutCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsLogoutCancel;

  /// No description provided for @settingsQuickNav.
  ///
  /// In en, this message translates to:
  /// **'Quick navigation'**
  String get settingsQuickNav;

  /// No description provided for @passengerRole.
  ///
  /// In en, this message translates to:
  /// **'Passenger'**
  String get passengerRole;

  /// No description provided for @agentRole.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get agentRole;

  /// No description provided for @ownerRole.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get ownerRole;

  /// No description provided for @adminRole.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get adminRole;

  /// No description provided for @homeGreetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGreetingMorning;

  /// No description provided for @homeGreetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGreetingAfternoon;

  /// No description provided for @homeGreetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingEvening;

  /// No description provided for @homeSearchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Where are you going?'**
  String get homeSearchPlaceholder;

  /// No description provided for @homeRecentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get homeRecentSearches;

  /// No description provided for @homePopularRoutes.
  ///
  /// In en, this message translates to:
  /// **'Popular routes'**
  String get homePopularRoutes;

  /// No description provided for @searchFromCity.
  ///
  /// In en, this message translates to:
  /// **'Departure city'**
  String get searchFromCity;

  /// No description provided for @searchToCity.
  ///
  /// In en, this message translates to:
  /// **'Arrival city'**
  String get searchToCity;

  /// No description provided for @searchSelectDate.
  ///
  /// In en, this message translates to:
  /// **'Select a date'**
  String get searchSelectDate;

  /// No description provided for @searchPassengerCount.
  ///
  /// In en, this message translates to:
  /// **'Number of passengers'**
  String get searchPassengerCount;

  /// No description provided for @searchButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Search trips'**
  String get searchButtonLabel;

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'Available trips'**
  String get searchResults;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No trips found for this route'**
  String get searchNoResults;

  /// No description provided for @searchTryOther.
  ///
  /// In en, this message translates to:
  /// **'Try other dates or cities'**
  String get searchTryOther;

  /// No description provided for @searchSeat.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{seat} other{seats}}'**
  String searchSeat(int count);

  /// No description provided for @tripDeparture.
  ///
  /// In en, this message translates to:
  /// **'Departure'**
  String get tripDeparture;

  /// No description provided for @tripArrival.
  ///
  /// In en, this message translates to:
  /// **'Arrival'**
  String get tripArrival;

  /// No description provided for @tripDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get tripDuration;

  /// No description provided for @tripAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get tripAvailable;

  /// No description provided for @tripClass.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get tripClass;

  /// No description provided for @tripClassStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get tripClassStandard;

  /// No description provided for @tripClassVip.
  ///
  /// In en, this message translates to:
  /// **'VIP'**
  String get tripClassVip;

  /// No description provided for @tripClassExpress.
  ///
  /// In en, this message translates to:
  /// **'Express'**
  String get tripClassExpress;

  /// No description provided for @tripStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get tripStatusScheduled;

  /// No description provided for @tripStatusBoarding.
  ///
  /// In en, this message translates to:
  /// **'Boarding'**
  String get tripStatusBoarding;

  /// No description provided for @tripStatusDeparted.
  ///
  /// In en, this message translates to:
  /// **'Departed'**
  String get tripStatusDeparted;

  /// No description provided for @tripStatusArrived.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get tripStatusArrived;

  /// No description provided for @tripStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get tripStatusCancelled;

  /// No description provided for @tripBook.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get tripBook;

  /// No description provided for @tripSelectSeat.
  ///
  /// In en, this message translates to:
  /// **'Select a seat'**
  String get tripSelectSeat;

  /// No description provided for @tripSeatOccupied.
  ///
  /// In en, this message translates to:
  /// **'Occupied'**
  String get tripSeatOccupied;

  /// No description provided for @tripSeatAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get tripSeatAvailable;

  /// No description provided for @tripSeatBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get tripSeatBlocked;

  /// No description provided for @tripSeatYours.
  ///
  /// In en, this message translates to:
  /// **'Your seat'**
  String get tripSeatYours;

  /// No description provided for @tripConfirmBooking.
  ///
  /// In en, this message translates to:
  /// **'Confirm booking'**
  String get tripConfirmBooking;

  /// No description provided for @tripPassengerInfo.
  ///
  /// In en, this message translates to:
  /// **'Passenger information'**
  String get tripPassengerInfo;

  /// No description provided for @bookingsTitle.
  ///
  /// In en, this message translates to:
  /// **'My tickets'**
  String get bookingsTitle;

  /// No description provided for @bookingsNoBookings.
  ///
  /// In en, this message translates to:
  /// **'No tickets yet'**
  String get bookingsNoBookings;

  /// No description provided for @bookingsNoBookingsSub.
  ///
  /// In en, this message translates to:
  /// **'Your booked trips will appear here'**
  String get bookingsNoBookingsSub;

  /// No description provided for @bookingStatusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get bookingStatusConfirmed;

  /// No description provided for @bookingStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get bookingStatusPending;

  /// No description provided for @bookingStatusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get bookingStatusUpcoming;

  /// No description provided for @bookingStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get bookingStatusCompleted;

  /// No description provided for @bookingStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get bookingStatusCancelled;

  /// No description provided for @bookingRef.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get bookingRef;

  /// No description provided for @bookingSeats.
  ///
  /// In en, this message translates to:
  /// **'Seats'**
  String get bookingSeats;

  /// No description provided for @bookingTotal.
  ///
  /// In en, this message translates to:
  /// **'Total paid'**
  String get bookingTotal;

  /// No description provided for @bookingDownload.
  ///
  /// In en, this message translates to:
  /// **'Download ticket'**
  String get bookingDownload;

  /// No description provided for @bookingShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get bookingShare;

  /// No description provided for @bookingCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel booking'**
  String get bookingCancel;

  /// No description provided for @bookingCancelConfirm.
  ///
  /// In en, this message translates to:
  /// **'Cancel this booking?'**
  String get bookingCancelConfirm;

  /// No description provided for @bookingRateTrip.
  ///
  /// In en, this message translates to:
  /// **'Rate this trip'**
  String get bookingRateTrip;

  /// No description provided for @bookingRateTitle.
  ///
  /// In en, this message translates to:
  /// **'How was your trip?'**
  String get bookingRateTitle;

  /// No description provided for @bookingRateComment.
  ///
  /// In en, this message translates to:
  /// **'Your comment (optional)'**
  String get bookingRateComment;

  /// No description provided for @bookingPayNow.
  ///
  /// In en, this message translates to:
  /// **'Pay now'**
  String get bookingPayNow;

  /// No description provided for @bookingPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get bookingPaid;

  /// No description provided for @bookingPending.
  ///
  /// In en, this message translates to:
  /// **'Pending payment'**
  String get bookingPending;

  /// No description provided for @bookingSeatNumber.
  ///
  /// In en, this message translates to:
  /// **'Seat {seat}'**
  String bookingSeatNumber(String seat);

  /// No description provided for @paymentTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get paymentTitle;

  /// No description provided for @paymentChooseMethod.
  ///
  /// In en, this message translates to:
  /// **'Choose a payment method'**
  String get paymentChooseMethod;

  /// No description provided for @paymentProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing payment…'**
  String get paymentProcessing;

  /// No description provided for @paymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment successful!'**
  String get paymentSuccess;

  /// No description provided for @paymentSuccessSub.
  ///
  /// In en, this message translates to:
  /// **'Your ticket has been confirmed.'**
  String get paymentSuccessSub;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment failed'**
  String get paymentFailed;

  /// No description provided for @paymentFailedSub.
  ///
  /// In en, this message translates to:
  /// **'Please try again or use another method.'**
  String get paymentFailedSub;

  /// No description provided for @paymentGoToTicket.
  ///
  /// In en, this message translates to:
  /// **'View my ticket'**
  String get paymentGoToTicket;

  /// No description provided for @paymentRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get paymentRetry;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket scanner'**
  String get scanTitle;

  /// No description provided for @scanInstruction.
  ///
  /// In en, this message translates to:
  /// **'Position the QR code in the frame'**
  String get scanInstruction;

  /// No description provided for @scanSuccess.
  ///
  /// In en, this message translates to:
  /// **'Ticket validated'**
  String get scanSuccess;

  /// No description provided for @scanInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid or unrecognised ticket'**
  String get scanInvalid;

  /// No description provided for @scanAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'Ticket already validated'**
  String get scanAlreadyUsed;

  /// No description provided for @scanOfflineBadge.
  ///
  /// In en, this message translates to:
  /// **'Offline — will sync on reconnection'**
  String get scanOfflineBadge;

  /// No description provided for @scanOfflineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline mode active'**
  String get scanOfflineMode;

  /// No description provided for @scanResult.
  ///
  /// In en, this message translates to:
  /// **'Scan result'**
  String get scanResult;

  /// No description provided for @scanSeatLabel.
  ///
  /// In en, this message translates to:
  /// **'Seat'**
  String get scanSeatLabel;

  /// No description provided for @scanTripLabel.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get scanTripLabel;

  /// No description provided for @scanPassengerLabel.
  ///
  /// In en, this message translates to:
  /// **'Passenger'**
  String get scanPassengerLabel;

  /// No description provided for @scanScanAnother.
  ///
  /// In en, this message translates to:
  /// **'Scan another'**
  String get scanScanAnother;

  /// No description provided for @departuresTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s departures'**
  String get departuresTitle;

  /// No description provided for @departuresNone.
  ///
  /// In en, this message translates to:
  /// **'No scheduled departures'**
  String get departuresNone;

  /// No description provided for @departureSeeManifest.
  ///
  /// In en, this message translates to:
  /// **'Manifest'**
  String get departureSeeManifest;

  /// No description provided for @departureDownloadOffline.
  ///
  /// In en, this message translates to:
  /// **'Download offline'**
  String get departureDownloadOffline;

  /// No description provided for @departureOfflineReady.
  ///
  /// In en, this message translates to:
  /// **'Offline ready'**
  String get departureOfflineReady;

  /// No description provided for @departureCountdown.
  ///
  /// In en, this message translates to:
  /// **'in {time}'**
  String departureCountdown(String time);

  /// No description provided for @manifestTitle.
  ///
  /// In en, this message translates to:
  /// **'Passenger list'**
  String get manifestTitle;

  /// No description provided for @manifestScanned.
  ///
  /// In en, this message translates to:
  /// **'Scanned'**
  String get manifestScanned;

  /// No description provided for @manifestNotScanned.
  ///
  /// In en, this message translates to:
  /// **'Not scanned'**
  String get manifestNotScanned;

  /// No description provided for @manifestMissing.
  ///
  /// In en, this message translates to:
  /// **'Missing passengers'**
  String get manifestMissing;

  /// No description provided for @manifestTotal.
  ///
  /// In en, this message translates to:
  /// **'{scanned}/{total} passengers'**
  String manifestTotal(int scanned, int total);

  /// No description provided for @manifestCallPassenger.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get manifestCallPassenger;

  /// No description provided for @quickSaleTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick sale'**
  String get quickSaleTitle;

  /// No description provided for @quickSaleSelectTrip.
  ///
  /// In en, this message translates to:
  /// **'Select a departure'**
  String get quickSaleSelectTrip;

  /// No description provided for @quickSaleQty.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quickSaleQty;

  /// No description provided for @quickSalePayMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get quickSalePayMethod;

  /// No description provided for @quickSaleCollect.
  ///
  /// In en, this message translates to:
  /// **'Collect {amount} F'**
  String quickSaleCollect(String amount);

  /// No description provided for @quickSaleSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment received'**
  String get quickSaleSuccess;

  /// No description provided for @quickSaleNew.
  ///
  /// In en, this message translates to:
  /// **'New sale'**
  String get quickSaleNew;

  /// No description provided for @quickSaleBackToDepartures.
  ///
  /// In en, this message translates to:
  /// **'Back to departures'**
  String get quickSaleBackToDepartures;

  /// No description provided for @guichetTitle.
  ///
  /// In en, this message translates to:
  /// **'Ticket counter'**
  String get guichetTitle;

  /// No description provided for @caisseTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily cashier'**
  String get caisseTitle;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @dashboardRevenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get dashboardRevenue;

  /// No description provided for @dashboardTrips.
  ///
  /// In en, this message translates to:
  /// **'Trips'**
  String get dashboardTrips;

  /// No description provided for @dashboardOccupancy.
  ///
  /// In en, this message translates to:
  /// **'Occupancy'**
  String get dashboardOccupancy;

  /// No description provided for @dashboardPassengers.
  ///
  /// In en, this message translates to:
  /// **'Passengers'**
  String get dashboardPassengers;

  /// No description provided for @dashboardPeriod7d.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get dashboardPeriod7d;

  /// No description provided for @dashboardPeriod30d.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get dashboardPeriod30d;

  /// No description provided for @dashboardPeriod90d.
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get dashboardPeriod90d;

  /// No description provided for @dashboardTopRoutes.
  ///
  /// In en, this message translates to:
  /// **'Top routes'**
  String get dashboardTopRoutes;

  /// No description provided for @dashboardFillRate.
  ///
  /// In en, this message translates to:
  /// **'Fill rate by route'**
  String get dashboardFillRate;

  /// No description provided for @fleetTitle.
  ///
  /// In en, this message translates to:
  /// **'Fleet'**
  String get fleetTitle;

  /// No description provided for @fleetAddVehicle.
  ///
  /// In en, this message translates to:
  /// **'Add vehicle'**
  String get fleetAddVehicle;

  /// No description provided for @fleetNoVehicles.
  ///
  /// In en, this message translates to:
  /// **'No vehicles registered'**
  String get fleetNoVehicles;

  /// No description provided for @fleetPlate.
  ///
  /// In en, this message translates to:
  /// **'Plate'**
  String get fleetPlate;

  /// No description provided for @fleetBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get fleetBrand;

  /// No description provided for @fleetModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get fleetModel;

  /// No description provided for @fleetYear.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get fleetYear;

  /// No description provided for @fleetCapacity.
  ///
  /// In en, this message translates to:
  /// **'Capacity'**
  String get fleetCapacity;

  /// No description provided for @fleetStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get fleetStatusActive;

  /// No description provided for @fleetStatusInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get fleetStatusInactive;

  /// No description provided for @fleetStatusMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get fleetStatusMaintenance;

  /// No description provided for @fleetFuelTab.
  ///
  /// In en, this message translates to:
  /// **'Fuel'**
  String get fleetFuelTab;

  /// No description provided for @fleetMaintenanceTab.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get fleetMaintenanceTab;

  /// No description provided for @fleetNoFuelLogs.
  ///
  /// In en, this message translates to:
  /// **'No fuel logs'**
  String get fleetNoFuelLogs;

  /// No description provided for @fleetNoMaintenanceLogs.
  ///
  /// In en, this message translates to:
  /// **'No maintenance logs'**
  String get fleetNoMaintenanceLogs;

  /// No description provided for @fleetAddFuel.
  ///
  /// In en, this message translates to:
  /// **'Log refuel'**
  String get fleetAddFuel;

  /// No description provided for @fleetAddMaintenance.
  ///
  /// In en, this message translates to:
  /// **'Log service'**
  String get fleetAddMaintenance;

  /// No description provided for @fleetNextService.
  ///
  /// In en, this message translates to:
  /// **'Next service'**
  String get fleetNextService;

  /// No description provided for @driversTitle.
  ///
  /// In en, this message translates to:
  /// **'Drivers'**
  String get driversTitle;

  /// No description provided for @driversAddDriver.
  ///
  /// In en, this message translates to:
  /// **'Add driver'**
  String get driversAddDriver;

  /// No description provided for @driversNoDrivers.
  ///
  /// In en, this message translates to:
  /// **'No drivers registered'**
  String get driversNoDrivers;

  /// No description provided for @driverLicenseExpiry.
  ///
  /// In en, this message translates to:
  /// **'License expiry'**
  String get driverLicenseExpiry;

  /// No description provided for @driverLicenseExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get driverLicenseExpired;

  /// No description provided for @driverLicenseExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get driverLicenseExpiringSoon;

  /// No description provided for @driverAvailable.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get driverAvailable;

  /// No description provided for @driverUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get driverUnavailable;

  /// No description provided for @driverScheduleTab.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get driverScheduleTab;

  /// No description provided for @driverAbsencesTab.
  ///
  /// In en, this message translates to:
  /// **'Absences'**
  String get driverAbsencesTab;

  /// No description provided for @driverEvaluationsTab.
  ///
  /// In en, this message translates to:
  /// **'Evaluations'**
  String get driverEvaluationsTab;

  /// No description provided for @driverNoTrips.
  ///
  /// In en, this message translates to:
  /// **'No trips this month'**
  String get driverNoTrips;

  /// No description provided for @driverNoAbsences.
  ///
  /// In en, this message translates to:
  /// **'No absences recorded'**
  String get driverNoAbsences;

  /// No description provided for @driverNoEvaluations.
  ///
  /// In en, this message translates to:
  /// **'No evaluations yet'**
  String get driverNoEvaluations;

  /// No description provided for @driverAddAbsence.
  ///
  /// In en, this message translates to:
  /// **'Record absence'**
  String get driverAddAbsence;

  /// No description provided for @driverAddEvaluation.
  ///
  /// In en, this message translates to:
  /// **'Evaluate'**
  String get driverAddEvaluation;

  /// No description provided for @driverAbsenceLeave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get driverAbsenceLeave;

  /// No description provided for @driverAbsenceSick.
  ///
  /// In en, this message translates to:
  /// **'Sick'**
  String get driverAbsenceSick;

  /// No description provided for @driverAbsenceOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get driverAbsenceOther;

  /// No description provided for @driverAbsenceApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get driverAbsenceApprove;

  /// No description provided for @driverAbsenceApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get driverAbsenceApproved;

  /// No description provided for @driverAbsencePending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get driverAbsencePending;

  /// No description provided for @driverAbsenceReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get driverAbsenceReason;

  /// No description provided for @driverEvalOverall.
  ///
  /// In en, this message translates to:
  /// **'Overall'**
  String get driverEvalOverall;

  /// No description provided for @driverEvalPunctuality.
  ///
  /// In en, this message translates to:
  /// **'Punctuality'**
  String get driverEvalPunctuality;

  /// No description provided for @driverEvalSafety.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get driverEvalSafety;

  /// No description provided for @driverEvalService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get driverEvalService;

  /// No description provided for @driverEvalComment.
  ///
  /// In en, this message translates to:
  /// **'Comment (optional)'**
  String get driverEvalComment;

  /// No description provided for @driverEvalAverageRating.
  ///
  /// In en, this message translates to:
  /// **'Average rating'**
  String get driverEvalAverageRating;

  /// No description provided for @routesTitle.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get routesTitle;

  /// No description provided for @routesNoRoutes.
  ///
  /// In en, this message translates to:
  /// **'No routes defined'**
  String get routesNoRoutes;

  /// No description provided for @routesAddRoute.
  ///
  /// In en, this message translates to:
  /// **'Add route'**
  String get routesAddRoute;

  /// No description provided for @schedulesTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedules'**
  String get schedulesTitle;

  /// No description provided for @staffTitle.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get staffTitle;

  /// No description provided for @stationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stations'**
  String get stationsTitle;

  /// No description provided for @reportsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reportsTitle;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @notificationsNone.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notificationsNone;

  /// No description provided for @notificationsMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get notificationsMarkAllRead;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'My profile'**
  String get profileTitle;

  /// No description provided for @profilePersonalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal information'**
  String get profilePersonalInfo;

  /// No description provided for @profileCompany.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get profileCompany;

  /// No description provided for @languageAuto.
  ///
  /// In en, this message translates to:
  /// **'System (auto)'**
  String get languageAuto;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Your trip in hand'**
  String get appTagline;

  /// No description provided for @loginOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get loginOr;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @validationEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get validationEmailInvalid;

  /// No description provided for @validationPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid number (min. 8 digits)'**
  String get validationPhoneInvalid;

  /// No description provided for @validationPasswordMin.
  ///
  /// In en, this message translates to:
  /// **'Minimum 8 characters'**
  String get validationPasswordMin;

  /// No description provided for @registerFormTitle.
  ///
  /// In en, this message translates to:
  /// **'Your information'**
  String get registerFormTitle;

  /// No description provided for @registerFormSub.
  ///
  /// In en, this message translates to:
  /// **'Fill all fields to continue'**
  String get registerFormSub;

  /// No description provided for @registerTerms.
  ///
  /// In en, this message translates to:
  /// **'By creating an account, you agree to our terms of use.'**
  String get registerTerms;

  /// No description provided for @registerPassengerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a passenger account'**
  String get registerPassengerSubtitle;

  /// No description provided for @forgotSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Email sent!'**
  String get forgotSentTitle;

  /// No description provided for @forgotSentBody.
  ///
  /// In en, this message translates to:
  /// **'If this email is registered, you\'ll receive a reset link.'**
  String get forgotSentBody;

  /// No description provided for @forgotSpamNote.
  ///
  /// In en, this message translates to:
  /// **'Also check your spam folder.'**
  String get forgotSpamNote;

  /// No description provided for @forgotInstruction.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address to receive a reset link.'**
  String get forgotInstruction;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hello, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeWhereToGo.
  ///
  /// In en, this message translates to:
  /// **'Where are you going?'**
  String get homeWhereToGo;

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for a trip…'**
  String get homeSearchHint;

  /// No description provided for @homeUpcomingDepartures.
  ///
  /// In en, this message translates to:
  /// **'Upcoming departures'**
  String get homeUpcomingDepartures;

  /// No description provided for @homeNextDeparture.
  ///
  /// In en, this message translates to:
  /// **'Next departure'**
  String get homeNextDeparture;

  /// No description provided for @homeAwaitingPayment.
  ///
  /// In en, this message translates to:
  /// **'Awaiting payment'**
  String get homeAwaitingPayment;

  /// No description provided for @homeViewTickets.
  ///
  /// In en, this message translates to:
  /// **'View tickets'**
  String get homeViewTickets;

  /// No description provided for @homeNoTripsTitle.
  ///
  /// In en, this message translates to:
  /// **'No trips available'**
  String get homeNoTripsTitle;

  /// No description provided for @homeNoTripsSub.
  ///
  /// In en, this message translates to:
  /// **'Come back later or try different criteria.'**
  String get homeNoTripsSub;

  /// No description provided for @homeAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get homeAlerts;

  /// No description provided for @homeBoardingStatus.
  ///
  /// In en, this message translates to:
  /// **'Boarding'**
  String get homeBoardingStatus;

  /// No description provided for @homeBookNow.
  ///
  /// In en, this message translates to:
  /// **'Book'**
  String get homeBookNow;

  /// No description provided for @bookingsOfflineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline mode — cached tickets'**
  String get bookingsOfflineMode;

  /// No description provided for @bookingsPendingPay.
  ///
  /// In en, this message translates to:
  /// **'Payment pending — tap to pay'**
  String get bookingsPendingPay;

  /// No description provided for @bookingsTrackLive.
  ///
  /// In en, this message translates to:
  /// **'Track live'**
  String get bookingsTrackLive;

  /// No description provided for @bookingsTrackBoarding.
  ///
  /// In en, this message translates to:
  /// **'Boarding — Track'**
  String get bookingsTrackBoarding;

  /// No description provided for @bookingsSearchTrips.
  ///
  /// In en, this message translates to:
  /// **'Search for a trip'**
  String get bookingsSearchTrips;

  /// No description provided for @paymentConfirming.
  ///
  /// In en, this message translates to:
  /// **'Confirming payment…'**
  String get paymentConfirming;

  /// No description provided for @paymentPleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait a moment.'**
  String get paymentPleaseWait;

  /// No description provided for @paymentTripLabel.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get paymentTripLabel;

  /// No description provided for @paymentSeatsLabel.
  ///
  /// In en, this message translates to:
  /// **'Seats'**
  String get paymentSeatsLabel;

  /// No description provided for @paymentTotalPaidLabel.
  ///
  /// In en, this message translates to:
  /// **'Total paid'**
  String get paymentTotalPaidLabel;

  /// No description provided for @paymentTicketReady.
  ///
  /// In en, this message translates to:
  /// **'Your ticket is confirmed and ready.'**
  String get paymentTicketReady;

  /// No description provided for @paymentGoHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get paymentGoHome;

  /// No description provided for @paymentLoadingLabel.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get paymentLoadingLabel;

  /// No description provided for @paymentErrorMsg.
  ///
  /// In en, this message translates to:
  /// **'Your payment was unsuccessful.\nNo amount was charged.'**
  String get paymentErrorMsg;

  /// No description provided for @paymentGotoStationHint.
  ///
  /// In en, this message translates to:
  /// **'If the issue persists, go to the station.'**
  String get paymentGotoStationHint;

  /// No description provided for @departureQuickSale.
  ///
  /// In en, this message translates to:
  /// **'Quick sale'**
  String get departureQuickSale;

  /// No description provided for @departuresNoneToday.
  ///
  /// In en, this message translates to:
  /// **'No departures today'**
  String get departuresNoneToday;

  /// No description provided for @departureDriverMode.
  ///
  /// In en, this message translates to:
  /// **'Driver mode'**
  String get departureDriverMode;

  /// No description provided for @departureGpsSharingLabel.
  ///
  /// In en, this message translates to:
  /// **'Sharing location live'**
  String get departureGpsSharingLabel;

  /// No description provided for @departureGpsStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get departureGpsStop;

  /// No description provided for @departureSharePosition.
  ///
  /// In en, this message translates to:
  /// **'Share your position with passengers'**
  String get departureSharePosition;

  /// No description provided for @departurePaxSuffix.
  ///
  /// In en, this message translates to:
  /// **'passengers'**
  String get departurePaxSuffix;

  /// No description provided for @departureManifestBtn.
  ///
  /// In en, this message translates to:
  /// **'Manifest · {count} pax'**
  String departureManifestBtn(int count);

  /// No description provided for @scanValidatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Ticket validated ✓'**
  String get scanValidatedLabel;

  /// No description provided for @scanRejectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Ticket rejected'**
  String get scanRejectedLabel;

  /// No description provided for @scanAlreadyBoarded.
  ///
  /// In en, this message translates to:
  /// **'Ticket already boarded'**
  String get scanAlreadyBoarded;

  /// No description provided for @scanVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying…'**
  String get scanVerifying;

  /// No description provided for @scanCenterQr.
  ///
  /// In en, this message translates to:
  /// **'Center the QR code in the frame'**
  String get scanCenterQr;

  /// No description provided for @scanAgentHeader.
  ///
  /// In en, this message translates to:
  /// **'Agent · Scanner'**
  String get scanAgentHeader;

  /// No description provided for @scanNextTicket.
  ///
  /// In en, this message translates to:
  /// **'Scan next'**
  String get scanNextTicket;

  /// No description provided for @scanTryAgain2.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get scanTryAgain2;

  /// No description provided for @scanOfflineSyncNote.
  ///
  /// In en, this message translates to:
  /// **'Offline · will sync'**
  String get scanOfflineSyncNote;

  /// No description provided for @guichetSectionRoute.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get guichetSectionRoute;

  /// No description provided for @guichetSectionDayTrips.
  ///
  /// In en, this message translates to:
  /// **'Today\'s trips'**
  String get guichetSectionDayTrips;

  /// No description provided for @guichetSectionSeats.
  ///
  /// In en, this message translates to:
  /// **'Seats'**
  String get guichetSectionSeats;

  /// No description provided for @guichetSectionPax.
  ///
  /// In en, this message translates to:
  /// **'Passengers'**
  String get guichetSectionPax;

  /// No description provided for @guichetChooseSeats.
  ///
  /// In en, this message translates to:
  /// **'Choose seats'**
  String get guichetChooseSeats;

  /// No description provided for @guichetModify.
  ///
  /// In en, this message translates to:
  /// **'Modify'**
  String get guichetModify;

  /// No description provided for @guichetNoTripsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No trips available'**
  String get guichetNoTripsAvailable;

  /// No description provided for @guichetSaleSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sale successful!'**
  String get guichetSaleSuccess;

  /// No description provided for @guichetNewSale.
  ///
  /// In en, this message translates to:
  /// **'New sale'**
  String get guichetNewSale;

  /// No description provided for @guichetCollectBtn.
  ///
  /// In en, this message translates to:
  /// **'Collect · {amount} F'**
  String guichetCollectBtn(String amount);

  /// No description provided for @guichetSelectSeatsFirst.
  ///
  /// In en, this message translates to:
  /// **'Select seats first'**
  String get guichetSelectSeatsFirst;

  /// No description provided for @guichetPaymentSection.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get guichetPaymentSection;

  /// No description provided for @guichetDeparture.
  ///
  /// In en, this message translates to:
  /// **'Departure'**
  String get guichetDeparture;

  /// No description provided for @guichetArrival.
  ///
  /// In en, this message translates to:
  /// **'Arrival'**
  String get guichetArrival;

  /// No description provided for @caisseDailyReport.
  ///
  /// In en, this message translates to:
  /// **'Daily cashier report'**
  String get caisseDailyReport;

  /// No description provided for @caisseRevenueLabel.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get caisseRevenueLabel;

  /// No description provided for @caisseTicketsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get caisseTicketsLabel;

  /// No description provided for @caisseByMethod.
  ///
  /// In en, this message translates to:
  /// **'By payment method'**
  String get caisseByMethod;

  /// No description provided for @caisseTransactionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get caisseTransactionsLabel;

  /// No description provided for @caisseNoTransactions.
  ///
  /// In en, this message translates to:
  /// **'No transactions'**
  String get caisseNoTransactions;

  /// No description provided for @caisseTodayLabel.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get caisseTodayLabel;

  /// No description provided for @dashboardManagement.
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get dashboardManagement;

  /// No description provided for @dashboardAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Analysis'**
  String get dashboardAnalysis;

  /// No description provided for @dashboardDailyRevenue.
  ///
  /// In en, this message translates to:
  /// **'Daily revenue'**
  String get dashboardDailyRevenue;

  /// No description provided for @dashboardTotalRevenue.
  ///
  /// In en, this message translates to:
  /// **'Total revenue'**
  String get dashboardTotalRevenue;

  /// No description provided for @dashboardTotalTickets.
  ///
  /// In en, this message translates to:
  /// **'Total tickets'**
  String get dashboardTotalTickets;

  /// No description provided for @dashboardDriversNav.
  ///
  /// In en, this message translates to:
  /// **'Drivers'**
  String get dashboardDriversNav;

  /// No description provided for @dashboardSchedulesNav.
  ///
  /// In en, this message translates to:
  /// **'Schedules'**
  String get dashboardSchedulesNav;

  /// No description provided for @dashboardStaffNav.
  ///
  /// In en, this message translates to:
  /// **'Team'**
  String get dashboardStaffNav;

  /// No description provided for @dashboardReportsNav.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get dashboardReportsNav;

  /// No description provided for @dashboardStationsNav.
  ///
  /// In en, this message translates to:
  /// **'Stations'**
  String get dashboardStationsNav;

  /// No description provided for @dashboardNetworkNav.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get dashboardNetworkNav;

  /// No description provided for @dashboardTripsNav.
  ///
  /// In en, this message translates to:
  /// **'trips'**
  String get dashboardTripsNav;

  /// No description provided for @dashboardRevenueMonth.
  ///
  /// In en, this message translates to:
  /// **'Revenue (30d)'**
  String get dashboardRevenueMonth;

  /// No description provided for @dashboardTicketsMonth.
  ///
  /// In en, this message translates to:
  /// **'Tickets (30d)'**
  String get dashboardTicketsMonth;

  /// No description provided for @dashboardVehiclesLabel.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get dashboardVehiclesLabel;

  /// No description provided for @dashboardRoutesLabel.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get dashboardRoutesLabel;

  /// No description provided for @dashboardNoData.
  ///
  /// In en, this message translates to:
  /// **'No data available'**
  String get dashboardNoData;

  /// No description provided for @notifJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get notifJustNow;

  /// No description provided for @notifMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{n} min ago'**
  String notifMinutesAgo(int n);

  /// No description provided for @notifHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}h ago'**
  String notifHoursAgo(int n);

  /// No description provided for @notifDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{n}d ago'**
  String notifDaysAgo(int n);

  /// No description provided for @tripsToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get tripsToday;

  /// No description provided for @tripsTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tripsTomorrow;

  /// No description provided for @tripsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get tripsThisWeek;

  /// No description provided for @tripsManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Trip management'**
  String get tripsManageTitle;

  /// No description provided for @tripsNone.
  ///
  /// In en, this message translates to:
  /// **'No trips'**
  String get tripsNone;

  /// No description provided for @searchAllCompanies.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get searchAllCompanies;

  /// No description provided for @searchCityHint.
  ///
  /// In en, this message translates to:
  /// **'Search a city…'**
  String get searchCityHint;

  /// No description provided for @searchOriginHint.
  ///
  /// In en, this message translates to:
  /// **'Where from?'**
  String get searchOriginHint;

  /// No description provided for @searchDestHint.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get searchDestHint;

  /// No description provided for @searchLaunchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Start a search'**
  String get searchLaunchPrompt;

  /// No description provided for @searchLaunchSub.
  ///
  /// In en, this message translates to:
  /// **'Choose your cities and date'**
  String get searchLaunchSub;

  /// No description provided for @searchMissingFields.
  ///
  /// In en, this message translates to:
  /// **'Please select departure and destination.'**
  String get searchMissingFields;

  /// No description provided for @searchInProgress.
  ///
  /// In en, this message translates to:
  /// **'Searching…'**
  String get searchInProgress;

  /// No description provided for @bookingDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Booking details'**
  String get bookingDetailTitle;

  /// No description provided for @bookingRateYourReview.
  ///
  /// In en, this message translates to:
  /// **'Your review'**
  String get bookingRateYourReview;

  /// No description provided for @bookingRateThankYou.
  ///
  /// In en, this message translates to:
  /// **'Thanks for your review!'**
  String get bookingRateThankYou;

  /// No description provided for @bookingRateSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit review'**
  String get bookingRateSubmit;

  /// No description provided for @bookingPayPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment pending'**
  String get bookingPayPendingTitle;

  /// No description provided for @bookingPayPendingBody.
  ///
  /// In en, this message translates to:
  /// **'This booking expires if payment is not completed in time.'**
  String get bookingPayPendingBody;

  /// No description provided for @bookingTicketsSection.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get bookingTicketsSection;

  /// No description provided for @bookingBusEnRoute.
  ///
  /// In en, this message translates to:
  /// **'Bus en route'**
  String get bookingBusEnRoute;

  /// No description provided for @bookingTrackBoardingSub.
  ///
  /// In en, this message translates to:
  /// **'Track live departure'**
  String get bookingTrackBoardingSub;

  /// No description provided for @bookingShareTrip.
  ///
  /// In en, this message translates to:
  /// **'Share this trip'**
  String get bookingShareTrip;

  /// No description provided for @tripInfoVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get tripInfoVehicle;

  /// No description provided for @tripInfoDepartureStation.
  ///
  /// In en, this message translates to:
  /// **'Departure station'**
  String get tripInfoDepartureStation;

  /// No description provided for @tripInfoArrivalStation.
  ///
  /// In en, this message translates to:
  /// **'Arrival station'**
  String get tripInfoArrivalStation;

  /// No description provided for @bookingQrInstruction.
  ///
  /// In en, this message translates to:
  /// **'Show this QR code to the agent at boarding'**
  String get bookingQrInstruction;

  /// No description provided for @bookingQrUnavailable.
  ///
  /// In en, this message translates to:
  /// **'QR code unavailable'**
  String get bookingQrUnavailable;

  /// No description provided for @bookingRefPrefix.
  ///
  /// In en, this message translates to:
  /// **'Ref'**
  String get bookingRefPrefix;

  /// No description provided for @tripPassengersLabel.
  ///
  /// In en, this message translates to:
  /// **'Passengers'**
  String get tripPassengersLabel;

  /// No description provided for @bookingChooseSeats.
  ///
  /// In en, this message translates to:
  /// **'Choose your seats'**
  String get bookingChooseSeats;

  /// No description provided for @bookingModifySeats.
  ///
  /// In en, this message translates to:
  /// **'Modify'**
  String get bookingModifySeats;

  /// No description provided for @bookingPricePerSeat.
  ///
  /// In en, this message translates to:
  /// **'{price} F / seat'**
  String bookingPricePerSeat(String price);

  /// No description provided for @bookingConfirmAndPay.
  ///
  /// In en, this message translates to:
  /// **'Confirm and pay · {amount} F'**
  String bookingConfirmAndPay(String amount);

  /// No description provided for @bookingSelectSeatsPrompt.
  ///
  /// In en, this message translates to:
  /// **'Select your seats'**
  String get bookingSelectSeatsPrompt;

  /// No description provided for @bookingPaymentNote.
  ///
  /// In en, this message translates to:
  /// **'Secure payment via GeniusPay · Orange Money, MTN MoMo, Wave and card accepted.'**
  String get bookingPaymentNote;

  /// No description provided for @profileAccountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account settings'**
  String get profileAccountSettings;

  /// No description provided for @profileCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get profileCurrentPassword;

  /// No description provided for @profileNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get profileNewPassword;

  /// No description provided for @profileConfirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get profileConfirmNewPassword;

  /// No description provided for @profilePasswordMin.
  ///
  /// In en, this message translates to:
  /// **'Minimum 6 characters'**
  String get profilePasswordMin;

  /// No description provided for @profilePasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password updated'**
  String get profilePasswordChanged;

  /// No description provided for @profileSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get profileSaveChanges;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdated;

  /// No description provided for @paymentSecureTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure payment'**
  String get paymentSecureTitle;

  /// No description provided for @paymentLoadingWebview.
  ///
  /// In en, this message translates to:
  /// **'Loading payment…'**
  String get paymentLoadingWebview;

  /// No description provided for @reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get reload;

  /// No description provided for @companyCannotLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load company'**
  String get companyCannotLoad;

  /// No description provided for @companyTripsAvail.
  ///
  /// In en, this message translates to:
  /// **'Available trips'**
  String get companyTripsAvail;

  /// No description provided for @companyLinesLabel.
  ///
  /// In en, this message translates to:
  /// **'Lines'**
  String get companyLinesLabel;

  /// No description provided for @companyContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get companyContact;

  /// No description provided for @companyStationsCount.
  ///
  /// In en, this message translates to:
  /// **'Stations ({n})'**
  String companyStationsCount(int n);

  /// No description provided for @companyRoutesCount.
  ///
  /// In en, this message translates to:
  /// **'Routes ({n})'**
  String companyRoutesCount(int n);

  /// No description provided for @stationCannotLoad.
  ///
  /// In en, this message translates to:
  /// **'Failed to load station'**
  String get stationCannotLoad;

  /// No description provided for @stationDeparturesLabel.
  ///
  /// In en, this message translates to:
  /// **'Departures'**
  String get stationDeparturesLabel;

  /// No description provided for @stationGpsAvail.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get stationGpsAvail;

  /// No description provided for @stationPracticalInfo.
  ///
  /// In en, this message translates to:
  /// **'Practical information'**
  String get stationPracticalInfo;

  /// No description provided for @stationNavigateBtn.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get stationNavigateBtn;

  /// No description provided for @stationNextDepartures.
  ///
  /// In en, this message translates to:
  /// **'Next departures ({n})'**
  String stationNextDepartures(int n);

  /// No description provided for @stationNoDepartures.
  ///
  /// In en, this message translates to:
  /// **'No departures scheduled today'**
  String get stationNoDepartures;

  /// No description provided for @stationSeats.
  ///
  /// In en, this message translates to:
  /// **'{seats} seats'**
  String stationSeats(int seats);

  /// No description provided for @navScreenLocationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location denied — enable it in settings'**
  String get navScreenLocationDenied;

  /// No description provided for @navScreenArrived.
  ///
  /// In en, this message translates to:
  /// **'You have arrived!'**
  String get navScreenArrived;

  /// No description provided for @navScreenNoDistance.
  ///
  /// In en, this message translates to:
  /// **'Cannot calculate distance without location.'**
  String get navScreenNoDistance;

  /// No description provided for @navScreenLocating.
  ///
  /// In en, this message translates to:
  /// **'Locating…'**
  String get navScreenLocating;

  /// No description provided for @navScreenDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get navScreenDistance;

  /// No description provided for @navScreenWalking.
  ///
  /// In en, this message translates to:
  /// **'On foot'**
  String get navScreenWalking;

  /// No description provided for @tripTrackingTitle.
  ///
  /// In en, this message translates to:
  /// **'Live tracking'**
  String get tripTrackingTitle;

  /// No description provided for @tripTrackingWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting for location…'**
  String get tripTrackingWaiting;

  /// No description provided for @tripTrackingEta.
  ///
  /// In en, this message translates to:
  /// **'Expected arrival'**
  String get tripTrackingEta;

  /// No description provided for @tripTrackingSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get tripTrackingSteps;

  /// No description provided for @tripTrackingOccupied.
  ///
  /// In en, this message translates to:
  /// **'{occupied}/{total} seats occupied'**
  String tripTrackingOccupied(int occupied, int total);

  /// No description provided for @tripSocketLive.
  ///
  /// In en, this message translates to:
  /// **'● Live'**
  String get tripSocketLive;

  /// No description provided for @tripSocketConnecting.
  ///
  /// In en, this message translates to:
  /// **'○ Connecting…'**
  String get tripSocketConnecting;

  /// No description provided for @tripSocketReconnecting.
  ///
  /// In en, this message translates to:
  /// **'○ Reconnecting…'**
  String get tripSocketReconnecting;

  /// No description provided for @tripSocketOffline.
  ///
  /// In en, this message translates to:
  /// **'✕ Offline'**
  String get tripSocketOffline;

  /// No description provided for @seatPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your seats'**
  String get seatPickerTitle;

  /// No description provided for @seatAvailableLabel.
  ///
  /// In en, this message translates to:
  /// **'Available'**
  String get seatAvailableLabel;

  /// No description provided for @seatSelectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get seatSelectedLabel;

  /// No description provided for @seatOccupiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Occupied'**
  String get seatOccupiedLabel;

  /// No description provided for @seatFrontOfBus.
  ///
  /// In en, this message translates to:
  /// **'Front of bus'**
  String get seatFrontOfBus;

  /// No description provided for @seatSelectMin.
  ///
  /// In en, this message translates to:
  /// **'Select at least 1 seat'**
  String get seatSelectMin;

  /// No description provided for @seatConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Confirm 1 seat · {amount} F} other{Confirm {count} seats · {amount} F}}'**
  String seatConfirmButton(int count, String amount);

  /// No description provided for @agentGpsEnableHint.
  ///
  /// In en, this message translates to:
  /// **'Enable GPS in settings'**
  String get agentGpsEnableHint;

  /// No description provided for @manifestSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search a passenger or seat…'**
  String get manifestSearchHint;

  /// No description provided for @manifestMissingAlert.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} passenger not boarded} other{{count} passengers not boarded}}'**
  String manifestMissingAlert(int count);

  /// No description provided for @manifestNoPassengers.
  ///
  /// In en, this message translates to:
  /// **'No passengers'**
  String get manifestNoPassengers;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @quickSaleTicketCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} ticket} other{{count} tickets}}'**
  String quickSaleTicketCount(int count);

  /// No description provided for @payMethodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get payMethodCash;

  /// No description provided for @agentStationLabel.
  ///
  /// In en, this message translates to:
  /// **'Assigned station'**
  String get agentStationLabel;

  /// No description provided for @agentInfoSection.
  ///
  /// In en, this message translates to:
  /// **'Information'**
  String get agentInfoSection;

  /// No description provided for @schedulesNoSchedules.
  ///
  /// In en, this message translates to:
  /// **'No schedules'**
  String get schedulesNoSchedules;

  /// No description provided for @schedulesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a schedule'**
  String get schedulesAdd;

  /// No description provided for @schedulesNew.
  ///
  /// In en, this message translates to:
  /// **'New schedule'**
  String get schedulesNew;

  /// No description provided for @schedulesCreate.
  ///
  /// In en, this message translates to:
  /// **'Create schedule'**
  String get schedulesCreate;

  /// No description provided for @scheduleDays.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get scheduleDays;

  /// No description provided for @scheduleRouteLabel.
  ///
  /// In en, this message translates to:
  /// **'Route'**
  String get scheduleRouteLabel;

  /// No description provided for @scheduleSelectRoute.
  ///
  /// In en, this message translates to:
  /// **'Select a route'**
  String get scheduleSelectRoute;

  /// No description provided for @scheduleDepartureTime.
  ///
  /// In en, this message translates to:
  /// **'Departure time'**
  String get scheduleDepartureTime;

  /// No description provided for @staffNoMembers.
  ///
  /// In en, this message translates to:
  /// **'No staff members'**
  String get staffNoMembers;

  /// No description provided for @staffInviteAgent.
  ///
  /// In en, this message translates to:
  /// **'Invite an agent'**
  String get staffInviteAgent;

  /// No description provided for @staffInvite.
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get staffInvite;

  /// No description provided for @staffInviteMember.
  ///
  /// In en, this message translates to:
  /// **'Invite a member'**
  String get staffInviteMember;

  /// No description provided for @staffSendInvite.
  ///
  /// In en, this message translates to:
  /// **'Send invitation'**
  String get staffSendInvite;

  /// No description provided for @staffInviteSent.
  ///
  /// In en, this message translates to:
  /// **'Invitation sent'**
  String get staffInviteSent;

  /// No description provided for @staffRoleLabel.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get staffRoleLabel;

  /// No description provided for @staffStationOptional.
  ///
  /// In en, this message translates to:
  /// **'Assigned station (optional)'**
  String get staffStationOptional;

  /// No description provided for @stationsNone.
  ///
  /// In en, this message translates to:
  /// **'No stations'**
  String get stationsNone;

  /// No description provided for @stationsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a station'**
  String get stationsAdd;

  /// No description provided for @stationsNew.
  ///
  /// In en, this message translates to:
  /// **'New station'**
  String get stationsNew;

  /// No description provided for @stationsCreate.
  ///
  /// In en, this message translates to:
  /// **'Create station'**
  String get stationsCreate;

  /// No description provided for @stationsPrimary.
  ///
  /// In en, this message translates to:
  /// **'Primary'**
  String get stationsPrimary;

  /// No description provided for @stationsSetPrimary.
  ///
  /// In en, this message translates to:
  /// **'Set as primary'**
  String get stationsSetPrimary;

  /// No description provided for @stationsPrimaryCannotDelete.
  ///
  /// In en, this message translates to:
  /// **'Primary station cannot be deleted'**
  String get stationsPrimaryCannotDelete;

  /// No description provided for @stationsAgentCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} agent} other{{n} agents}}'**
  String stationsAgentCount(int n);

  /// No description provided for @stationsPrimaryLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary station'**
  String get stationsPrimaryLabel;

  /// No description provided for @stationsPrimarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Default station for your account'**
  String get stationsPrimarySubtitle;

  /// No description provided for @stationsName.
  ///
  /// In en, this message translates to:
  /// **'Station name'**
  String get stationsName;

  /// No description provided for @stationsDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete station'**
  String get stationsDeleteTitle;

  /// No description provided for @reportsPeriod365d.
  ///
  /// In en, this message translates to:
  /// **'1 year'**
  String get reportsPeriod365d;

  /// No description provided for @reportsBookingsSection.
  ///
  /// In en, this message translates to:
  /// **'Bookings'**
  String get reportsBookingsSection;

  /// No description provided for @reportsTotalBookings.
  ///
  /// In en, this message translates to:
  /// **'Total bookings'**
  String get reportsTotalBookings;

  /// No description provided for @reportsExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get reportsExport;

  /// No description provided for @reportsExportError.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get reportsExportError;

  /// No description provided for @reportsByStatus.
  ///
  /// In en, this message translates to:
  /// **'By status'**
  String get reportsByStatus;

  /// No description provided for @reportsExportSubject.
  ///
  /// In en, this message translates to:
  /// **'TransPro report ({format})'**
  String reportsExportSubject(String format);

  /// No description provided for @fleetStatusOutOfService.
  ///
  /// In en, this message translates to:
  /// **'Out of service'**
  String get fleetStatusOutOfService;

  /// No description provided for @fleetActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get fleetActivate;

  /// No description provided for @fleetDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get fleetDeactivate;

  /// No description provided for @fleetMaintenanceOilChange.
  ///
  /// In en, this message translates to:
  /// **'Oil change'**
  String get fleetMaintenanceOilChange;

  /// No description provided for @fleetMaintenanceTireRotation.
  ///
  /// In en, this message translates to:
  /// **'Tire rotation'**
  String get fleetMaintenanceTireRotation;

  /// No description provided for @fleetMaintenanceBrakeService.
  ///
  /// In en, this message translates to:
  /// **'Brakes'**
  String get fleetMaintenanceBrakeService;

  /// No description provided for @fleetMaintenanceFilterChange.
  ///
  /// In en, this message translates to:
  /// **'Filter change'**
  String get fleetMaintenanceFilterChange;

  /// No description provided for @fleetMaintenanceMajorService.
  ///
  /// In en, this message translates to:
  /// **'Major service'**
  String get fleetMaintenanceMajorService;

  /// No description provided for @fleetMaintenanceRepair.
  ///
  /// In en, this message translates to:
  /// **'Repair'**
  String get fleetMaintenanceRepair;

  /// No description provided for @fleetMaintenanceInspection.
  ///
  /// In en, this message translates to:
  /// **'Inspection'**
  String get fleetMaintenanceInspection;

  /// No description provided for @fleetFuelLiters.
  ///
  /// In en, this message translates to:
  /// **'Liters'**
  String get fleetFuelLiters;

  /// No description provided for @fleetFuelTotalCost.
  ///
  /// In en, this message translates to:
  /// **'Total cost'**
  String get fleetFuelTotalCost;

  /// No description provided for @fleetOdometer.
  ///
  /// In en, this message translates to:
  /// **'Mileage'**
  String get fleetOdometer;

  /// No description provided for @fleetFuelStationLabel.
  ///
  /// In en, this message translates to:
  /// **'Station'**
  String get fleetFuelStationLabel;

  /// No description provided for @fleetDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get fleetDescriptionLabel;

  /// No description provided for @fleetCostLabel.
  ///
  /// In en, this message translates to:
  /// **'Cost'**
  String get fleetCostLabel;

  /// No description provided for @fleetGarageLabel.
  ///
  /// In en, this message translates to:
  /// **'Garage'**
  String get fleetGarageLabel;

  /// No description provided for @fleetDeleteFuelTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this refuel?'**
  String get fleetDeleteFuelTitle;

  /// No description provided for @fleetDeleteMaintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this service?'**
  String get fleetDeleteMaintenanceTitle;

  /// No description provided for @fleetTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get fleetTypeLabel;

  /// No description provided for @notDefined.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notDefined;

  /// No description provided for @driverSingularLabel.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driverSingularLabel;

  /// No description provided for @driverEvaluateTitle.
  ///
  /// In en, this message translates to:
  /// **'Evaluate driver'**
  String get driverEvaluateTitle;

  /// No description provided for @driverAddAbsenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Record absence'**
  String get driverAddAbsenceTitle;

  /// No description provided for @driverEvalCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} evaluation} other{{n} evaluations}}'**
  String driverEvalCount(int n);

  /// No description provided for @driverEvalBy.
  ///
  /// In en, this message translates to:
  /// **'By {name}'**
  String driverEvalBy(String name);

  /// No description provided for @driverAbsenceStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get driverAbsenceStartDate;

  /// No description provided for @driverAbsenceEndDate.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get driverAbsenceEndDate;

  /// No description provided for @driverAbsenceSelectDates.
  ///
  /// In en, this message translates to:
  /// **'Select the dates'**
  String get driverAbsenceSelectDates;

  /// No description provided for @driverAbsenceReasonOptional.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get driverAbsenceReasonOptional;

  /// No description provided for @routeDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get routeDeactivate;

  /// No description provided for @routeActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get routeActivate;

  /// No description provided for @routeSchedulesCount.
  ///
  /// In en, this message translates to:
  /// **'{n, plural, =1{{n} schedule} other{{n} schedules}}'**
  String routeSchedulesCount(int n);

  /// No description provided for @routeNew.
  ///
  /// In en, this message translates to:
  /// **'New route'**
  String get routeNew;

  /// No description provided for @routeNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Route name'**
  String get routeNameLabel;

  /// No description provided for @routeOriginCity.
  ///
  /// In en, this message translates to:
  /// **'Origin city'**
  String get routeOriginCity;

  /// No description provided for @routeDestCity.
  ///
  /// In en, this message translates to:
  /// **'Destination city'**
  String get routeDestCity;

  /// No description provided for @routeDistance.
  ///
  /// In en, this message translates to:
  /// **'Distance (km)'**
  String get routeDistance;

  /// No description provided for @routeDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration (min)'**
  String get routeDuration;

  /// No description provided for @routeBasePrice.
  ///
  /// In en, this message translates to:
  /// **'Base price (FCFA)'**
  String get routeBasePrice;

  /// No description provided for @routeSelectCities.
  ///
  /// In en, this message translates to:
  /// **'Select the cities'**
  String get routeSelectCities;

  /// No description provided for @profileNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get profileNameLabel;

  /// No description provided for @profileAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get profileAddressLabel;

  /// No description provided for @profileRccmLabel.
  ///
  /// In en, this message translates to:
  /// **'RCCM'**
  String get profileRccmLabel;

  /// No description provided for @profileCompanyName.
  ///
  /// In en, this message translates to:
  /// **'Company name'**
  String get profileCompanyName;

  /// No description provided for @profileEditCompany.
  ///
  /// In en, this message translates to:
  /// **'Edit company'**
  String get profileEditCompany;

  /// No description provided for @fleetNewVehicle.
  ///
  /// In en, this message translates to:
  /// **'New vehicle'**
  String get fleetNewVehicle;

  /// No description provided for @fleetClass.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get fleetClass;

  /// No description provided for @invalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid number'**
  String get invalidNumber;

  /// No description provided for @companiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Companies'**
  String get companiesTitle;

  /// No description provided for @companiesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search a company…'**
  String get companiesSearchHint;

  /// No description provided for @favoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favoritesTitle;

  /// No description provided for @favoritesCompanies.
  ///
  /// In en, this message translates to:
  /// **'Favorite companies'**
  String get favoritesCompanies;

  /// No description provided for @favoritesStations.
  ///
  /// In en, this message translates to:
  /// **'Favorite stations'**
  String get favoritesStations;

  /// No description provided for @favoritesNoCompanies.
  ///
  /// In en, this message translates to:
  /// **'No favorite companies yet'**
  String get favoritesNoCompanies;

  /// No description provided for @favoritesNoStations.
  ///
  /// In en, this message translates to:
  /// **'No favorite stations yet'**
  String get favoritesNoStations;

  /// No description provided for @homeFavoriteCompanies.
  ///
  /// In en, this message translates to:
  /// **'My favorite companies'**
  String get homeFavoriteCompanies;

  /// No description provided for @transactionsTitle.
  ///
  /// In en, this message translates to:
  /// **'My transactions'**
  String get transactionsTitle;

  /// No description provided for @transactionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet'**
  String get transactionsEmpty;

  /// No description provided for @transactionsEmptySub.
  ///
  /// In en, this message translates to:
  /// **'Your payments will appear here.'**
  String get transactionsEmptySub;

  /// No description provided for @transactionsFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get transactionsFilterAll;

  /// No description provided for @transactionsFilterSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successful'**
  String get transactionsFilterSuccess;

  /// No description provided for @transactionsFilterFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get transactionsFilterFailed;

  /// No description provided for @transactionsFilterPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get transactionsFilterPending;

  /// No description provided for @transactionsTotalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total spent'**
  String get transactionsTotalSpent;

  /// No description provided for @transactionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} transaction(s)'**
  String transactionsCount(int count);

  /// No description provided for @transactionsMethodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get transactionsMethodCash;

  /// No description provided for @transactionsMethodMobile.
  ///
  /// In en, this message translates to:
  /// **'Mobile Money'**
  String get transactionsMethodMobile;

  /// No description provided for @transactionsMethodCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get transactionsMethodCard;

  /// No description provided for @transactionsStatusSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successful'**
  String get transactionsStatusSuccess;

  /// No description provided for @transactionsStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get transactionsStatusFailed;

  /// No description provided for @transactionsStatusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get transactionsStatusProcessing;

  /// No description provided for @transactionsStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get transactionsStatusPending;

  /// No description provided for @transactionsRef.
  ///
  /// In en, this message translates to:
  /// **'Ref. {ref}'**
  String transactionsRef(String ref);

  /// No description provided for @transactionsSeats.
  ///
  /// In en, this message translates to:
  /// **'{count} seat(s)'**
  String transactionsSeats(int count);

  /// No description provided for @transactionsDrawerLabel.
  ///
  /// In en, this message translates to:
  /// **'My transactions'**
  String get transactionsDrawerLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
