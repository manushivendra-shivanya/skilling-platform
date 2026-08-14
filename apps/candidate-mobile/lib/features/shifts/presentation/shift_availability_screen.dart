import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/app_failure_localization.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/app_loading_progress.dart';
import '../../../core/widgets/app_state_view.dart';
import '../../../core/widgets/app_sticky_footer.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/shift_availability.dart';
import 'shift_availability_controller.dart';

class ShiftAvailabilityScreen extends ConsumerWidget {
  const ShiftAvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(shiftAvailabilityControllerProvider);
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.availabilityTitle)),
      body: SafeArea(
        child: state.when(
          loading: () => Center(
            child: AppLoadingProgressBar(label: l10n.availabilityLoadingLabel),
          ),
          error: (error, stackTrace) => AppErrorState(
            title: l10n.availabilityLoadErrorTitle,
            message: error is AppFailure
                ? error.localizedMessage(l10n)
                : l10n.availabilityLoadErrorFallback,
            onAction: () => ref.invalidate(shiftAvailabilityControllerProvider),
          ),
          data: (value) => _AvailabilityForm(initial: value),
        ),
      ),
    );
  }
}

class _AvailabilityForm extends ConsumerStatefulWidget {
  const _AvailabilityForm({required this.initial});

  final ShiftAvailability initial;

  @override
  ConsumerState<_AvailabilityForm> createState() => _AvailabilityFormState();
}

class _AvailabilityFormState extends ConsumerState<_AvailabilityForm> {
  late bool _availableToday;
  late final TextEditingController _fromController;
  late final TextEditingController _untilController;
  late final TextEditingController _cityController;
  late final TextEditingController _travelController;
  late final TextEditingController _minPayController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _availableToday = widget.initial.availableToday;
    _fromController = TextEditingController(
      text: widget.initial.availableFrom ?? '',
    );
    _untilController = TextEditingController(
      text: widget.initial.availableUntil ?? '',
    );
    _cityController = TextEditingController(
      text: widget.initial.preferredCity ?? '',
    );
    _travelController = TextEditingController(
      text: widget.initial.maxTravelKm?.toString() ?? '',
    );
    _minPayController = TextEditingController(
      text: widget.initial.minPay?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _fromController.dispose();
    _untilController.dispose();
    _cityController.dispose();
    _travelController.dispose();
    _minPayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.availabilityHeadline,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l10n.availabilitySubtitle,
                  style: const TextStyle(color: AppColors.inkMuted),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _availableToday,
                        onChanged: (value) =>
                            setState(() => _availableToday = value),
                        title: Text(l10n.availabilityWorkTodayLabel),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              label: l10n.availabilityFromLabel,
                              controller: _fromController,
                              hint: '16:00',
                              helperText: l10n.availabilityTimeHelper,
                              keyboardType: TextInputType.datetime,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: AppTextField(
                              label: l10n.availabilityUntilLabel,
                              controller: _untilController,
                              hint: '22:00',
                              helperText: l10n.availabilityTimeHelper,
                              keyboardType: TextInputType.datetime,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        label: l10n.availabilityCityLabel,
                        controller: _cityController,
                        hint: l10n.availabilityCityHint,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: l10n.availabilityTravelLabel,
                        controller: _travelController,
                        hint: '8',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        label: l10n.availabilityMinPayLabel,
                        controller: _minPayController,
                        hint: '500',
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        AppStickyFooter(
          child: AppButton(
            label: _saving
                ? l10n.availabilitySavingLabel
                : l10n.availabilitySaveButton,
            isLoading: _saving,
            onPressed: _save,
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final availability = ShiftAvailability(
      availableToday: _availableToday,
      availableFrom: _fromController.text.trim().isEmpty
          ? null
          : _fromController.text.trim(),
      availableUntil: _untilController.text.trim().isEmpty
          ? null
          : _untilController.text.trim(),
      preferredCity: _cityController.text.trim().isEmpty
          ? null
          : _cityController.text.trim(),
      maxTravelKm: int.tryParse(_travelController.text.trim()),
      minPay: double.tryParse(_minPayController.text.trim()),
    );
    final failure = await ref
        .read(shiftAvailabilityControllerProvider.notifier)
        .save(availability);
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = false);
    showAppSnackBar(
      context: context,
      message:
          failure?.localizedMessage(l10n) ?? l10n.availabilitySavedSnackbar,
      tone: failure == null ? AppMessageTone.success : AppMessageTone.error,
    );
  }
}
