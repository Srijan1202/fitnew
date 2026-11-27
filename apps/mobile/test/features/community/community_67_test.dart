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
}
