// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'TransPro CI';

  @override
  String get connectivityOffline => 'Pas de connexion internet';

  @override
  String get connectivityNoInternet => 'Aucun accès à internet';

  @override
  String get connectivityRestored => 'Connexion rétablie';

  @override
  String get connectivityActionOffline =>
      'Cette action nécessite une connexion internet';

  @override
  String get save => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get confirm => 'Confirmer';

  @override
  String get delete => 'Supprimer';

  @override
  String get edit => 'Modifier';

  @override
  String get add => 'Ajouter';

  @override
  String get back => 'Retour';

  @override
  String get close => 'Fermer';

  @override
  String get retry => 'Réessayer';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get ok => 'OK';

  @override
  String get see => 'Voir';

  @override
  String get required => 'Requis';

  @override
  String get loading => 'Chargement…';

  @override
  String get error => 'Une erreur est survenue';

  @override
  String get errorNetwork => 'Erreur réseau. Vérifiez votre connexion.';

  @override
  String get errorServer => 'Erreur serveur. Veuillez réessayer.';

  @override
  String get errorUnknown => 'Erreur inconnue';

  @override
  String get successSaved => 'Enregistré avec succès';

  @override
  String get successDeleted => 'Supprimé avec succès';

  @override
  String get confirmDeleteTitle => 'Supprimer ?';

  @override
  String get confirmDeleteBody => 'Cette action est irréversible.';

  @override
  String get optional => 'optionnel';

  @override
  String get search => 'Rechercher';

  @override
  String get filter => 'Filtrer';

  @override
  String get from => 'De';

  @override
  String get to => 'Vers';

  @override
  String get date => 'Date';

  @override
  String get time => 'Heure';

  @override
  String get price => 'Prix';

  @override
  String get total => 'Total';

  @override
  String get status => 'Statut';

  @override
  String get details => 'Détails';

  @override
  String get none => 'Aucun';

  @override
  String get notAvailable => 'N/A';

  @override
  String get loginTitle => 'Bon retour';

  @override
  String get loginSubtitle => 'Connectez-vous à votre compte TransPro';

  @override
  String get emailLabel => 'Adresse e-mail';

  @override
  String get emailHint => 'exemple@email.com';

  @override
  String get passwordLabel => 'Mot de passe';

  @override
  String get passwordHint => 'Votre mot de passe';

  @override
  String get loginButton => 'Se connecter';

  @override
  String get forgotPasswordLink => 'Mot de passe oublié ?';

  @override
  String get noAccountText => 'Pas encore de compte ?';

  @override
  String get registerLink => 'En créer un';

  @override
  String get loginError => 'Email ou mot de passe incorrect';

  @override
  String get registerTitle => 'Créer un compte';

  @override
  String get registerSubtitle => 'Rejoignez TransPro CI';

  @override
  String get firstNameLabel => 'Prénom';

  @override
  String get firstNameHint => 'Kouassi';

  @override
  String get lastNameLabel => 'Nom';

  @override
  String get lastNameHint => 'Koffi';

  @override
  String get phoneLabel => 'Numéro de téléphone';

  @override
  String get phoneHint => '+225 07 00 00 00 00';

  @override
  String get confirmPasswordLabel => 'Confirmer le mot de passe';

  @override
  String get confirmPasswordHint => 'Répétez votre mot de passe';

  @override
  String get passwordMismatch => 'Les mots de passe ne correspondent pas';

  @override
  String get registerButton => 'Créer le compte';

  @override
  String get alreadyHaveAccount => 'Déjà un compte ?';

  @override
  String get loginLink => 'Se connecter';

  @override
  String get forgotPasswordTitle => 'Mot de passe oublié ?';

  @override
  String get forgotPasswordSubtitle =>
      'Saisissez votre e-mail, nous vous enverrons un lien de réinitialisation';

  @override
  String get sendResetLink => 'Envoyer le lien';

  @override
  String get backToLogin => 'Retour à la connexion';

  @override
  String get resetEmailSent => 'E-mail envoyé ! Vérifiez votre boîte.';

  @override
  String get pinLoginTitle => 'Code PIN';

  @override
  String get pinLoginSubtitle => 'Saisissez votre code à 4 chiffres';

  @override
  String get pinLockedTitle => 'Compte verrouillé';

  @override
  String get pinLockedError =>
      'Trop de tentatives échouées. Utilisez votre mot de passe.';

  @override
  String pinWrongError(int attempts, int max) {
    return 'Code PIN incorrect ($attempts/$max tentatives)';
  }

  @override
  String get pinSignInAnother => 'Se connecter autrement';

  @override
  String get pinSetupTitle => 'Choisissez un code PIN';

  @override
  String get pinSetupSubtitle => 'Ce code sécurisera l\'accès à l\'application';

  @override
  String get pinConfirmTitle => 'Confirmez votre code PIN';

  @override
  String get pinConfirmSubtitle =>
      'Saisissez à nouveau le même code à 4 chiffres';

  @override
  String get pinMismatch => 'Les codes PIN ne correspondent pas. Réessayez.';

  @override
  String get pinSetupBiometricLabel => 'Activer la biométrie';

  @override
  String get pinSetupBiometricSub => 'Empreinte digitale / Face ID';

  @override
  String get pinRetry => 'Recommencer';

  @override
  String get biometricReason => 'Déverrouillez TransPro avec votre biométrie';

  @override
  String get onboardingSkip => 'Passer';

  @override
  String get onboardingNext => 'Suivant';

  @override
  String get onboardingStart => 'Commencer';

  @override
  String get onboarding1Title => 'Trouvez votre trajet';

  @override
  String get onboarding1Body =>
      'Recherchez parmi des centaines de trajets disponibles partout en Côte d\'Ivoire. Choisissez votre date, votre ville de départ et de destination.';

  @override
  String get onboarding2Title => 'Choisissez votre siège';

  @override
  String get onboarding2Body =>
      'Sélectionnez votre place dans le véhicule selon vos préférences. Fenêtre, couloir, classe VIP — tout est à portée de main.';

  @override
  String get onboarding3Title => 'Payez en toute sécurité';

  @override
  String get onboarding3Body =>
      'Réglez votre billet par Orange Money, MTN MoMo, Wave ou en espèces. Votre QR code est disponible hors-ligne pour l\'embarquement.';

  @override
  String get navHome => 'Accueil';

  @override
  String get navSearch => 'Recherche';

  @override
  String get navTickets => 'Billets';

  @override
  String get navProfile => 'Profil';

  @override
  String get navDepartures => 'Départs';

  @override
  String get navScanner => 'Scanner';

  @override
  String get navGuichet => 'Guichet';

  @override
  String get navCaisse => 'Caisse';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navTrips => 'Voyages';

  @override
  String get navFleet => 'Flotte';

  @override
  String get navRoutes => 'Réseau';

  @override
  String get settingsAppearance => 'Apparence & Sécurité';

  @override
  String get settingsTheme => 'Thème';

  @override
  String get settingsThemeSystem => 'Système';

  @override
  String get settingsThemeLight => 'Clair';

  @override
  String get settingsThemeDark => 'Sombre';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsBiometric => 'Biométrie';

  @override
  String get settingsBiometricSub => 'Empreinte digitale / Face ID';

  @override
  String get settingsAccount => 'Paramètres du compte';

  @override
  String get settingsEditProfile => 'Modifier le profil';

  @override
  String get settingsChangePassword => 'Changer le mot de passe';

  @override
  String get settingsLogout => 'Déconnexion';

  @override
  String get settingsLogoutConfirm => 'Déconnexion';

  @override
  String get settingsLogoutBody => 'Voulez-vous vraiment vous déconnecter ?';

  @override
  String get settingsLogoutCancel => 'Annuler';

  @override
  String get settingsQuickNav => 'Navigation rapide';

  @override
  String get passengerRole => 'Passager';

  @override
  String get agentRole => 'Agent';

  @override
  String get ownerRole => 'Propriétaire';

  @override
  String get adminRole => 'Administrateur';

  @override
  String get homeGreetingMorning => 'Bonjour';

  @override
  String get homeGreetingAfternoon => 'Bon après-midi';

  @override
  String get homeGreetingEvening => 'Bonsoir';

  @override
  String get homeSearchPlaceholder => 'Où allez-vous ?';

  @override
  String get homeRecentSearches => 'Recherches récentes';

  @override
  String get homePopularRoutes => 'Trajets populaires';

  @override
  String get searchFromCity => 'Ville de départ';

  @override
  String get searchToCity => 'Ville d\'arrivée';

  @override
  String get searchSelectDate => 'Sélectionner une date';

  @override
  String get searchPassengerCount => 'Nombre de passagers';

  @override
  String get searchButtonLabel => 'Rechercher des trajets';

  @override
  String get searchResults => 'Trajets disponibles';

  @override
  String get searchNoResults => 'Aucun trajet trouvé pour cet itinéraire';

  @override
  String get searchTryOther => 'Essayez d\'autres dates ou villes';

  @override
  String searchSeat(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'places',
      one: 'place',
    );
    return '$_temp0';
  }

  @override
  String get tripDeparture => 'Départ';

  @override
  String get tripArrival => 'Arrivée';

  @override
  String get tripDuration => 'Durée';

  @override
  String get tripAvailable => 'Disponible';

  @override
  String get tripClass => 'Classe';

  @override
  String get tripClassStandard => 'Standard';

  @override
  String get tripClassVip => 'VIP';

  @override
  String get tripClassExpress => 'Express';

  @override
  String get tripStatusScheduled => 'Planifié';

  @override
  String get tripStatusBoarding => 'Embarquement';

  @override
  String get tripStatusDeparted => 'Parti';

  @override
  String get tripStatusArrived => 'Arrivé';

  @override
  String get tripStatusCancelled => 'Annulé';

  @override
  String get tripBook => 'Réserver';

  @override
  String get tripSelectSeat => 'Choisir un siège';

  @override
  String get tripSeatOccupied => 'Occupé';

  @override
  String get tripSeatAvailable => 'Disponible';

  @override
  String get tripSeatBlocked => 'Bloqué';

  @override
  String get tripSeatYours => 'Votre siège';

  @override
  String get tripConfirmBooking => 'Confirmer la réservation';

  @override
  String get tripPassengerInfo => 'Informations passager';

  @override
  String get bookingsTitle => 'Mes billets';

  @override
  String get bookingsNoBookings => 'Aucun billet pour l\'instant';

  @override
  String get bookingsNoBookingsSub => 'Vos voyages réservés apparaîtront ici';

  @override
  String get bookingStatusConfirmed => 'Confirmé';

  @override
  String get bookingStatusPending => 'En attente';

  @override
  String get bookingStatusUpcoming => 'À venir';

  @override
  String get bookingStatusCompleted => 'Terminé';

  @override
  String get bookingStatusCancelled => 'Annulé';

  @override
  String get bookingRef => 'Référence';

  @override
  String get bookingSeats => 'Sièges';

  @override
  String get bookingTotal => 'Total payé';

  @override
  String get bookingDownload => 'Télécharger le billet';

  @override
  String get bookingShare => 'Partager';

  @override
  String get bookingCancel => 'Annuler la réservation';

  @override
  String get bookingCancelConfirm => 'Annuler cette réservation ?';

  @override
  String get bookingRateTrip => 'Évaluer ce trajet';

  @override
  String get bookingRateTitle => 'Comment s\'est passé votre voyage ?';

  @override
  String get bookingRateComment => 'Votre commentaire (optionnel)';

  @override
  String get bookingPayNow => 'Payer maintenant';

  @override
  String get bookingPaid => 'Payé';

  @override
  String get bookingPending => 'Paiement en attente';

  @override
  String bookingSeatNumber(String seat) {
    return 'Siège $seat';
  }

  @override
  String get paymentTitle => 'Paiement';

  @override
  String get paymentChooseMethod => 'Choisissez un mode de paiement';

  @override
  String get paymentProcessing => 'Traitement du paiement…';

  @override
  String get paymentSuccess => 'Paiement réussi !';

  @override
  String get paymentSuccessSub => 'Votre billet est confirmé.';

  @override
  String get paymentFailed => 'Paiement échoué';

  @override
  String get paymentFailedSub =>
      'Veuillez réessayer ou utiliser un autre moyen.';

  @override
  String get paymentGoToTicket => 'Voir mon billet';

  @override
  String get paymentRetry => 'Réessayer';

  @override
  String get scanTitle => 'Scanner de billets';

  @override
  String get scanInstruction => 'Positionnez le QR code dans le cadre';

  @override
  String get scanSuccess => 'Billet validé';

  @override
  String get scanInvalid => 'Billet invalide ou non reconnu';

  @override
  String get scanAlreadyUsed => 'Billet déjà validé';

  @override
  String get scanOfflineBadge => 'Hors-ligne · sera synchronisé';

  @override
  String get scanOfflineMode => 'Mode hors-ligne actif';

  @override
  String get scanResult => 'Résultat du scan';

  @override
  String get scanSeatLabel => 'Siège';

  @override
  String get scanTripLabel => 'Trajet';

  @override
  String get scanPassengerLabel => 'Passager';

  @override
  String get scanScanAnother => 'Scanner un autre';

  @override
  String get departuresTitle => 'Départs du jour';

  @override
  String get departuresNone => 'Aucun départ programmé';

  @override
  String get departureSeeManifest => 'Manifeste';

  @override
  String get departureDownloadOffline => 'Télécharger hors-ligne';

  @override
  String get departureOfflineReady => 'Prêt hors-ligne';

  @override
  String departureCountdown(String time) {
    return 'dans $time';
  }

  @override
  String get manifestTitle => 'Liste des passagers';

  @override
  String get manifestScanned => 'Scanné';

  @override
  String get manifestNotScanned => 'Non scanné';

  @override
  String get manifestMissing => 'Passagers manquants';

  @override
  String manifestTotal(int scanned, int total) {
    return '$scanned/$total passagers';
  }

  @override
  String get manifestCallPassenger => 'Appeler';

  @override
  String get quickSaleTitle => 'Vente rapide';

  @override
  String get quickSaleSelectTrip => 'Sélectionner un départ';

  @override
  String get quickSaleQty => 'Quantité';

  @override
  String get quickSalePayMethod => 'Mode de paiement';

  @override
  String quickSaleCollect(String amount) {
    return 'Encaisser $amount F';
  }

  @override
  String get quickSaleSuccess => 'Paiement encaissé';

  @override
  String get quickSaleNew => 'Nouvelle vente';

  @override
  String get quickSaleBackToDepartures => 'Retour aux départs';

  @override
  String get guichetTitle => 'Guichet';

  @override
  String get caisseTitle => 'Caisse du jour';

  @override
  String get dashboardTitle => 'Tableau de bord';

  @override
  String get dashboardRevenue => 'Chiffre d\'affaires';

  @override
  String get dashboardTrips => 'Voyages';

  @override
  String get dashboardOccupancy => 'Taux de remplissage';

  @override
  String get dashboardPassengers => 'Passagers';

  @override
  String get dashboardPeriod7d => '7 jours';

  @override
  String get dashboardPeriod30d => '30 jours';

  @override
  String get dashboardPeriod90d => '90 jours';

  @override
  String get dashboardTopRoutes => 'Top lignes';

  @override
  String get dashboardFillRate => 'Taux de remplissage par ligne';

  @override
  String get fleetTitle => 'Flotte';

  @override
  String get fleetAddVehicle => 'Ajouter un véhicule';

  @override
  String get fleetNoVehicles => 'Aucun véhicule enregistré';

  @override
  String get fleetPlate => 'Plaque';

  @override
  String get fleetBrand => 'Marque';

  @override
  String get fleetModel => 'Modèle';

  @override
  String get fleetYear => 'Année';

  @override
  String get fleetCapacity => 'Capacité';

  @override
  String get fleetStatusActive => 'Actif';

  @override
  String get fleetStatusInactive => 'Inactif';

  @override
  String get fleetStatusMaintenance => 'Maintenance';

  @override
  String get fleetFuelTab => 'Carburant';

  @override
  String get fleetMaintenanceTab => 'Entretien';

  @override
  String get fleetNoFuelLogs => 'Aucun plein enregistré';

  @override
  String get fleetNoMaintenanceLogs => 'Aucun entretien enregistré';

  @override
  String get fleetAddFuel => 'Enregistrer un plein';

  @override
  String get fleetAddMaintenance => 'Enregistrer un entretien';

  @override
  String get fleetNextService => 'Prochain entretien';

  @override
  String get driversTitle => 'Chauffeurs';

  @override
  String get driversAddDriver => 'Ajouter un chauffeur';

  @override
  String get driversNoDrivers => 'Aucun chauffeur enregistré';

  @override
  String get driverLicenseExpiry => 'Expiration permis';

  @override
  String get driverLicenseExpired => 'Expiré';

  @override
  String get driverLicenseExpiringSoon => 'Bientôt';

  @override
  String get driverAvailable => 'Disponible';

  @override
  String get driverUnavailable => 'Indisponible';

  @override
  String get driverScheduleTab => 'Planning mensuel';

  @override
  String get driverAbsencesTab => 'Absences';

  @override
  String get driverEvaluationsTab => 'Évaluations';

  @override
  String get driverNoTrips => 'Aucun trajet ce mois-ci';

  @override
  String get driverNoAbsences => 'Aucune absence enregistrée';

  @override
  String get driverNoEvaluations => 'Aucune évaluation pour ce chauffeur';

  @override
  String get driverAddAbsence => 'Enregistrer une absence';

  @override
  String get driverAddEvaluation => 'Évaluer';

  @override
  String get driverAbsenceLeave => 'Congé';

  @override
  String get driverAbsenceSick => 'Maladie';

  @override
  String get driverAbsenceOther => 'Autre';

  @override
  String get driverAbsenceApprove => 'Approuver';

  @override
  String get driverAbsenceApproved => 'Approuvée';

  @override
  String get driverAbsencePending => 'En attente';

  @override
  String get driverAbsenceReason => 'Motif';

  @override
  String get driverEvalOverall => 'Note globale';

  @override
  String get driverEvalPunctuality => 'Ponctualité';

  @override
  String get driverEvalSafety => 'Sécurité';

  @override
  String get driverEvalService => 'Service';

  @override
  String get driverEvalComment => 'Commentaire (optionnel)';

  @override
  String get driverEvalAverageRating => 'Note moyenne';

  @override
  String get routesTitle => 'Réseau';

  @override
  String get routesNoRoutes => 'Aucune ligne définie';

  @override
  String get routesAddRoute => 'Ajouter une ligne';

  @override
  String get schedulesTitle => 'Grilles horaires';

  @override
  String get staffTitle => 'Équipe';

  @override
  String get stationsTitle => 'Gares';

  @override
  String get reportsTitle => 'Rapports';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsNone => 'Aucune notification';

  @override
  String get notificationsMarkAllRead => 'Tout marquer comme lu';

  @override
  String get profileTitle => 'Mon profil';

  @override
  String get profilePersonalInfo => 'Informations personnelles';

  @override
  String get profileCompany => 'Entreprise';

  @override
  String get languageAuto => 'Système (auto)';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeSystem => 'Système';

  @override
  String get appTagline => 'Votre voyage en main';

  @override
  String get loginOr => 'ou';

  @override
  String get seeAll => 'Voir tout';

  @override
  String get validationEmailInvalid => 'Email invalide';

  @override
  String get validationPhoneInvalid => 'Numéro invalide (8 chiffres min.)';

  @override
  String get validationPasswordMin => 'Minimum 8 caractères';

  @override
  String get registerFormTitle => 'Vos informations';

  @override
  String get registerFormSub => 'Remplissez tous les champs pour continuer';

  @override
  String get registerTerms =>
      'En créant un compte, vous acceptez nos conditions d\'utilisation.';

  @override
  String get registerPassengerSubtitle => 'Créer un compte passager';

  @override
  String get forgotSentTitle => 'Email envoyé !';

  @override
  String get forgotSentBody =>
      'Si cet email est enregistré, vous recevrez un lien de réinitialisation.';

  @override
  String get forgotSpamNote => 'Vérifiez également votre dossier spam.';

  @override
  String get forgotInstruction =>
      'Entrez votre email pour recevoir un lien de réinitialisation.';

  @override
  String homeGreeting(String name) {
    return 'Bonjour, $name';
  }

  @override
  String get homeWhereToGo => 'Où allez-vous ?';

  @override
  String get homeSearchHint => 'Rechercher un voyage…';

  @override
  String get homeUpcomingDepartures => 'Prochains départs';

  @override
  String get homeNextDeparture => 'Prochain départ';

  @override
  String get homeAwaitingPayment => 'En attente de paiement';

  @override
  String get homeViewTickets => 'Voir les billets';

  @override
  String get homeNoTripsTitle => 'Aucun voyage disponible';

  @override
  String get homeNoTripsSub => 'Revenez plus tard ou modifiez vos critères.';

  @override
  String get homeAlerts => 'Alertes';

  @override
  String get homeBoardingStatus => 'Embarquement';

  @override
  String get homeBookNow => 'Réserver';

  @override
  String get homeHistory => 'Historique';

  @override
  String get homeNextTripTitle => 'Mon prochain voyage';

  @override
  String get homeAnyCompany => 'Toutes les compagnies';

  @override
  String get searchCompany => 'Compagnie';

  @override
  String get homePopularDestinations => 'Destinations populaires';

  @override
  String get homePartners => 'Compagnies partenaires';

  @override
  String homePartnersCount(int count) {
    return '$count compagnies vous font confiance';
  }

  @override
  String homeFromPrice(String price) {
    return 'dès $price F';
  }

  @override
  String homeTripsAvailable(int count) {
    return '$count départs';
  }

  @override
  String homeDepartsInDays(int days) {
    return 'Départ dans $days j';
  }

  @override
  String homeDepartsInHM(int h, int m) {
    return 'Départ dans ${h}h ${m}min';
  }

  @override
  String homeDepartsInMin(int m) {
    return 'Départ dans ${m}min';
  }

  @override
  String get homeDepartingNow => 'Départ imminent';

  @override
  String get bookingsOfflineMode => 'Mode hors-ligne — billets mis en cache';

  @override
  String get bookingsPendingPay => 'Paiement en attente — appuyez pour payer';

  @override
  String get bookingsTrackLive => 'Suivre en direct';

  @override
  String get bookingsTrackBoarding => 'Embarquement — Suivre';

  @override
  String get bookingsSearchTrips => 'Rechercher un voyage';

  @override
  String get paymentConfirming => 'Confirmation du paiement…';

  @override
  String get paymentPleaseWait => 'Merci de patienter quelques instants.';

  @override
  String get paymentTripLabel => 'Trajet';

  @override
  String get paymentSeatsLabel => 'Sièges';

  @override
  String get paymentTotalPaidLabel => 'Total payé';

  @override
  String get paymentTicketReady => 'Votre billet est confirmé et prêt.';

  @override
  String get paymentGoHome => 'Retour à l\'accueil';

  @override
  String get paymentLoadingLabel => 'Chargement…';

  @override
  String get paymentErrorMsg =>
      'Votre paiement n\'a pas abouti.\nAucun montant n\'a été débité.';

  @override
  String get paymentGotoStationHint =>
      'Si le problème persiste, présentez-vous à la gare.';

  @override
  String get departureQuickSale => 'Vente rapide';

  @override
  String get departuresNoneToday => 'Aucun départ aujourd\'hui';

  @override
  String get departureDriverMode => 'Mode conducteur';

  @override
  String get departureGpsSharingLabel => 'Position partagée en direct';

  @override
  String get departureGpsStop => 'Arrêter';

  @override
  String get departureSharePosition => 'Partagez votre position aux passagers';

  @override
  String get departurePaxSuffix => 'passagers';

  @override
  String departureManifestBtn(int count) {
    return 'Manifeste · $count pax';
  }

  @override
  String get scanValidatedLabel => 'Billet validé ✓';

  @override
  String get scanRejectedLabel => 'Billet refusé';

  @override
  String get scanAlreadyBoarded => 'Billet déjà embarqué';

  @override
  String get scanVerifying => 'Vérification…';

  @override
  String get scanCenterQr => 'Centrez le QR code dans le cadre';

  @override
  String get scanAgentHeader => 'Agent · Scanner';

  @override
  String get scanNextTicket => 'Scanner le suivant';

  @override
  String get scanTryAgain2 => 'Réessayer';

  @override
  String get scanOfflineSyncNote => 'Hors-ligne · sera synchronisé';

  @override
  String get guichetSectionRoute => 'Trajet';

  @override
  String get guichetSectionDayTrips => 'Voyage du jour';

  @override
  String get guichetSectionSeats => 'Sièges';

  @override
  String get guichetSectionPax => 'Passagers';

  @override
  String get guichetChooseSeats => 'Choisir les sièges';

  @override
  String get guichetModify => 'Modifier';

  @override
  String get guichetNoTripsAvailable => 'Aucun voyage disponible';

  @override
  String get guichetSaleSuccess => 'Vente réussie !';

  @override
  String get guichetNewSale => 'Nouvelle vente';

  @override
  String guichetCollectBtn(String amount) {
    return 'Encaisser · $amount F';
  }

  @override
  String get guichetSelectSeatsFirst => 'Sélectionnez les sièges';

  @override
  String get guichetPaymentSection => 'Paiement';

  @override
  String get guichetDeparture => 'Départ';

  @override
  String get guichetArrival => 'Arrivée';

  @override
  String get caisseDailyReport => 'Rapport de caisse';

  @override
  String get caisseRevenueLabel => 'Recettes';

  @override
  String get caisseTicketsLabel => 'Billets';

  @override
  String get caisseByMethod => 'Par mode de paiement';

  @override
  String get caisseTransactionsLabel => 'Transactions';

  @override
  String get caisseNoTransactions => 'Aucune transaction';

  @override
  String get caisseTodayLabel => 'Aujourd\'hui';

  @override
  String get dashboardManagement => 'Gestion';

  @override
  String get dashboardAnalysis => 'Analyse';

  @override
  String get dashboardDailyRevenue => 'Recettes par jour';

  @override
  String get dashboardTotalRevenue => 'Total recettes';

  @override
  String get dashboardTotalTickets => 'Total billets';

  @override
  String get dashboardDriversNav => 'Conducteurs';

  @override
  String get dashboardSchedulesNav => 'Horaires';

  @override
  String get dashboardStaffNav => 'Personnel';

  @override
  String get dashboardReportsNav => 'Rapports';

  @override
  String get dashboardStationsNav => 'Gares';

  @override
  String get dashboardNetworkNav => 'Réseau';

  @override
  String get dashboardTripsNav => 'voyages';

  @override
  String get dashboardRevenueMonth => 'Recettes (30j)';

  @override
  String get dashboardTicketsMonth => 'Billets (30j)';

  @override
  String get dashboardVehiclesLabel => 'Véhicules';

  @override
  String get dashboardRoutesLabel => 'Itinéraires';

  @override
  String get dashboardNoData => 'Aucune donnée';

  @override
  String get notifJustNow => 'À l\'instant';

  @override
  String notifMinutesAgo(int n) {
    return 'Il y a $n min';
  }

  @override
  String notifHoursAgo(int n) {
    return 'Il y a $n h';
  }

  @override
  String notifDaysAgo(int n) {
    return 'Il y a $n j';
  }

  @override
  String get tripsToday => 'Aujourd\'hui';

  @override
  String get tripsTomorrow => 'Demain';

  @override
  String get tripsThisWeek => 'Cette semaine';

  @override
  String get tripsManageTitle => 'Gestion des voyages';

  @override
  String get tripsNone => 'Aucun voyage';

  @override
  String get searchAllCompanies => 'Toutes';

  @override
  String get searchCityHint => 'Rechercher une ville…';

  @override
  String get searchOriginHint => 'D\'où partez-vous ?';

  @override
  String get searchDestHint => 'Où allez-vous ?';

  @override
  String get searchLaunchPrompt => 'Lancez une recherche';

  @override
  String get searchLaunchSub => 'Choisissez vos villes et la date';

  @override
  String get searchMissingFields =>
      'Veuillez sélectionner départ et destination.';

  @override
  String get searchInProgress => 'Recherche en cours…';

  @override
  String get bookingDetailTitle => 'Détail de la réservation';

  @override
  String get bookingRateYourReview => 'Votre avis';

  @override
  String get bookingRateThankYou => 'Merci pour votre avis !';

  @override
  String get bookingRateSubmit => 'Envoyer mon avis';

  @override
  String get bookingPayPendingTitle => 'Paiement en attente';

  @override
  String get bookingPayPendingBody =>
      'Cette réservation expire si le paiement n\'est pas effectué dans les délais.';

  @override
  String get bookingTicketsSection => 'Billets';

  @override
  String get bookingBusEnRoute => 'Bus en route';

  @override
  String get bookingTrackBoardingSub => 'Suivre le départ en direct';

  @override
  String get bookingShareTrip => 'Partager ce voyage';

  @override
  String get tripInfoVehicle => 'Véhicule';

  @override
  String get tripInfoDepartureStation => 'Gare de départ';

  @override
  String get tripInfoArrivalStation => 'Gare d\'arrivée';

  @override
  String get bookingQrInstruction =>
      'Présentez ce QR code à l\'agent à l\'embarquement';

  @override
  String get bookingQrUnavailable => 'QR code indisponible';

  @override
  String get bookingRefPrefix => 'Réf';

  @override
  String get tripPassengersLabel => 'Passagers';

  @override
  String get bookingChooseSeats => 'Choisir vos sièges';

  @override
  String get bookingModifySeats => 'Modifier';

  @override
  String bookingPricePerSeat(String price) {
    return '$price F / siège';
  }

  @override
  String bookingConfirmAndPay(String amount) {
    return 'Confirmer et payer · $amount F';
  }

  @override
  String get bookingSelectSeatsPrompt => 'Sélectionnez vos sièges';

  @override
  String get bookingPaymentNote =>
      'Paiement sécurisé via GeniusPay · Orange Money, MTN MoMo, Wave et carte acceptés.';

  @override
  String get profileAccountSettings => 'Paramètres du compte';

  @override
  String get profileCurrentPassword => 'Mot de passe actuel';

  @override
  String get profileNewPassword => 'Nouveau mot de passe';

  @override
  String get profileConfirmNewPassword => 'Confirmer le nouveau mot de passe';

  @override
  String get profilePasswordMin => 'Minimum 6 caractères';

  @override
  String get profilePasswordChanged => 'Mot de passe modifié';

  @override
  String get profileSaveChanges => 'Enregistrer les modifications';

  @override
  String get profileUpdated => 'Profil mis à jour';

  @override
  String get paymentSecureTitle => 'Paiement sécurisé';

  @override
  String get paymentLoadingWebview => 'Chargement du paiement…';

  @override
  String get reload => 'Recharger';

  @override
  String get companyCannotLoad => 'Impossible de charger la compagnie';

  @override
  String get companyTripsAvail => 'Voyages dispo';

  @override
  String get companyLinesLabel => 'Lignes';

  @override
  String get companyContact => 'Contact';

  @override
  String companyStationsCount(int n) {
    return 'Gares ($n)';
  }

  @override
  String companyRoutesCount(int n) {
    return 'Lignes desservies ($n)';
  }

  @override
  String get stationCannotLoad => 'Impossible de charger la gare';

  @override
  String get stationDeparturesLabel => 'Départs';

  @override
  String get stationGpsAvail => 'Dispo';

  @override
  String get stationPracticalInfo => 'Informations pratiques';

  @override
  String get stationNavigateBtn => 'Naviguer';

  @override
  String stationNextDepartures(int n) {
    return 'Prochains départs ($n)';
  }

  @override
  String get stationNoDepartures => 'Aucun départ prévu aujourd\'hui';

  @override
  String stationSeats(int seats) {
    return '$seats places';
  }

  @override
  String get navScreenLocationDenied =>
      'Localisation refusée — activez-la dans les paramètres';

  @override
  String get navScreenArrived => 'Vous êtes arrivé !';

  @override
  String get navScreenNoDistance =>
      'Impossible de calculer la distance sans la localisation.';

  @override
  String get navScreenLocating => 'Localisation en cours...';

  @override
  String get navScreenDistance => 'Distance';

  @override
  String get navScreenWalking => 'À pied';

  @override
  String get tripTrackingTitle => 'Suivi en direct';

  @override
  String get tripTrackingWaiting => 'En attente de localisation…';

  @override
  String get tripTrackingEta => 'Arrivée prévue';

  @override
  String get tripTrackingSteps => 'Étapes';

  @override
  String tripTrackingOccupied(int occupied, int total) {
    return '$occupied/$total sièges occupés';
  }

  @override
  String get tripSocketLive => '● En direct';

  @override
  String get tripSocketConnecting => '○ Connexion…';

  @override
  String get tripSocketReconnecting => '○ Reconnexion…';

  @override
  String get tripSocketOffline => '✕ Hors ligne';

  @override
  String get seatPickerTitle => 'Choisir vos sièges';

  @override
  String get seatAvailableLabel => 'Libre';

  @override
  String get seatSelectedLabel => 'Sélectionné';

  @override
  String get seatOccupiedLabel => 'Occupé';

  @override
  String get seatFrontOfBus => 'Avant du bus';

  @override
  String get seatSelectMin => 'Sélectionnez au moins 1 siège';

  @override
  String seatConfirmButton(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Confirmer $count sièges · $amount F',
      one: 'Confirmer 1 siège · $amount F',
    );
    return '$_temp0';
  }

  @override
  String get agentGpsEnableHint => 'Activez le GPS dans les paramètres';

  @override
  String get manifestSearchHint => 'Rechercher un passager ou un siège…';

  @override
  String manifestMissingAlert(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count passagers non embarqués',
      one: '$count passager non embarqué',
    );
    return '$_temp0';
  }

  @override
  String get manifestNoPassengers => 'Aucun passager';

  @override
  String get noResults => 'Aucun résultat';

  @override
  String quickSaleTicketCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count billets',
      one: '$count billet',
    );
    return '$_temp0';
  }

  @override
  String get payMethodCash => 'Espèces';

  @override
  String get agentStationLabel => 'Gare affectée';

  @override
  String get agentInfoSection => 'Informations';

  @override
  String get schedulesNoSchedules => 'Aucun horaire';

  @override
  String get schedulesAdd => 'Ajouter un horaire';

  @override
  String get schedulesNew => 'Nouvel horaire';

  @override
  String get schedulesCreate => 'Créer l\'horaire';

  @override
  String get scheduleDays => 'Jours';

  @override
  String get scheduleRouteLabel => 'Itinéraire';

  @override
  String get scheduleSelectRoute => 'Sélectionnez un itinéraire';

  @override
  String get scheduleDepartureTime => 'Heure de départ';

  @override
  String get staffNoMembers => 'Aucun membre du personnel';

  @override
  String get staffInviteAgent => 'Inviter un agent';

  @override
  String get staffInvite => 'Inviter';

  @override
  String get staffInviteMember => 'Inviter un membre';

  @override
  String get staffSendInvite => 'Envoyer l\'invitation';

  @override
  String get staffInviteSent => 'Invitation envoyée';

  @override
  String get staffRoleLabel => 'Rôle';

  @override
  String get staffStationOptional => 'Gare assignée (optionnel)';

  @override
  String get stationsNone => 'Aucune gare';

  @override
  String get stationsAdd => 'Ajouter une gare';

  @override
  String get stationsNew => 'Nouvelle gare';

  @override
  String get stationsCreate => 'Créer la gare';

  @override
  String get stationsPrimary => 'Principale';

  @override
  String get stationsSetPrimary => 'Définir principale';

  @override
  String get stationsPrimaryCannotDelete =>
      'La gare principale ne peut pas être supprimée';

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
  String get stationsPrimaryLabel => 'Gare principale';

  @override
  String get stationsPrimarySubtitle => 'Gare par défaut pour votre compte';

  @override
  String get stationsName => 'Nom de la gare';

  @override
  String get stationsDeleteTitle => 'Supprimer la gare';

  @override
  String get reportsPeriod365d => '1 an';

  @override
  String get reportsBookingsSection => 'Réservations';

  @override
  String get reportsTotalBookings => 'Total réservations';

  @override
  String get reportsExport => 'Exporter';

  @override
  String get reportsExportError => 'Export impossible';

  @override
  String get reportsByStatus => 'Par statut';

  @override
  String reportsExportSubject(String format) {
    return 'Rapport TransPro ($format)';
  }

  @override
  String get fleetStatusOutOfService => 'Hors service';

  @override
  String get fleetActivate => 'Activer';

  @override
  String get fleetDeactivate => 'Désactiver';

  @override
  String get fleetMaintenanceOilChange => 'Vidange';

  @override
  String get fleetMaintenanceTireRotation => 'Rotation pneus';

  @override
  String get fleetMaintenanceBrakeService => 'Freins';

  @override
  String get fleetMaintenanceFilterChange => 'Filtre';

  @override
  String get fleetMaintenanceMajorService => 'Révision majeure';

  @override
  String get fleetMaintenanceRepair => 'Réparation';

  @override
  String get fleetMaintenanceInspection => 'Inspection';

  @override
  String get fleetFuelLiters => 'Litres';

  @override
  String get fleetFuelTotalCost => 'Coût total';

  @override
  String get fleetOdometer => 'Kilométrage';

  @override
  String get fleetFuelStationLabel => 'Station';

  @override
  String get fleetDescriptionLabel => 'Description';

  @override
  String get fleetCostLabel => 'Coût';

  @override
  String get fleetGarageLabel => 'Garage';

  @override
  String get fleetDeleteFuelTitle => 'Supprimer ce plein ?';

  @override
  String get fleetDeleteMaintenanceTitle => 'Supprimer cet entretien ?';

  @override
  String get fleetTypeLabel => 'Type';

  @override
  String get notDefined => 'Non défini';

  @override
  String get driverSingularLabel => 'Conducteur';

  @override
  String get driverEvaluateTitle => 'Évaluer le conducteur';

  @override
  String get driverAddAbsenceTitle => 'Enregistrer une absence';

  @override
  String driverEvalCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n évaluations',
      one: '$n évaluation',
    );
    return '$_temp0';
  }

  @override
  String driverEvalBy(String name) {
    return 'Par $name';
  }

  @override
  String get driverAbsenceStartDate => 'Début';

  @override
  String get driverAbsenceEndDate => 'Fin';

  @override
  String get driverAbsenceSelectDates => 'Sélectionnez les dates';

  @override
  String get driverAbsenceReasonOptional => 'Motif (optionnel)';

  @override
  String get routeDeactivate => 'Désactiver';

  @override
  String get routeActivate => 'Activer';

  @override
  String routeSchedulesCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n horaires',
      one: '$n horaire',
    );
    return '$_temp0';
  }

  @override
  String get routeNew => 'Nouvel itinéraire';

  @override
  String get routeNameLabel => 'Nom de l\'itinéraire';

  @override
  String get routeOriginCity => 'Ville départ';

  @override
  String get routeDestCity => 'Ville arrivée';

  @override
  String get routeDistance => 'Distance (km)';

  @override
  String get routeDuration => 'Durée (min)';

  @override
  String get routeBasePrice => 'Prix de base (F CFA)';

  @override
  String get routeSelectCities => 'Sélectionnez les villes';

  @override
  String get profileNameLabel => 'Nom';

  @override
  String get profileAddressLabel => 'Adresse';

  @override
  String get profileRccmLabel => 'RCCM';

  @override
  String get profileCompanyName => 'Nom de l\'entreprise';

  @override
  String get profileEditCompany => 'Modifier l\'entreprise';

  @override
  String get fleetNewVehicle => 'Nouveau véhicule';

  @override
  String get fleetClass => 'Classe';

  @override
  String get invalidNumber => 'Nombre invalide';

  @override
  String get companiesTitle => 'Compagnies';

  @override
  String get companiesSearchHint => 'Chercher une compagnie…';

  @override
  String get favoritesTitle => 'Favoris';

  @override
  String get favoritesCompanies => 'Compagnies favorites';

  @override
  String get favoritesStations => 'Gares favorites';

  @override
  String get favoritesNoCompanies => 'Aucune compagnie favorite';

  @override
  String get favoritesNoStations => 'Aucune gare favorite';

  @override
  String get homeFavoriteCompanies => 'Mes compagnies favorites';

  @override
  String get transactionsTitle => 'Mes transactions';

  @override
  String get transactionsEmpty => 'Aucune transaction';

  @override
  String get transactionsEmptySub =>
      'Vos paiements effectués apparaîtront ici.';

  @override
  String get transactionsFilterAll => 'Toutes';

  @override
  String get transactionsFilterSuccess => 'Réussies';

  @override
  String get transactionsFilterFailed => 'Échouées';

  @override
  String get transactionsFilterPending => 'En cours';

  @override
  String get transactionsTotalSpent => 'Total dépensé';

  @override
  String transactionsCount(int count) {
    return '$count transaction(s)';
  }

  @override
  String get transactionsMethodCash => 'Espèces';

  @override
  String get transactionsMethodMobile => 'Mobile Money';

  @override
  String get transactionsMethodCard => 'Carte';

  @override
  String get transactionsStatusSuccess => 'Réussi';

  @override
  String get transactionsStatusFailed => 'Échoué';

  @override
  String get transactionsStatusProcessing => 'En cours';

  @override
  String get transactionsStatusPending => 'En attente';

  @override
  String transactionsRef(String ref) {
    return 'Réf. $ref';
  }

  @override
  String transactionsSeats(int count) {
    return '$count siège(s)';
  }

  @override
  String get transactionsDrawerLabel => 'Mes transactions';
}
