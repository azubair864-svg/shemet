class GameModel {
  final String id;
  final String name;
  final String emoji;
  final int entryCost;
  final List<int> possibleWins;

  GameModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.entryCost,
    required this.possibleWins,
  });

  static List<GameModel> getGames() {
    return [
      GameModel(
        id: 'dice',
        name: 'Dice Roll',
        emoji: '🎲',
        entryCost: 50,
        possibleWins: [0, 100, 200, 500],
      ),
      GameModel(
        id: 'wheel',
        name: 'Spin Wheel',
        emoji: '🎡',
        entryCost: 100,
        possibleWins: [0, 200, 500, 1000, 5000],
      ),
      GameModel(
        id: 'quiz',
        name: 'Quick Quiz',
        emoji: '❓',
        entryCost: 20,
        possibleWins: [0, 50, 100],
      ),
      GameModel(
        id: 'lucky',
        name: 'Lucky Draw',
        emoji: '🎁',
        entryCost: 200,
        possibleWins: [0, 500, 1000, 2000, 10000],
      ),
    ];
  }
}