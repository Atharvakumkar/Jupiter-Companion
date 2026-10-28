import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/models/fuel_log.dart';
import '../../domain/models/maintenance_record.dart';
import '../../domain/models/parking_location.dart';
import '../../domain/models/ride.dart';
import '../../domain/models/route_point.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('jupiter_companion.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Rides table
    await db.execute('''
      CREATE TABLE rides (
        id TEXT PRIMARY KEY,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        moving_duration_seconds INTEGER NOT NULL DEFAULT 0,
        distance_meters REAL NOT NULL DEFAULT 0.0,
        max_speed_kmh REAL NOT NULL DEFAULT 0.0,
        avg_speed_kmh REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL,
        source TEXT NOT NULL,
        points_count INTEGER NOT NULL DEFAULT 0,
        is_synced INTEGER NOT NULL DEFAULT 0,
        last_sync_time INTEGER,
        start_address TEXT,
        end_address TEXT
      )
    ''');

    // 2. Route points table
    await db.execute('''
      CREATE TABLE route_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ride_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL NOT NULL DEFAULT 0.0,
        accuracy REAL NOT NULL DEFAULT 999.0,
        speed_kmh REAL NOT NULL DEFAULT 0.0,
        bearing REAL NOT NULL DEFAULT 0.0,
        timestamp INTEGER NOT NULL,
        is_paused INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (ride_id) REFERENCES rides (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_route_points_ride_id ON route_points(ride_id)');
    await db.execute('CREATE INDEX idx_route_points_timestamp ON route_points(timestamp)');

    // 3. Maintenance table
    await db.execute('''
      CREATE TABLE maintenance_records (
        id TEXT PRIMARY KEY,
        date INTEGER NOT NULL,
        odometer_km REAL NOT NULL,
        odometer_source TEXT NOT NULL,
        task_type TEXT NOT NULL,
        cost REAL NOT NULL DEFAULT 0.0,
        notes TEXT,
        next_due_km REAL,
        next_due_date INTEGER,
        is_completed INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // 4. Fuel logs table
    await db.execute('''
      CREATE TABLE fuel_logs (
        id TEXT PRIMARY KEY,
        date INTEGER NOT NULL,
        liters REAL NOT NULL,
        total_cost REAL NOT NULL,
        cost_per_liter REAL NOT NULL,
        odometer_km REAL,
        is_full_tank INTEGER NOT NULL DEFAULT 1,
        fuel_station TEXT,
        notes TEXT,
        calculated_economy_kmpl REAL
      )
    ''');

    // 5. Parking locations table
    await db.execute('''
      CREATE TABLE parking_locations (
        id TEXT PRIMARY KEY,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        timestamp INTEGER NOT NULL,
        note TEXT,
        accuracy_meters REAL,
        address_preview TEXT,
        associated_ride_id TEXT
      )
    ''');
  }

  // --- Ride CRUD Operations ---

  Future<void> insertRide(Ride ride) async {
    final db = await database;
    await db.insert('rides', ride.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateRide(Ride ride) async {
    final db = await database;
    await db.update(
      'rides',
      ride.toMap(),
      where: 'id = ?',
      whereArgs: [ride.id],
    );
  }

  Future<Ride?> getRide(String id) async {
    final db = await database;
    final results = await db.query(
      'rides',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Ride.fromMap(results.first);
  }

  Future<List<Ride>> getAllRides() async {
    final db = await database;
    final results = await db.query('rides', orderBy: 'start_time DESC');
    return results.map((m) => Ride.fromMap(m)).toList();
  }

  Future<Ride?> getActiveRide() async {
    final db = await database;
    final results = await db.query(
      'rides',
      where: 'status IN (?, ?, ?)',
      whereArgs: [RideStatus.starting.name, RideStatus.recording.name, RideStatus.paused.name],
      orderBy: 'start_time DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return Ride.fromMap(results.first);
  }

  Future<void> deleteRide(String id) async {
    final db = await database;
    await db.delete('route_points', where: 'ride_id = ?', whereArgs: [id]);
    await db.delete('rides', where: 'id = ?', whereArgs: [id]);
  }

  // --- Route Points Operations ---

  Future<void> insertRoutePoint(RoutePoint point) async {
    final db = await database;
    await db.insert('route_points', point.toMap());
  }

  Future<void> insertRoutePointsBatch(List<RoutePoint> points) async {
    if (points.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final p in points) {
      batch.insert('route_points', p.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<RoutePoint>> getPointsForRide(String rideId) async {
    final db = await database;
    final results = await db.query(
      'route_points',
      where: 'ride_id = ?',
      whereArgs: [rideId],
      orderBy: 'timestamp ASC',
    );
    return results.map((m) => RoutePoint.fromMap(m)).toList();
  }

  // --- Maintenance Operations ---

  Future<void> insertMaintenanceRecord(MaintenanceRecord record) async {
    final db = await database;
    await db.insert('maintenance_records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<MaintenanceRecord>> getAllMaintenanceRecords() async {
    final db = await database;
    final results = await db.query('maintenance_records', orderBy: 'date DESC');
    return results.map((m) => MaintenanceRecord.fromMap(m)).toList();
  }

  Future<void> deleteMaintenanceRecord(String id) async {
    final db = await database;
    await db.delete('maintenance_records', where: 'id = ?', whereArgs: [id]);
  }

  // --- Fuel Log Operations ---

  Future<void> insertFuelLog(FuelLog log) async {
    final db = await database;
    await db.insert('fuel_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<FuelLog>> getAllFuelLogs() async {
    final db = await database;
    final results = await db.query('fuel_logs', orderBy: 'date DESC');
    return results.map((m) => FuelLog.fromMap(m)).toList();
  }

  Future<void> deleteFuelLog(String id) async {
    final db = await database;
    await db.delete('fuel_logs', where: 'id = ?', whereArgs: [id]);
  }

  // --- Parking Location Operations ---

  Future<void> saveParkingLocation(ParkingLocation location) async {
    final db = await database;
    await db.insert('parking_locations', location.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<ParkingLocation?> getLatestParkingLocation() async {
    final db = await database;
    final results = await db.query(
      'parking_locations',
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return ParkingLocation.fromMap(results.first);
  }

  Future<List<ParkingLocation>> getAllParkingLocations() async {
    final db = await database;
    final results = await db.query('parking_locations', orderBy: 'timestamp DESC');
    return results.map((m) => ParkingLocation.fromMap(m)).toList();
  }

  Future<void> deleteParkingLocation(String id) async {
    final db = await database;
    await db.delete('parking_locations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}

