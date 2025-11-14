const String apiBaseUrl = String.fromEnvironment(
  'LEDGERSTREAM_API_BASE_URL',
  defaultValue: 'http://localhost:8000/api',
);

const Duration paymentsAutoRefreshInterval = Duration(seconds: 15);
const int defaultPaymentsPageSize = 25;
