import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/collisions.dart';
// import 'package:flame/effects.dart';
import 'package:flame/experimental.dart';
import 'package:flame/particles.dart';
import 'package:flame/components.dart';
// import 'package:flame_noise/flame_noise.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/player_data.dart';
import '../models/spaceship_details.dart';

import 'game.dart';
import 'enemy.dart';
import 'bullet.dart';
import 'command.dart';
import 'audio_player_component.dart';

// Define a custom event for handling left and right movement
enum PlayerMovement { left, right, none }

class Player extends SpriteComponent
    with CollisionCallbacks, HasGameReference<SpacescapeGame>, KeyboardHandler {
  // Player joystick
  late Player player;
  JoystickComponent joystick;

  void move(Vector2 delta) {
    position += delta;
  }

  // Player health.
  int _health = 100;
  int get health => _health;

  // Details of current spaceship.
  Spaceship _spaceship;

  // Type of current spaceship.
  SpaceshipType spaceshipType;

  // A reference to PlayerData so that
  // we can modify money.
  late PlayerData _playerData;
  int get score => _playerData.currentScore;

  // If true, player will shoot 3 bullets at a time.
  bool _shootMultipleBullets = false;

  // Controls for how long multi-bullet power up is active.
  late Timer _powerUpTimer;

  // Holds an object of Random class to generate random numbers.
  final _random = Random();

  // This method generates a random vector such that
  // its x component lies between [-100 to 100] and
  // y component lies between [200, 400]
  Vector2 getRandomVector() {
    return (Vector2.random(_random) - Vector2(0.5, -1)) * 200;
  }

  Player({
    required this.joystick,
    required this.spaceshipType,
    Sprite? sprite,
    Vector2? position,
    Vector2? size,
  })  : _spaceship = Spaceship.getSpaceshipByType(spaceshipType),
        super(sprite: sprite, position: position, size: size) {
    // Sets power up timer to 4 seconds. After 4 seconds,
    // multiple bullet will get deactivated.
    _powerUpTimer = Timer(4, onTick: () {
      _shootMultipleBullets = false;
    });
  }

  @override
  void onMount() {
    super.onMount();

    // Adding a circular hitbox with radius as 0.8 times
    // the smallest dimension of this components size.
    final shape = CircleHitbox.relative(
      0.8,
      parentSize: size,
      position: size / 2,
      anchor: Anchor.center,
    );
    add(shape);

    _playerData = Provider.of<PlayerData>(game.buildContext!, listen: false);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);

    // If other entity is an Enemy, reduce player's health by 10.
    if (other is Enemy) {
      _health -= 10;
      if (_health <= 0) {
        _health = 0;
      }
    }
  }

  Vector2 keyboardDelta = Vector2.zero();
  static final _keysWatched = {
    LogicalKeyboardKey.keyW,
    LogicalKeyboardKey.keyA,
    LogicalKeyboardKey.keyS,
    LogicalKeyboardKey.keyD,
    LogicalKeyboardKey.space,
  };

  @override
  bool onKeyEvent(RawKeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    keyboardDelta.setZero();

    if (!_keysWatched.contains(event.logicalKey)) return true;

    if (event is RawKeyDownEvent &&
        !event.repeat &&
        event.logicalKey == LogicalKeyboardKey.space) {
      joystickAction();
    }

    if (keysPressed.contains(LogicalKeyboardKey.keyW)) {
      keyboardDelta.y = -1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.keyA)) {
      keyboardDelta.x = -1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.keyS)) {
      keyboardDelta.y = 1;
    }
    if (keysPressed.contains(LogicalKeyboardKey.keyD)) {
      keyboardDelta.x = 1;
    }

    return false;
  }

  @override
  void update(double dt) {
    super.update(dt);

    _powerUpTimer.update(dt);

    if (!joystick.delta.isZero()) {
      print("joystickmoved");
      position.add(joystick.relativeDelta * _spaceship.speed * dt);
    }

    if (!keyboardDelta.isZero()) {
      position.add(keyboardDelta * _spaceship.speed * dt);
    }

    position.clamp(
      Vector2.zero() + size / 2,
      game.fixedResolution - size / 2,
    );

    final particleComponent = ParticleSystemComponent(
      particle: Particle.generate(
        count: 10,
        lifespan: 0.1,
        generator: (i) => AcceleratedParticle(
          acceleration: getRandomVector(),
          speed: getRandomVector(),
          position: (position.clone() + Vector2(0, size.y / 3)),
          child: CircleParticle(
            radius: 1,
            paint: Paint()..color = Colors.white,
          ),
        ),
      ),
    );

    game.world.add(particleComponent);
  }

  void joystickAction() {
    Bullet bullet = Bullet(
      sprite: game.spriteSheet.getSpriteById(28),
      size: Vector2(64, 64),
      position: position.clone(),
      level: _spaceship.level,
    );

    bullet.anchor = Anchor.center;
    game.world.add(bullet);

    game.addCommand(Command<AudioPlayerComponent>(action: (audioPlayer) {
      audioPlayer.playSfx('laserSmall_001.ogg');
    }));

    if (_shootMultipleBullets) {
      for (int i = -1; i < 2; i += 2) {
        Bullet bullet = Bullet(
          sprite: game.spriteSheet.getSpriteById(28),
          size: Vector2(64, 64),
          position: position.clone(),
          level: _spaceship.level,
        );

        bullet.anchor = Anchor.center;
        bullet.direction.rotate(i * pi / 6);
        game.world.add(bullet);
      }
    }
  }

  void addToScore(int points) {
    _playerData.currentScore += points;
    _playerData.money += points;
    _playerData.save();
  }

  void increaseHealthBy(int points) {
    _health += points;
    if (_health > 100) {
      _health = 100;
    }
  }

  void reset() {
    _playerData.currentScore = 0;
    _health = 100;
    position = game.fixedResolution / 2;
  }

  void setSpaceshipType(SpaceshipType spaceshipType) {
    spaceshipType = spaceshipType;
    _spaceship = Spaceship.getSpaceshipByType(spaceshipType);
    sprite = game.spriteSheet.getSpriteById(_spaceship.spriteId);
  }

  void shootMultipleBullets() {
    _shootMultipleBullets = true;
    _powerUpTimer.stop();
    _powerUpTimer.start();
  }
}
