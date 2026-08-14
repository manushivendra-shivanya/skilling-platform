import 'package:candidate_mobile/features/profile_details/domain/detailed_candidate_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DetailedCandidateProfile.completionPercent', () {
    test('is 0 for a fully empty profile', () {
      expect(DetailedCandidateProfile.empty.completionPercent, 0);
      expect(DetailedCandidateProfile.empty.isComplete, isFalse);
    });

    test('counts phone-or-email as one section, not two', () {
      const withPhoneOnly = DetailedCandidateProfile(
        phone: '9999999999',
        email: '',
        skills: [],
        workExperience: [],
        education: [],
        certifications: [],
        projects: [],
      );
      // 1 of 5 sections -> 20%, not 10% -- phone and email share one slot.
      expect(withPhoneOnly.completionPercent, 20);
    });

    test('counts certifications-or-projects as one section, not two', () {
      const withProjectOnly = DetailedCandidateProfile(
        phone: '',
        email: '',
        skills: [],
        workExperience: [],
        education: [],
        certifications: [],
        projects: [ProjectEntry(id: 'p1', title: 'Inventory tracker')],
      );
      expect(withProjectOnly.completionPercent, 20);

      const withBoth = DetailedCandidateProfile(
        phone: '',
        email: '',
        skills: [],
        workExperience: [],
        education: [],
        certifications: [
          ExternalCertificationEntry(id: 'c1', name: 'Forklift License'),
        ],
        projects: [ProjectEntry(id: 'p1', title: 'Inventory tracker')],
      );
      // Still one section, even with both populated.
      expect(withBoth.completionPercent, 20);
    });

    test('is 100 once every section has at least one value', () {
      const full = DetailedCandidateProfile(
        phone: '9999999999',
        email: 'candidate@example.com',
        skills: ['forklift'],
        workExperience: [
          WorkExperienceEntry(
            id: 'w1',
            title: 'Warehouse Associate',
            company: 'Apex Logistics',
          ),
        ],
        education: [EducationEntry(id: 'e1', institution: 'Delhi University')],
        certifications: [],
        projects: [ProjectEntry(id: 'p1', title: 'Inventory tracker')],
      );
      expect(full.completionPercent, 100);
      expect(full.isComplete, isTrue);
    });
  });
}
