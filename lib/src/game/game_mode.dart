/// What the host picked in the lobby.
enum GameMode {
  /// Alone against CPU tanks in the open field.
  solo,

  /// Last tank standing against other people.
  multi,

  /// Together against waves of enemy tanks that drive to the base.
  defense,

  /// Capture the flag: red against blue, each side steals the other's flag
  /// and brings it home, tanks come back after they were destroyed.
  flag;

  bool get withOthers => this != solo;
}
