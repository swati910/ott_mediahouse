abstract final class StorageKeys {
  static const selectedLanguage = 'mh_selected_language';
  static const themeMode = 'mh_theme_mode';
  static const dashboardPeriod = 'mh_dashboard_period';
  static const tablePageSize = 'mh_table_page_size';
  static const onboardingComplete = 'mh_onboarding_complete';
  static const migrationVersion = 'mh_storage_migration_version';
  static const accessTokenMigrationComplete =
      'mh_access_token_migration_complete_v1';
  static const refreshTokenMigrationComplete =
      'mh_refresh_token_migration_complete_v1';
  static const sessionIdMigrationComplete =
      'mh_session_id_migration_complete_v1';

  static const accessToken = 'mh_access_token_v2';
  static const refreshToken = 'mh_refresh_token_v2';
  static const sessionId = 'mh_session_id_v2';

  static const legacyAccessToken = 'accessToken';
  static const legacyToken = 'token';
  static const legacyRefreshToken = 'refreshToken';
  static const legacySessionId = 'sessionId';

  static const currentMigrationVersion = 1;
}

abstract final class HiveBoxes {
  static const dashboardCache = 'mh_dashboard_cache_v1';
  static const transactionCache = 'mh_transaction_cache_v1';
  static const settlementCache = 'mh_settlement_cache_v1';
  static const notificationCache = 'mh_notification_cache_v1';
  static const profileCache = 'mh_profile_cache_v1';
  static const supportCache = 'mh_support_cache_v1';
  static const lookupCache = 'mh_lookup_cache_v1';
  static const localDrafts = 'mh_local_drafts_v1';

  static const all = <String>[
    dashboardCache,
    transactionCache,
    settlementCache,
    notificationCache,
    profileCache,
    supportCache,
    lookupCache,
  ];
}
