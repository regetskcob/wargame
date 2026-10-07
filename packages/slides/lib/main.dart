import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_deck/flutter_deck.dart';
import 'package:flutter_deck_web_client/flutter_deck_web_client.dart';
import 'package:google_fonts/google_fonts.dart';

import 'deck_theme.dart';
import 'slides/s01_title.dart';
import 'slides/s02_speakers.dart';
import 'slides/s03_agenda.dart';
import 'slides/s04_why_serverless.dart';
import 'slides/s04a_the_game.dart';
import 'slides/s05_architecture.dart';
import 'slides/s06_realtime.dart';
import 'slides/s06a_game_netcode.dart';
import 'slides/s07_credits.dart';
import 'slides/s08_typed_v3.dart';
import 'slides/s09_v2_vs_v3.dart';
import 'slides/s10_setup.dart';
import 'slides/s11_install_cli.dart';
import 'slides/s12_github_sync.dart';
import 'slides/s13_migration.dart';
import 'slides/s14_skeleton.dart';
import 'slides/s15_run_the_game.dart';
import 'slides/s16_exercise_setup.dart';
import 'slides/s17_game_idea.dart';
import 'slides/s18_initial_schema.dart';
import 'slides/s19_schema.dart';
import 'slides/s19a_ship_it.dart';
import 'slides/s20_questions.dart';
import 'slides/s21_thanks.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/google_fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['google_fonts'], license);
  });
  runApp(const WorkshopSlides());
}

class WorkshopSlides extends StatelessWidget {
  const WorkshopSlides({super.key});

  @override
  Widget build(BuildContext context) {
    return FlutterDeckApp(
      client: FlutterDeckWebClient(),
      configuration: FlutterDeckConfiguration(
        footer: const FlutterDeckFooterConfiguration(
          showSlideNumbers: true,
          showSocialHandle: true,
        ),
        header: const FlutterDeckHeaderConfiguration(showHeader: false),
        slideSize: FlutterDeckSlideSize.fromAspectRatio(
          aspectRatio: const FlutterDeckAspectRatio.ratio16x9(),
          resolution: const FlutterDeckResolution.fhd(),
        ),
        transition: const FlutterDeckTransition.fade(),
      ),
      lightTheme: buildDeckTheme(),
      darkTheme: buildDeckTheme(),
      themeMode: ThemeMode.dark,
      slides: const [
        TitleSlide(),
        SpeakersSlide(),
        AgendaSlide(),
        WhyServerlessSlide(),
        TheGameSlide(),
        ArchitectureSlide(),
        RealtimeSlide(),
        GameNetcodeSlide(),
        CreditsSlide(),
        TypedV3Slide(),
        V2VersusV3Slide(),
        SetupSlide(),
        InstallCliSlide(),
        GithubSyncSlide(),
        MigrationSlide(),
        SkeletonSlide(),
        RunTheGameSlide(),
        ExerciseSetupSlide(),
        GameIdeaSlide(),
        InitialSchemaSlide(),
        SchemaSlide(),
        ShipItSlide(),
        QuestionsSlide(),
        ThanksSlide(),
      ],
    );
  }
}
