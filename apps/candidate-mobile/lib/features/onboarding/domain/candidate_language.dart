enum CandidateLanguage {
  english('en'),
  hindi('hi'),
  hinglish('hi-Latn');

  const CandidateLanguage(this.code);

  final String code;

  static CandidateLanguage? fromCode(String? code) {
    for (final language in values) {
      if (language.code == code) {
        return language;
      }
    }
    return null;
  }

  String get nativeName => switch (this) {
    CandidateLanguage.english => 'English',
    CandidateLanguage.hindi => 'हिंदी',
    CandidateLanguage.hinglish => 'Hinglish',
  };

  String get description => switch (this) {
    CandidateLanguage.english => 'Continue in English',
    CandidateLanguage.hindi => 'हिंदी में आगे बढ़ें',
    CandidateLanguage.hinglish => 'Hindi aur English, dono mein',
  };
}

class SignInCopy {
  const SignInCopy({
    required this.title,
    required this.message,
    required this.emailLabel,
    required this.googleLabel,
    required this.googleStatus,
    required this.privacyLead,
    required this.termsLabel,
    required this.andLabel,
    required this.privacyLabel,
  });

  factory SignInCopy.forLanguage(CandidateLanguage language) {
    return switch (language) {
      CandidateLanguage.english => const SignInCopy(
        title: 'How would you like to continue?',
        message: 'Use your email to create or resume your profile.',
        emailLabel: 'Continue with email',
        googleLabel: 'Continue with Google',
        googleStatus: 'Planned — not configured yet',
        privacyLead: 'By continuing, you agree to our',
        termsLabel: 'Terms',
        andLabel: 'and',
        privacyLabel: 'Privacy Policy',
      ),
      CandidateLanguage.hindi => const SignInCopy(
        title: 'आप कैसे आगे बढ़ना चाहेंगे?',
        message: 'अपनी प्रोफ़ाइल बनाने या जारी रखने के लिए ईमेल इस्तेमाल करें।',
        emailLabel: 'ईमेल से आगे बढ़ें',
        googleLabel: 'Google से आगे बढ़ें',
        googleStatus: 'जल्द उपलब्ध होगा — अभी सेट अप नहीं है',
        privacyLead: 'आगे बढ़कर आप हमारी',
        termsLabel: 'शर्तों',
        andLabel: 'और',
        privacyLabel: 'गोपनीयता नीति',
      ),
      CandidateLanguage.hinglish => const SignInCopy(
        title: 'Aap kaise continue karna chahenge?',
        message: 'Profile banane ya resume karne ke liye email use karein.',
        emailLabel: 'Email se continue karein',
        googleLabel: 'Google se continue karein',
        googleStatus: 'Jald aa raha hai — abhi setup nahi hai',
        privacyLead: 'Continue karke aap hamari',
        termsLabel: 'Terms',
        andLabel: 'aur',
        privacyLabel: 'Privacy Policy',
      ),
    };
  }

  final String title;
  final String message;
  final String emailLabel;
  final String googleLabel;
  final String googleStatus;
  final String privacyLead;
  final String termsLabel;
  final String andLabel;
  final String privacyLabel;
}
