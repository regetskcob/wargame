import 'package:flutter/widgets.dart';
import 'package:flutter_deck/flutter_deck.dart';

import '../widgets/code_pane.dart';
import '../widgets/side_bullets.dart';

class MigrationSlide extends FlutterDeckSlideWidget {
  const MigrationSlide()
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/migration',
          title: 'What a migration looks like',
          speakerNotes:
              '- This is the first of the migrations the repository ships with, the '
              'scores table behind the leaderboard, later files add the '
              'players table and the round statistics\n'
              '- A migration is plain SQL, anything Postgres accepts works\n'
              '- The id is the auth user id, so each player owns exactly '
              'one row\n'
              '- Row level security is on, with one policy per operation: '
              'everyone reads, players only write their own row\n'
              '- That is why the publishable key is safe to put in the '
              'client\n'
              '- The file name prefix sets the order, and each file runs '
              'once per database',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.split(
      leftBuilder: (context) => const SideBullets(
        items: [
          'Plain SQL in supabase/migrations',
          'The table: one row per player, keyed by the auth user id',
          'Row level security: everyone reads, you write your own row',
          'Applied in file name order, once per database',
        ],
      ),
      rightBuilder: (context) => const CodePane(
        fileName: 'supabase/migrations/0001_scores.sql',
        code: '''
create table public.scores (
  id uuid primary key
    references auth.users (id) on delete cascade,
  name text not null,
  wins integer not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.scores enable row level security;

create policy "Scores are readable by everyone"
  on public.scores for select
  using (true);

create policy "Players can insert their own score"
  on public.scores for insert
  with check (auth.uid() = id);

create policy "Players can update their own score"
  on public.scores for update
  using (auth.uid() = id)
  with check (auth.uid() = id);''',
      ),
    );
  }
}
