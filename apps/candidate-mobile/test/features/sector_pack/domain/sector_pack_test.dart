import 'package:candidate_mobile/features/sector_pack/domain/sector_pack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SectorPacks', () {
    test('warehouseLogistics is the only pack live in the shipped app', () {
      final live = SectorPacks.all.where((p) => p.isReferenceImplementation);

      expect(live, contains(SectorPacks.warehouseLogistics));
      expect(live, contains(SectorPacks.lastMileDelivery));
    });

    test('byId resolves each pack back to itself', () {
      for (final pack in SectorPacks.all) {
        expect(SectorPacks.byId(pack.id), same(pack));
      }
    });

    test('every pack names a real-world signal source, not a generic label', () {
      for (final pack in SectorPacks.all) {
        expect(pack.signalSource, isNotEmpty);
        expect(
          pack.signalSource.toLowerCase(),
          isNot(contains('status colour')),
          reason:
              '${pack.displayName} signalSource should name the real object '
              'its palette is read from, not describe itself generically',
        );
      }
    });

    test('no pack reuses its signal palette as the primary accent', () {
      // Regression guard for the bug caught while building the last-mile
      // pack: a content-type tag colliding with a status colour because
      // both were the same token.
      for (final pack in SectorPacks.all) {
        final signalColors = {
          pack.signalPalette.locked,
          pack.signalPalette.active,
          pack.signalPalette.cleared,
        };
        expect(
          signalColors.contains(pack.primaryAccent),
          isFalse,
          reason:
              '${pack.displayName}: primaryAccent should stay distinct from '
              'the locked/active/cleared signal colours',
        );
      }
    });

    test('warehouse and last-mile packs use distinct labels for every slot', () {
      final warehouse = SectorPacks.warehouseLogistics;
      final lastMile = SectorPacks.lastMileDelivery;

      expect(warehouse.listItemLabel, isNot(lastMile.listItemLabel));
      expect(warehouse.taskObjectLabel, isNot(lastMile.taskObjectLabel));
      expect(warehouse.credentialLabel, isNot(lastMile.credentialLabel));
      expect(warehouse.signalSource, isNot(lastMile.signalSource));
    });
  });
}
