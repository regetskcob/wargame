/// What the host picked in the lobby.
enum GameMode {
  /// Alone against CPU tanks in the open field.
  solo,

  /// Last tank standing against other people.
  multi,

  /// Together against waves of enemy tanks that drive to the base.
  defense;

  bool get withOthers => this != solo;
}
