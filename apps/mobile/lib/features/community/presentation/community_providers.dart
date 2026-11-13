import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/controllers/auth_controller.dart';
import '../../auth/presentation/controllers/auth_providers.dart';
import '../data/community_api.dart';
import '../domain/community.dart';

final communityApiProvider =
    Provider<CommunityApi>((ref) => DioCommunityApi(ref.watch(dioProvider)));

/// Beta 5.8 (ADR-057): am I in Community, as whom, and how many friend
/// requests wait.
final communityMeProvider = FutureProvider<CommunityMe>(
  (ref) async {
    requireSession(ref);
    final r = await ref.watch(communityApiProvider).me();
    return r.when(ok: (m) => m, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

final friendListsProvider = FutureProvider.autoDispose<FriendLists>(
  (ref) async {
    requireSession(ref);
    final r = await ref.watch(communityApiProvider).friends();
    return r.when(ok: (l) => l, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

final clubsProvider = FutureProvider.autoDispose<List<Club>>(
  (ref) async {
    requireSession(ref);
    final r = await ref.watch(communityApiProvider).clubs();
    return r.when(ok: (c) => c, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

final blockedProvider = FutureProvider.autoDispose<List<CommunityPerson>>(
  (ref) async {
    requireSession(ref);
    final r = await ref.watch(communityApiProvider).blocked();
    return r.when(ok: (p) => p, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// Community's parts, chosen at the top (Friends first; beta 6.3: the Feed
/// beside it).
enum CommunityTab { friends, feed, clubs, world }

class CommunityTabController extends Notifier<CommunityTab> {
  @override
  CommunityTab build() => CommunityTab.friends;

  void set(CommunityTab tab) => state = tab;
}

final communityTabProvider =
    NotifierProvider<CommunityTabController, CommunityTab>(
  CommunityTabController.new,
);

/// What every board ranks by: gym sessions unless the person picks run km.
class BoardMetricController extends Notifier<BoardMetric> {
  @override
  BoardMetric build() => BoardMetric.sessions;

  void set(BoardMetric metric) => state = metric;
}

final boardMetricProvider =
    NotifierProvider<BoardMetricController, BoardMetric>(
  BoardMetricController.new,
);

/// The world board everywhere, or in the person's own country.
class WorldScopeController extends Notifier<bool> {
  @override
  bool build() => false;

  // ignore: avoid_positional_boolean_parameters
  void set(bool countryOnly) => state = countryOnly;
}

final worldCountryOnlyProvider = NotifierProvider<WorldScopeController, bool>(
  WorldScopeController.new,
);

/// Beta 6.3 (C13): every board's period, the week unless the person picks.
class BoardPeriodController extends Notifier<BoardPeriod> {
  @override
  BoardPeriod build() => BoardPeriod.week;

  void set(BoardPeriod period) => state = period;
}

final boardPeriodProvider =
    NotifierProvider<BoardPeriodController, BoardPeriod>(
  BoardPeriodController.new,
);

final friendsBoardProvider =
    FutureProvider.autoDispose.family<Board, BoardMetric>(
  (ref, metric) async {
    requireSession(ref);
    final period = ref.watch(boardPeriodProvider);
    final r = await ref
        .watch(communityApiProvider)
        .friendsBoard(metric, period: period);
    return r.when(ok: (b) => b, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

final clubBoardProvider =
    FutureProvider.autoDispose.family<Board, (String, BoardMetric)>(
  (ref, key) async {
    requireSession(ref);
    final period = ref.watch(boardPeriodProvider);
    final r = await ref
        .watch(communityApiProvider)
        .clubBoard(key.$1, key.$2, period: period);
    return r.when(ok: (b) => b, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

final worldBoardProvider =
    FutureProvider.autoDispose.family<Board, (BoardMetric, String?)>(
  (ref, key) async {
    requireSession(ref);
    final period = ref.watch(boardPeriodProvider);
    final r = await ref
        .watch(communityApiProvider)
        .worldBoard(key.$1, country: key.$2, period: period);
    return r.when(ok: (b) => b, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// Beta 6.3 (C1): the feed's first page (older pages load in the view).
final feedProvider = FutureProvider.autoDispose<Feed>(
  (ref) async {
    requireSession(ref);
    final r = await ref.watch(communityApiProvider).feed();
    return r.when(ok: (f) => f, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// Beta 6.3 (C16): people you may know.
final suggestionsProvider = FutureProvider.autoDispose<List<Suggestion>>(
  (ref) async {
    requireSession(ref);
    final r = await ref.watch(communityApiProvider).suggestions();
    return r.when(ok: (s) => s, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// Beta 6.2 (C4): a friend's or club-mate's board data.
final personProfileProvider =
    FutureProvider.autoDispose.family<PersonProfile, String>(
  (ref, userId) async {
    requireSession(ref);
    final r = await ref.watch(communityApiProvider).personProfile(userId);
    return r.when(ok: (p) => p, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// Beta 6.2 (C5): who a club's owner removed.
final removedFromClubProvider =
    FutureProvider.autoDispose.family<List<CommunityPerson>, String>(
  (ref, clubId) async {
    requireSession(ref);
    final r = await ref.watch(communityApiProvider).removedFrom(clubId);
    return r.when(ok: (p) => p, err: (f) => throw f);
  },
  retry: (_, __) => null,
);

/// After anything that changes who is where: every list and board again.
void refreshCommunity(WidgetRef ref) {
  ref
    ..invalidate(communityMeProvider)
    ..invalidate(friendListsProvider)
    ..invalidate(clubsProvider)
    ..invalidate(blockedProvider)
    ..invalidate(friendsBoardProvider)
    ..invalidate(clubBoardProvider)
    ..invalidate(worldBoardProvider)
    ..invalidate(personProfileProvider)
    ..invalidate(removedFromClubProvider)
    ..invalidate(feedProvider)
    ..invalidate(suggestionsProvider);
}
