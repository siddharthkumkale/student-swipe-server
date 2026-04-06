/// Google Play–related URLs and contact. Set [websiteBaseUrl] after you publish
/// the `docs/` folder to GitHub Pages (no trailing slash).
///
/// Example: `https://yourusername.github.io/student_swipe`
abstract final class PlayStoreConfig {
  /// HTTPS root of your GitHub Pages site hosting `docs/` (no trailing slash).
  /// When empty, [privacyPolicyUrl], [termsOfServiceUrl], [supportUrl], and
  /// [accountDeletionInstructionsUrl] are empty until you set this.
  static const String websiteBaseUrl = '';

  /// Privacy policy (`docs/index.html`).
  static String get privacyPolicyUrl => _joinBase('');

  /// Terms of use (`docs/terms.html`).
  static String get termsOfServiceUrl => _joinBase('terms.html');

  /// Help & support (`docs/support.html`).
  static String get supportUrl => _joinBase('support.html');

  /// Web instructions for account deletion (`docs/delete-account.html`).
  static String get accountDeletionInstructionsUrl => _joinBase('delete-account.html');

  /// Inbox for account-deletion requests (Play policy). Shown in Settings → Delete account.
  static const String accountDeletionEmail = 'siddharthkumkale2@gmail.com';

  static String _joinBase(String path) {
    final base = websiteBaseUrl.trim();
    if (base.isEmpty) return '';
    if (path.isEmpty) return base.endsWith('/') ? '${base}index.html' : '$base/';
    final sep = base.endsWith('/') ? '' : '/';
    return '$base$sep$path';
  }

  static bool _isHttpUrl(String raw) {
    final u = raw.trim();
    if (u.isEmpty) return false;
    final uri = Uri.tryParse(u);
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  static bool get isPrivacyPolicyConfigured => _isHttpUrl(privacyPolicyUrl);

  static bool get isTermsConfigured => _isHttpUrl(termsOfServiceUrl);

  static bool get isSupportConfigured => _isHttpUrl(supportUrl);

  static bool get isAccountDeletionHelpConfigured => _isHttpUrl(accountDeletionInstructionsUrl);
}
