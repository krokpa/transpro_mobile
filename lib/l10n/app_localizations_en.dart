// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'TransPro CI';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get back => 'Back';

  @override
  String get close => 'Close';

  @override
  String get retry => 'Retry';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get ok => 'OK';

  @override
  String get see => 'View';

  @override
  String get required => 'Required';

  @override
  String get loading => 'Loading…';

  @override
  String get error => 'An error occurred';

  @override
  String get errorNetwork => 'Network error. Check your connection.';

  @override
  String get errorServer => 'Server error. Please try again.';

  @override
  String get errorUnknown => 'Unknown error';

  @override
  String get successSaved => 'Saved successfully';

  @override
  String get successDeleted => 'Deleted successfully';

  @override
  String get confirmDeleteTitle => 'Delete?';

  @override
  String get confirmDeleteBody => 'This action cannot be undone.';

  @override
  String get optional => 'optional';

  @override
  String get search => 'Search';

  @override
  String get filter => 'Filter';

  @override
  String get from => 'From';

  @override
  String get to => 'To';

  @override
  String get date => 'Date';

  @override
  String get time => 'Time';

  @override
  String get price => 'Price';

  @override
  String get total => 'Total';

  @override
  String get status => 'Status';

  @override
  String get details => 'Details';

  @override
  String get none => 'None';

  @override
  String get notAvailable => 'N/A';

  @override
  String get loginTitle => 'Welcome back';

  @override
  String get loginSubtitle => 'Sign in to your TransPro account';

  @override
  String get emailLabel => 'Email address';

  @override
  String get emailHint => 'example@email.com';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordHint => 'Your password';

  @override
  String get loginButton => 'Sign in';

  @override
  String get forgotPasswordLink => 'Forgot password?';

  @override
  String get noAccountText => 'No account yet?';

  @override
  String get registerLink => 'Create one';

  @override
  String get loginError => 'Incorrect email or password';

  @override
  String get registerTitle => 'Create an account';

  @override
  String get registerSubtitle => 'Join TransPro CI';

  @override
  String get firstNameLabel => 'First name';

  @override
  String get firstNameHint => 'John';

  @override
  String get lastNameLabel => 'Last name';

  @override
  String get lastNameHint => 'Doe';

  @override
  String get phoneLabel => 'Phone number';

  @override
  String get phoneHint => '+225 07 00 00 00 00';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get confirmPasswordHint => 'Repeat your password';

  @override
  String get passwordMismatch => 'Passwords do not match';

  @override
  String get registerButton => 'Create account';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get loginLink => 'Sign in';

  @override
  String get forgotPasswordTitle => 'Forgot password?';

  @override
  String get forgotPasswordSubtitle =>
      'Enter your email address and we\'ll send you a reset link';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get backToLogin => 'Back to login';

  @override
  String get resetEmailSent => 'Email sent! Check your inbox.';

  @override
  String get pinLoginTitle => 'PIN Code';

  @override
  String get pinLoginSubtitle => 'Enter your 4-digit code';

  @override
  String get pinLockedTitle => 'Account locked';

  @override
  String get pinLockedError => 'Too many failed attempts. Use your password.';

  @override
  String pinWrongError(int attempts, int max) {
    return 'Incorrect PIN ($attempts/$max attempts)';
  }

  @override
  String get pinSignInAnother => 'Sign in another way';

  @override
  String get pinSetupTitle => 'Choose a PIN';

  @override
  String get pinSetupSubtitle => 'This PIN will secure access to the app';

  @override
  String get pinConfirmTitle => 'Confirm your PIN';

  @override
  String get pinConfirmSubtitle => 'Enter the same 4-digit code again';

  @override
  String get pinMismatch => 'PINs do not match. Please try again.';

  @override
  String get pinSetupBiometricLabel => 'Enable biometrics';

  @override
  String get pinSetupBiometricSub => 'Fingerprint / Face ID';

  @override
  String get pinRetry => 'Start over';

  @override
  String get biometricReason => 'Unlock TransPro with your biometrics';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get onboarding1Title => 'Find your trip';

  @override
  String get onboarding1Body =>
      'Search among hundreds of available trips across Côte d\'Ivoire. Choose your date, origin, and destination.';

  @override
  String get onboarding2Title => 'Choose your seat';

  @override
  String get onboarding2Body =>
      'Pick your spot in the bus according to your preferences. Window, aisle, VIP — all at your fingertips.';

  @override
  String get onboarding3Title => 'Pay securely';

  @override
  String get onboarding3Body =>
      'Pay with Orange Money, MTN MoMo, Wave, or cash. Your QR ticket is available offline for boarding.';

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navTickets => 'Tickets';

  @override
  String get navProfile => 'Profile';

  @override
  String get navDepartures => 'Departures';

  @override
  String get navScanner => 'Scanner';

  @override
  String get navGuichet => 'Counter';

  @override
  String get navCaisse => 'Cashier';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navTrips => 'Trips';

  @override
  String get navFleet => 'Fleet';

  @override
  String get navRoutes => 'Routes';

  @override
  String get settingsAppearance => 'Appearance & Security';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsBiometric => 'Biometrics';

  @override
  String get settingsBiometricSub => 'Fingerprint / Face ID';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsEditProfile => 'Edit profile';

  @override
  String get settingsChangePassword => 'Change password';

  @override
  String get settingsLogout => 'Sign out';

  @override
  String get settingsLogoutConfirm => 'Sign out';

  @override
  String get settingsLogoutBody => 'Are you sure you want to sign out?';

  @override
  String get settingsLogoutCancel => 'Cancel';

  @override
  String get settingsQuickNav => 'Quick navigation';

  @override
  String get passengerRole => 'Passenger';

  @override
  String get agentRole => 'Agent';

  @override
  String get ownerRole => 'Owner';

  @override
  String get adminRole => 'Administrator';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String get homeSearchPlaceholder => 'Where are you going?';

  @override
  String get homeRecentSearches => 'Recent searches';

  @override
  String get homePopularRoutes => 'Popular routes';

  @override
  String get searchFromCity => 'Departure city';

  @override
  String get searchToCity => 'Arrival city';

  @override
  String get searchSelectDate => 'Select a date';

  @override
  String get searchPassengerCount => 'Number of passengers';

  @override
  String get searchButtonLabel => 'Search trips';

  @override
  String get searchResults => 'Available trips';

  @override
  String get searchNoResults => 'No trips found for this route';

  @override
  String get searchTryOther => 'Try other dates or cities';

  @override
  String searchSeat(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'seats',
      one: 'seat',
    );
    return '$_temp0';
  }

  @override
  String get tripDeparture => 'Departure';

  @override
  String get tripArrival => 'Arrival';

  @override
  String get tripDuration => 'Duration';

  @override
  String get tripAvailable => 'Available';

  @override
  String get tripClass => 'Class';

  @override
  String get tripClassStandard => 'Standard';

  @override
  String get tripClassVip => 'VIP';

  @override
  String get tripClassExpress => 'Express';

  @override
  String get tripStatusScheduled => 'Scheduled';

  @override
  String get tripStatusBoarding => 'Boarding';

  @override
  String get tripStatusDeparted => 'Departed';

  @override
  String get tripStatusArrived => 'Arrived';

  @override
  String get tripStatusCancelled => 'Cancelled';

  @override
  String get tripBook => 'Book';

  @override
  String get tripSelectSeat => 'Select a seat';

  @override
  String get tripSeatOccupied => 'Occupied';

  @override
  String get tripSeatAvailable => 'Available';

  @override
  String get tripSeatBlocked => 'Blocked';

  @override
  String get tripSeatYours => 'Your seat';

  @override
  String get tripConfirmBooking => 'Confirm booking';

  @override
  String get tripPassengerInfo => 'Passenger information';

  @override
  String get bookingsTitle => 'My tickets';

  @override
  String get bookingsNoBookings => 'No tickets yet';

  @override
  String get bookingsNoBookingsSub => 'Your booked trips will appear here';

  @override
  String get bookingStatusConfirmed => 'Confirmed';

  @override
  String get bookingStatusPending => 'Pending';

  @override
  String get bookingStatusUpcoming => 'Upcoming';

  @override
  String get bookingStatusCompleted => 'Completed';

  @override
  String get bookingStatusCancelled => 'Cancelled';

  @override
  String get bookingRef => 'Reference';

  @override
  String get bookingSeats => 'Seats';

  @override
  String get bookingTotal => 'Total paid';

  @override
  String get bookingDownload => 'Download ticket';

  @override
  String get bookingShare => 'Share';

  @override
  String get bookingCancel => 'Cancel booking';

  @override
  String get bookingCancelConfirm => 'Cancel this booking?';

  @override
  String get bookingRateTrip => 'Rate this trip';

  @override
  String get bookingRateTitle => 'How was your trip?';

  @override
  String get bookingRateComment => 'Your comment (optional)';

  @override
  String get bookingPayNow => 'Pay now';

  @override
  String get bookingPaid => 'Paid';

  @override
  String get bookingPending => 'Pending payment';

  @override
  String bookingSeatNumber(String seat) {
    return 'Seat $seat';
  }

  @override
  String get paymentTitle => 'Payment';

  @override
  String get paymentChooseMethod => 'Choose a payment method';

  @override
  String get paymentProcessing => 'Processing payment…';

  @override
  String get paymentSuccess => 'Payment successful!';

  @override
  String get paymentSuccessSub => 'Your ticket has been confirmed.';

  @override
  String get paymentFailed => 'Payment failed';

  @override
  String get paymentFailedSub => 'Please try again or use another method.';

  @override
  String get paymentGoToTicket => 'View my ticket';

  @override
  String get paymentRetry => 'Try again';

  @override
  String get scanTitle => 'Ticket scanner';

  @override
  String get scanInstruction => 'Position the QR code in the frame';

  @override
  String get scanSuccess => 'Ticket validated';

  @override
  String get scanInvalid => 'Invalid or unrecognised ticket';

  @override
  String get scanAlreadyUsed => 'Ticket already validated';

  @override
  String get scanOfflineBadge => 'Offline — will sync on reconnection';

  @override
  String get scanOfflineMode => 'Offline mode active';

  @override
  String get scanResult => 'Scan result';

  @override
  String get scanSeatLabel => 'Seat';

  @override
  String get scanTripLabel => 'Trip';

  @override
  String get scanPassengerLabel => 'Passenger';

  @override
  String get scanScanAnother => 'Scan another';

  @override
  String get departuresTitle => 'Today\'s departures';

  @override
  String get departuresNone => 'No scheduled departures';

  @override
  String get departureSeeManifest => 'Manifest';

  @override
  String get departureDownloadOffline => 'Download offline';

  @override
  String get departureOfflineReady => 'Offline ready';

  @override
  String departureCountdown(String time) {
    return 'in $time';
  }

  @override
  String get manifestTitle => 'Passenger list';

  @override
  String get manifestScanned => 'Scanned';

  @override
  String get manifestNotScanned => 'Not scanned';

  @override
  String get manifestMissing => 'Missing passengers';

  @override
  String manifestTotal(int scanned, int total) {
    return '$scanned/$total passengers';
  }

  @override
  String get manifestCallPassenger => 'Call';

  @override
  String get quickSaleTitle => 'Quick sale';

  @override
  String get quickSaleSelectTrip => 'Select a departure';

  @override
  String get quickSaleQty => 'Quantity';

  @override
  String get quickSalePayMethod => 'Payment method';

  @override
  String quickSaleCollect(String amount) {
    return 'Collect $amount F';
  }

  @override
  String get quickSaleSuccess => 'Payment received';

  @override
  String get quickSaleNew => 'New sale';

  @override
  String get quickSaleBackToDepartures => 'Back to departures';

  @override
  String get guichetTitle => 'Ticket counter';

  @override
  String get caisseTitle => 'Daily cashier';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get dashboardRevenue => 'Revenue';

  @override
  String get dashboardTrips => 'Trips';

  @override
  String get dashboardOccupancy => 'Occupancy';

  @override
  String get dashboardPassengers => 'Passengers';

  @override
  String get dashboardPeriod7d => '7 days';

  @override
  String get dashboardPeriod30d => '30 days';

  @override
  String get dashboardPeriod90d => '90 days';

  @override
  String get dashboardTopRoutes => 'Top routes';

  @override
  String get dashboardFillRate => 'Fill rate by route';

  @override
  String get fleetTitle => 'Fleet';

  @override
  String get fleetAddVehicle => 'Add vehicle';

  @override
  String get fleetNoVehicles => 'No vehicles registered';

  @override
  String get fleetPlate => 'Plate';

  @override
  String get fleetBrand => 'Brand';

  @override
  String get fleetModel => 'Model';

  @override
  String get fleetYear => 'Year';

  @override
  String get fleetCapacity => 'Capacity';

  @override
  String get fleetStatusActive => 'Active';

  @override
  String get fleetStatusInactive => 'Inactive';

  @override
  String get fleetStatusMaintenance => 'Maintenance';

  @override
  String get fleetFuelTab => 'Fuel';

  @override
  String get fleetMaintenanceTab => 'Maintenance';

  @override
  String get fleetNoFuelLogs => 'No fuel logs';

  @override
  String get fleetNoMaintenanceLogs => 'No maintenance logs';

  @override
  String get fleetAddFuel => 'Log refuel';

  @override
  String get fleetAddMaintenance => 'Log service';

  @override
  String get fleetNextService => 'Next service';

  @override
  String get driversTitle => 'Drivers';

  @override
  String get driversAddDriver => 'Add driver';

  @override
  String get driversNoDrivers => 'No drivers registered';

  @override
  String get driverLicenseExpiry => 'License expiry';

  @override
  String get driverLicenseExpired => 'Expired';

  @override
  String get driverLicenseExpiringSoon => 'Expiring soon';

  @override
  String get driverAvailable => 'Available';

  @override
  String get driverUnavailable => 'Unavailable';

  @override
  String get driverScheduleTab => 'Schedule';

  @override
  String get driverAbsencesTab => 'Absences';

  @override
  String get driverEvaluationsTab => 'Evaluations';

  @override
  String get driverNoTrips => 'No trips this month';

  @override
  String get driverNoAbsences => 'No absences recorded';

  @override
  String get driverNoEvaluations => 'No evaluations yet';

  @override
  String get driverAddAbsence => 'Record absence';

  @override
  String get driverAddEvaluation => 'Evaluate';

  @override
  String get driverAbsenceLeave => 'Leave';

  @override
  String get driverAbsenceSick => 'Sick';

  @override
  String get driverAbsenceOther => 'Other';

  @override
  String get driverAbsenceApprove => 'Approve';

  @override
  String get driverAbsenceApproved => 'Approved';

  @override
  String get driverAbsencePending => 'Pending';

  @override
  String get driverAbsenceReason => 'Reason';

  @override
  String get driverEvalOverall => 'Overall';

  @override
  String get driverEvalPunctuality => 'Punctuality';

  @override
  String get driverEvalSafety => 'Safety';

  @override
  String get driverEvalService => 'Service';

  @override
  String get driverEvalComment => 'Comment (optional)';

  @override
  String get driverEvalAverageRating => 'Average rating';

  @override
  String get routesTitle => 'Network';

  @override
  String get routesNoRoutes => 'No routes defined';

  @override
  String get routesAddRoute => 'Add route';

  @override
  String get schedulesTitle => 'Schedules';

  @override
  String get staffTitle => 'Team';

  @override
  String get stationsTitle => 'Stations';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsNone => 'No notifications';

  @override
  String get notificationsMarkAllRead => 'Mark all as read';

  @override
  String get profileTitle => 'My profile';

  @override
  String get profilePersonalInfo => 'Personal information';

  @override
  String get profileCompany => 'Company';

  @override
  String get languageAuto => 'System (auto)';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get appTagline => 'Your trip in hand';

  @override
  String get loginOr => 'or';

  @override
  String get seeAll => 'See all';

  @override
  String get validationEmailInvalid => 'Invalid email';

  @override
  String get validationPhoneInvalid => 'Invalid number (min. 8 digits)';

  @override
  String get validationPasswordMin => 'Minimum 8 characters';

  @override
  String get registerFormTitle => 'Your information';

  @override
  String get registerFormSub => 'Fill all fields to continue';

  @override
  String get registerTerms =>
      'By creating an account, you agree to our terms of use.';

  @override
  String get registerPassengerSubtitle => 'Create a passenger account';

  @override
  String get forgotSentTitle => 'Email sent!';

  @override
  String get forgotSentBody =>
      'If this email is registered, you\'ll receive a reset link.';

  @override
  String get forgotSpamNote => 'Also check your spam folder.';

  @override
  String get forgotInstruction =>
      'Enter your email address to receive a reset link.';

  @override
  String homeGreeting(String name) {
    return 'Hello, $name';
  }

  @override
  String get homeWhereToGo => 'Where are you going?';

  @override
  String get homeSearchHint => 'Search for a trip…';

  @override
  String get homeUpcomingDepartures => 'Upcoming departures';

  @override
  String get homeNextDeparture => 'Next departure';

  @override
  String get homeAwaitingPayment => 'Awaiting payment';

  @override
  String get homeViewTickets => 'View tickets';

  @override
  String get homeNoTripsTitle => 'No trips available';

  @override
  String get homeNoTripsSub => 'Come back later or try different criteria.';

  @override
  String get homeAlerts => 'Alerts';

  @override
  String get homeBoardingStatus => 'Boarding';

  @override
  String get homeBookNow => 'Book';

  @override
  String get bookingsOfflineMode => 'Offline mode — cached tickets';

  @override
  String get bookingsPendingPay => 'Payment pending — tap to pay';

  @override
  String get bookingsTrackLive => 'Track live';

  @override
  String get bookingsTrackBoarding => 'Boarding — Track';

  @override
  String get bookingsSearchTrips => 'Search for a trip';

  @override
  String get paymentConfirming => 'Confirming payment…';

  @override
  String get paymentPleaseWait => 'Please wait a moment.';

  @override
  String get paymentTripLabel => 'Trip';

  @override
  String get paymentSeatsLabel => 'Seats';

  @override
  String get paymentTotalPaidLabel => 'Total paid';

  @override
  String get paymentTicketReady => 'Your ticket is confirmed and ready.';

  @override
  String get paymentGoHome => 'Back to home';

  @override
  String get paymentLoadingLabel => 'Loading…';

  @override
  String get paymentErrorMsg =>
      'Your payment was unsuccessful.\nNo amount was charged.';

  @override
  String get paymentGotoStationHint =>
      'If the issue persists, go to the station.';

  @override
  String get departureQuickSale => 'Quick sale';

  @override
  String get departuresNoneToday => 'No departures today';

  @override
  String get departureDriverMode => 'Driver mode';

  @override
  String get departureGpsSharingLabel => 'Sharing location live';

  @override
  String get departureGpsStop => 'Stop';

  @override
  String get departureSharePosition => 'Share your position with passengers';

  @override
  String get departurePaxSuffix => 'passengers';

  @override
  String departureManifestBtn(int count) {
    return 'Manifest · $count pax';
  }

  @override
  String get scanValidatedLabel => 'Ticket validated ✓';

  @override
  String get scanRejectedLabel => 'Ticket rejected';

  @override
  String get scanAlreadyBoarded => 'Ticket already boarded';

  @override
  String get scanVerifying => 'Verifying…';

  @override
  String get scanCenterQr => 'Center the QR code in the frame';

  @override
  String get scanAgentHeader => 'Agent · Scanner';

  @override
  String get scanNextTicket => 'Scan next';

  @override
  String get scanTryAgain2 => 'Retry';

  @override
  String get scanOfflineSyncNote => 'Offline · will sync';

  @override
  String get guichetSectionRoute => 'Route';

  @override
  String get guichetSectionDayTrips => 'Today\'s trips';

  @override
  String get guichetSectionSeats => 'Seats';

  @override
  String get guichetSectionPax => 'Passengers';

  @override
  String get guichetChooseSeats => 'Choose seats';

  @override
  String get guichetModify => 'Modify';

  @override
  String get guichetNoTripsAvailable => 'No trips available';

  @override
  String get guichetSaleSuccess => 'Sale successful!';

  @override
  String get guichetNewSale => 'New sale';

  @override
  String guichetCollectBtn(String amount) {
    return 'Collect · $amount F';
  }

  @override
  String get guichetSelectSeatsFirst => 'Select seats first';

  @override
  String get guichetPaymentSection => 'Payment';

  @override
  String get guichetDeparture => 'Departure';

  @override
  String get guichetArrival => 'Arrival';

  @override
  String get caisseDailyReport => 'Daily cashier report';

  @override
  String get caisseRevenueLabel => 'Revenue';

  @override
  String get caisseTicketsLabel => 'Tickets';

  @override
  String get caisseByMethod => 'By payment method';

  @override
  String get caisseTransactionsLabel => 'Transactions';

  @override
  String get caisseNoTransactions => 'No transactions';

  @override
  String get caisseTodayLabel => 'Today';

  @override
  String get dashboardManagement => 'Management';

  @override
  String get dashboardAnalysis => 'Analysis';

  @override
  String get dashboardDailyRevenue => 'Daily revenue';

  @override
  String get dashboardTotalRevenue => 'Total revenue';

  @override
  String get dashboardTotalTickets => 'Total tickets';

  @override
  String get dashboardDriversNav => 'Drivers';

  @override
  String get dashboardSchedulesNav => 'Schedules';

  @override
  String get dashboardStaffNav => 'Team';

  @override
  String get dashboardReportsNav => 'Reports';

  @override
  String get dashboardStationsNav => 'Stations';

  @override
  String get dashboardNetworkNav => 'Network';

  @override
  String get dashboardTripsNav => 'trips';

  @override
  String get dashboardRevenueMonth => 'Revenue (30d)';

  @override
  String get dashboardTicketsMonth => 'Tickets (30d)';

  @override
  String get dashboardVehiclesLabel => 'Vehicles';

  @override
  String get dashboardRoutesLabel => 'Routes';

  @override
  String get dashboardNoData => 'No data available';

  @override
  String get notifJustNow => 'Just now';

  @override
  String notifMinutesAgo(int n) {
    return '$n min ago';
  }

  @override
  String notifHoursAgo(int n) {
    return '${n}h ago';
  }

  @override
  String notifDaysAgo(int n) {
    return '${n}d ago';
  }

  @override
  String get tripsToday => 'Today';

  @override
  String get tripsTomorrow => 'Tomorrow';

  @override
  String get tripsThisWeek => 'This week';

  @override
  String get tripsManageTitle => 'Trip management';

  @override
  String get tripsNone => 'No trips';

  @override
  String get searchAllCompanies => 'All';

  @override
  String get searchCityHint => 'Search a city…';

  @override
  String get searchOriginHint => 'Where from?';

  @override
  String get searchDestHint => 'Where to?';

  @override
  String get searchLaunchPrompt => 'Start a search';

  @override
  String get searchLaunchSub => 'Choose your cities and date';

  @override
  String get searchMissingFields => 'Please select departure and destination.';

  @override
  String get searchInProgress => 'Searching…';

  @override
  String get bookingDetailTitle => 'Booking details';

  @override
  String get bookingRateYourReview => 'Your review';

  @override
  String get bookingRateThankYou => 'Thanks for your review!';

  @override
  String get bookingRateSubmit => 'Submit review';

  @override
  String get bookingPayPendingTitle => 'Payment pending';

  @override
  String get bookingPayPendingBody =>
      'This booking expires if payment is not completed in time.';

  @override
  String get bookingTicketsSection => 'Tickets';

  @override
  String get bookingBusEnRoute => 'Bus en route';

  @override
  String get bookingTrackBoardingSub => 'Track live departure';

  @override
  String get bookingShareTrip => 'Share this trip';

  @override
  String get tripInfoVehicle => 'Vehicle';

  @override
  String get tripInfoDepartureStation => 'Departure station';

  @override
  String get tripInfoArrivalStation => 'Arrival station';

  @override
  String get bookingQrInstruction =>
      'Show this QR code to the agent at boarding';

  @override
  String get bookingQrUnavailable => 'QR code unavailable';

  @override
  String get bookingRefPrefix => 'Ref';

  @override
  String get tripPassengersLabel => 'Passengers';

  @override
  String get bookingChooseSeats => 'Choose your seats';

  @override
  String get bookingModifySeats => 'Modify';

  @override
  String bookingPricePerSeat(String price) {
    return '$price F / seat';
  }

  @override
  String bookingConfirmAndPay(String amount) {
    return 'Confirm and pay · $amount F';
  }

  @override
  String get bookingSelectSeatsPrompt => 'Select your seats';

  @override
  String get bookingPaymentNote =>
      'Secure payment via GeniusPay · Orange Money, MTN MoMo, Wave and card accepted.';

  @override
  String get profileAccountSettings => 'Account settings';

  @override
  String get profileCurrentPassword => 'Current password';

  @override
  String get profileNewPassword => 'New password';

  @override
  String get profileConfirmNewPassword => 'Confirm new password';

  @override
  String get profilePasswordMin => 'Minimum 6 characters';

  @override
  String get profilePasswordChanged => 'Password updated';

  @override
  String get profileSaveChanges => 'Save changes';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get paymentSecureTitle => 'Secure payment';

  @override
  String get paymentLoadingWebview => 'Loading payment…';

  @override
  String get reload => 'Reload';

  @override
  String get companyCannotLoad => 'Failed to load company';

  @override
  String get companyTripsAvail => 'Available trips';

  @override
  String get companyLinesLabel => 'Lines';

  @override
  String get companyContact => 'Contact';

  @override
  String companyStationsCount(int n) {
    return 'Stations ($n)';
  }

  @override
  String companyRoutesCount(int n) {
    return 'Routes ($n)';
  }

  @override
  String get stationCannotLoad => 'Failed to load station';

  @override
  String get stationDeparturesLabel => 'Departures';

  @override
  String get stationGpsAvail => 'Available';

  @override
  String get stationPracticalInfo => 'Practical information';

  @override
  String get stationNavigateBtn => 'Navigate';

  @override
  String stationNextDepartures(int n) {
    return 'Next departures ($n)';
  }

  @override
  String get stationNoDepartures => 'No departures scheduled today';

  @override
  String stationSeats(int seats) {
    return '$seats seats';
  }

  @override
  String get navScreenLocationDenied =>
      'Location denied — enable it in settings';

  @override
  String get navScreenArrived => 'You have arrived!';

  @override
  String get navScreenNoDistance =>
      'Cannot calculate distance without location.';

  @override
  String get navScreenLocating => 'Locating…';

  @override
  String get navScreenDistance => 'Distance';

  @override
  String get navScreenWalking => 'On foot';

  @override
  String get tripTrackingTitle => 'Live tracking';

  @override
  String get tripTrackingWaiting => 'Waiting for location…';

  @override
  String get tripTrackingEta => 'Expected arrival';

  @override
  String get tripTrackingSteps => 'Steps';

  @override
  String tripTrackingOccupied(int occupied, int total) {
    return '$occupied/$total seats occupied';
  }

  @override
  String get tripSocketLive => '● Live';

  @override
  String get tripSocketConnecting => '○ Connecting…';

  @override
  String get tripSocketReconnecting => '○ Reconnecting…';

  @override
  String get tripSocketOffline => '✕ Offline';

  @override
  String get seatPickerTitle => 'Choose your seats';

  @override
  String get seatAvailableLabel => 'Available';

  @override
  String get seatSelectedLabel => 'Selected';

  @override
  String get seatOccupiedLabel => 'Occupied';

  @override
  String get seatFrontOfBus => 'Front of bus';

  @override
  String get seatSelectMin => 'Select at least 1 seat';

  @override
  String seatConfirmButton(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Confirm $count seats · $amount F',
      one: 'Confirm 1 seat · $amount F',
    );
    return '$_temp0';
  }

  @override
  String get agentGpsEnableHint => 'Enable GPS in settings';

  @override
  String get manifestSearchHint => 'Search a passenger or seat…';

  @override
  String manifestMissingAlert(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count passengers not boarded',
      one: '$count passenger not boarded',
    );
    return '$_temp0';
  }

  @override
  String get manifestNoPassengers => 'No passengers';

  @override
  String get noResults => 'No results';

  @override
  String quickSaleTicketCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tickets',
      one: '$count ticket',
    );
    return '$_temp0';
  }

  @override
  String get payMethodCash => 'Cash';

  @override
  String get agentStationLabel => 'Assigned station';

  @override
  String get agentInfoSection => 'Information';

  @override
  String get schedulesNoSchedules => 'No schedules';

  @override
  String get schedulesAdd => 'Add a schedule';

  @override
  String get schedulesNew => 'New schedule';

  @override
  String get schedulesCreate => 'Create schedule';

  @override
  String get scheduleDays => 'Days';

  @override
  String get scheduleRouteLabel => 'Route';

  @override
  String get scheduleSelectRoute => 'Select a route';

  @override
  String get scheduleDepartureTime => 'Departure time';

  @override
  String get staffNoMembers => 'No staff members';

  @override
  String get staffInviteAgent => 'Invite an agent';

  @override
  String get staffInvite => 'Invite';

  @override
  String get staffInviteMember => 'Invite a member';

  @override
  String get staffSendInvite => 'Send invitation';

  @override
  String get staffInviteSent => 'Invitation sent';

  @override
  String get staffRoleLabel => 'Role';

  @override
  String get staffStationOptional => 'Assigned station (optional)';

  @override
  String get stationsNone => 'No stations';

  @override
  String get stationsAdd => 'Add a station';

  @override
  String get stationsNew => 'New station';

  @override
  String get stationsCreate => 'Create station';

  @override
  String get stationsPrimary => 'Primary';

  @override
  String get stationsSetPrimary => 'Set as primary';

  @override
  String get stationsPrimaryCannotDelete => 'Primary station cannot be deleted';

  @override
  String stationsAgentCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n agents',
      one: '$n agent',
    );
    return '$_temp0';
  }

  @override
  String get stationsPrimaryLabel => 'Primary station';

  @override
  String get stationsPrimarySubtitle => 'Default station for your account';

  @override
  String get stationsName => 'Station name';

  @override
  String get stationsDeleteTitle => 'Delete station';

  @override
  String get reportsPeriod365d => '1 year';

  @override
  String get reportsBookingsSection => 'Bookings';

  @override
  String get reportsTotalBookings => 'Total bookings';

  @override
  String get reportsExport => 'Export';

  @override
  String get reportsExportError => 'Export failed';

  @override
  String get reportsByStatus => 'By status';

  @override
  String reportsExportSubject(String format) {
    return 'TransPro report ($format)';
  }

  @override
  String get fleetStatusOutOfService => 'Out of service';

  @override
  String get fleetActivate => 'Activate';

  @override
  String get fleetDeactivate => 'Deactivate';

  @override
  String get fleetMaintenanceOilChange => 'Oil change';

  @override
  String get fleetMaintenanceTireRotation => 'Tire rotation';

  @override
  String get fleetMaintenanceBrakeService => 'Brakes';

  @override
  String get fleetMaintenanceFilterChange => 'Filter change';

  @override
  String get fleetMaintenanceMajorService => 'Major service';

  @override
  String get fleetMaintenanceRepair => 'Repair';

  @override
  String get fleetMaintenanceInspection => 'Inspection';

  @override
  String get fleetFuelLiters => 'Liters';

  @override
  String get fleetFuelTotalCost => 'Total cost';

  @override
  String get fleetOdometer => 'Mileage';

  @override
  String get fleetFuelStationLabel => 'Station';

  @override
  String get fleetDescriptionLabel => 'Description';

  @override
  String get fleetCostLabel => 'Cost';

  @override
  String get fleetGarageLabel => 'Garage';

  @override
  String get fleetDeleteFuelTitle => 'Delete this refuel?';

  @override
  String get fleetDeleteMaintenanceTitle => 'Delete this service?';

  @override
  String get fleetTypeLabel => 'Type';

  @override
  String get notDefined => 'Not set';

  @override
  String get driverSingularLabel => 'Driver';

  @override
  String get driverEvaluateTitle => 'Evaluate driver';

  @override
  String get driverAddAbsenceTitle => 'Record absence';

  @override
  String driverEvalCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n evaluations',
      one: '$n evaluation',
    );
    return '$_temp0';
  }

  @override
  String driverEvalBy(String name) {
    return 'By $name';
  }

  @override
  String get driverAbsenceStartDate => 'Start';

  @override
  String get driverAbsenceEndDate => 'End';

  @override
  String get driverAbsenceSelectDates => 'Select the dates';

  @override
  String get driverAbsenceReasonOptional => 'Reason (optional)';

  @override
  String get routeDeactivate => 'Deactivate';

  @override
  String get routeActivate => 'Activate';

  @override
  String routeSchedulesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n schedules',
      one: '$n schedule',
    );
    return '$_temp0';
  }

  @override
  String get routeNew => 'New route';

  @override
  String get routeNameLabel => 'Route name';

  @override
  String get routeOriginCity => 'Origin city';

  @override
  String get routeDestCity => 'Destination city';

  @override
  String get routeDistance => 'Distance (km)';

  @override
  String get routeDuration => 'Duration (min)';

  @override
  String get routeBasePrice => 'Base price (FCFA)';

  @override
  String get routeSelectCities => 'Select the cities';

  @override
  String get profileNameLabel => 'Name';

  @override
  String get profileAddressLabel => 'Address';

  @override
  String get profileRccmLabel => 'RCCM';

  @override
  String get profileCompanyName => 'Company name';

  @override
  String get profileEditCompany => 'Edit company';

  @override
  String get fleetNewVehicle => 'New vehicle';

  @override
  String get fleetClass => 'Class';

  @override
  String get invalidNumber => 'Invalid number';

  @override
  String get companiesTitle => 'Companies';

  @override
  String get companiesSearchHint => 'Search a company…';

  @override
  String get favoritesTitle => 'Favorites';

  @override
  String get favoritesCompanies => 'Favorite companies';

  @override
  String get favoritesStations => 'Favorite stations';

  @override
  String get favoritesNoCompanies => 'No favorite companies yet';

  @override
  String get favoritesNoStations => 'No favorite stations yet';

  @override
  String get homeFavoriteCompanies => 'My favorite companies';

  @override
  String get transactionsTitle => 'My transactions';

  @override
  String get transactionsEmpty => 'No transactions yet';

  @override
  String get transactionsEmptySub => 'Your payments will appear here.';

  @override
  String get transactionsFilterAll => 'All';

  @override
  String get transactionsFilterSuccess => 'Successful';

  @override
  String get transactionsFilterFailed => 'Failed';

  @override
  String get transactionsFilterPending => 'Pending';

  @override
  String get transactionsTotalSpent => 'Total spent';

  @override
  String transactionsCount(int count) {
    return '$count transaction(s)';
  }

  @override
  String get transactionsMethodCash => 'Cash';

  @override
  String get transactionsMethodMobile => 'Mobile Money';

  @override
  String get transactionsMethodCard => 'Card';

  @override
  String get transactionsStatusSuccess => 'Successful';

  @override
  String get transactionsStatusFailed => 'Failed';

  @override
  String get transactionsStatusProcessing => 'Processing';

  @override
  String get transactionsStatusPending => 'Pending';

  @override
  String transactionsRef(String ref) {
    return 'Ref. $ref';
  }

  @override
  String transactionsSeats(int count) {
    return '$count seat(s)';
  }

  @override
  String get transactionsDrawerLabel => 'My transactions';
}
