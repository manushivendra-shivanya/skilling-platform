import 'package:candidate_mobile/features/profile_assistant/domain/profile_gap.dart';
import 'package:candidate_mobile/features/profile_details/domain/detailed_candidate_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an empty profile reports every tracked field as a gap', () {
    final gaps = findProfileGaps(DetailedCandidateProfile.empty);

    expect(gaps, hasLength(ProfileGapId.values.length));
    expect(profileFieldCompletionPercent(DetailedCandidateProfile.empty), 0);
  });

  test('recruiter-filter gaps are ordered ahead of everything else', () {
    final gaps = findProfileGaps(DetailedCandidateProfile.empty);

    expect(gaps.first.priority, ProfileGapPriority.recruiterFilter);
    expect(gaps[1].priority, ProfileGapPriority.recruiterFilter);
    expect(
      gaps.take(2).map((gap) => gap.id),
      containsAll([ProfileGapId.noticePeriod, ProfileGapId.expectedCtc]),
    );
    // Ordering is by cost, never by section: an optional gap can never
    // outrank an important one.
    final priorities = gaps.map((gap) => gap.priority.index).toList();
    expect(priorities, orderedEquals(List.of(priorities)..sort()));
  });

  test('a filled field stops being a gap', () {
    final profile = DetailedCandidateProfile.empty.copyWith(
      headline: 'Warehouse Operations Associate',
      careerPreferences: const CareerPreferences(
        noticePeriod: NoticePeriod.fifteenDays,
      ),
    );

    final ids = findProfileGaps(profile).map((gap) => gap.id);

    expect(ids, isNot(contains(ProfileGapId.headline)));
    expect(ids, isNot(contains(ProfileGapId.noticePeriod)));
    expect(ids, contains(ProfileGapId.expectedCtc));
  });

  test(
    'an undisclosed current CTC is an answer, not a gap -- only expected CTC is tracked',
    () {
      final profile = DetailedCandidateProfile.empty.copyWith(
        careerPreferences: const CareerPreferences(
          currentCtcUndisclosed: true,
          expectedCtcAmount: 320000,
        ),
      );

      final ids = findProfileGaps(profile).map((gap) => gap.id);

      expect(ids, isNot(contains(ProfileGapId.expectedCtc)));
      // There is deliberately no ProfileGapId for current CTC at all --
      // see findProfileGaps' own doc comment.
      expect(
        ProfileGapId.values.map((id) => id.name),
        isNot(contains('currentCtc')),
      );
    },
  );

  test('whitespace does not count as a filled field', () {
    final profile = DetailedCandidateProfile.empty.copyWith(headline: '   ');

    expect(
      findProfileGaps(profile).map((gap) => gap.id),
      contains(ProfileGapId.headline),
    );
  });

  test('a fully populated profile reports no gaps and 100 percent', () {
    final profile = DetailedCandidateProfile.empty.copyWith(
      phone: '9876543210',
      email: 'asha@example.com',
      skills: const ['Forklift operation'],
      headline: 'Warehouse Operations Associate',
      summary: 'Reliable, WMS-certified associate.',
      totalExperience: '3 yrs 4 mos',
      languages: const [
        LanguageEntry(
          id: 'l1',
          language: 'Hindi',
          proficiency: LanguageProficiency.native,
        ),
      ],
      workExperience: const [
        WorkExperienceEntry(id: 'w1', title: 'Associate', company: 'ABC'),
      ],
      education: const [EducationEntry(id: 'e1', institution: 'Govt. ITI')],
      careerPreferences: const CareerPreferences(
        noticePeriod: NoticePeriod.fifteenDays,
        expectedCtcAmount: 320000,
        preferredLocations: ['Lucknow'],
      ),
    );

    expect(findProfileGaps(profile), isEmpty);
    expect(profileFieldCompletionPercent(profile), 100);
  });
}
