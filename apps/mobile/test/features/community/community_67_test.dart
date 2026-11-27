import 'package:fitos/features/community/domain/club_goals.dart';
import 'package:fitos/features/community/domain/community.dart';
import 'package:fitos/features/community/presentation/feed_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Beta 6.7 (Community revamp): the feed by day, and each post's kind.
void main() {
  FeedPost post(String id, DateTime at, {PostKind kind = PostKind.session}) =>
      FeedPost(
        id: id,
        person: const CommunityPerson(
          userId: 'u-ana',
          handle: 'ana',
          avatarId: null,
          country: null,
        ),
        kind: kind,
        title: 'Push',
        value: null,
        at: at,
        kudos: 0,
        cheered: false,
        mine: false,
      );

  test('posts under Today, Yesterday, then the weekday and date', () {
    final now = DateTime(2026, 11, 27, 9);
    final days = feedDays(
      [
        post('a', DateTime(2026, 11, 27, 8)),
        post('b', DateTime(2026, 11, 27, 0, 5)),
        post('c', DateTime(2026, 11, 26, 23)),
        post('d', DateTime(2026, 11, 23, 7)),
        post('e', DateTime(2026, 11, 23, 6)),
      ],
      now,
    );
    expect(days.map((d) => d.label), ['Today', 'Yesterday', 'Mon 23 Nov']);
    expect(days.map((d) => d.posts.map((p) => p.id).join()), [
      'ab',
      'c',
      'de',
    ]);
    expect(feedDays(const [], now), isEmpty);
  });

  test('a mark for each kind; records share the trophy', () {
    expect(postIcon(PostKind.session), Icons.fitness_center);
    expect(postIcon(PostKind.run), Icons.directions_run);
    expect(postIcon(PostKind.liftRecord), Icons.emoji_events);
    expect(postIcon(PostKind.runRecord), Icons.emoji_events);
    expect(postIcon(PostKind.streak), Icons.local_fire_department);
  });

  test("a club's line: the match while it's on, else the challenge", () {
    final match = ClubNow.fromJson({
      'kind': 'match',
      'metric': 'active-days',
      'opponent': 'Gym B',
      'us': 2.4,
      'them': 2.1,
      'daysLeft': 3,
    })!;
    expect(match, isA<ClubNowMatch>());
    expect(match.line, 'vs Gym B · 2.4 – 2.1 · 3 days left');
    final early = ClubNow.fromJson({
      'kind': 'match',
      'metric': 'sessions',
      'opponent': 'Gym B',
      'us': null,
      'them': null,
      'daysLeft': 1,
    })!;
    expect(early.line, 'vs Gym B · last day');
    final goal = ClubNow.fromJson({
      'kind': 'challenge',
      'metric': 'sessions',
      'total': 143,
      'target': 200,
      'daysLeft': 4,
    })! as ClubNowChallenge;
    expect(goal.line, '143 of 200 sessions · 4 days left');
    expect(goal.progress, closeTo(0.715, 0.001));
    expect(ClubNow.fromJson(null), isNull);
    expect(
      ClubNow.fromJson(
        {'kind': 'other', 'metric': 'sessions', 'daysLeft': 1},
      ),
      isNull,
    );
    final club = Club.fromJson({
      'id': 'c1',
      'name': 'Hostel A',
      'code': 'ABCD2345',
      'members': 3,
      'mine': false,
      'now': {
        'kind': 'challenge',
        'metric': 'distance',
        'total': 12.5,
        'target': 50,
        'daysLeft': 9,
      },
    });
    expect(club.now!.line, '12.5 of 50 km · 9 days left');
  });
}
