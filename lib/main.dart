import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// 🔔 Notification
final FlutterLocalNotificationsPlugin notifications =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MyApp());

  // 🔥 init sau để tránh lag
  initNotification();
}

// 🔥 tách riêng để tránh block UI
Future initNotification() async {
  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: android);

  await notifications.initialize(settings);

  await notifications
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
}

// ================= MODEL =================
class Task {
  int? id;
  String name;
  String location;
  String time;
  int done;

  Task({
    this.id,
    required this.name,
    required this.location,
    required this.time,
    this.done = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'time': time,
      'done': done,
    };
  }
}

// ================= DATABASE =================
class DBHelper {
  static Future<Database> initDB() async {
    return openDatabase(
      p.join(await getDatabasesPath(), 'tasks.db'),
      onCreate: (db, version) {
        return db.execute(
            "CREATE TABLE tasks(id INTEGER PRIMARY KEY, name TEXT, location TEXT, time TEXT, done INTEGER)");
      },
      version: 1,
    );
  }

  static Future<void> insert(Task task) async {
    final db = await initDB();
    await db.insert('tasks', task.toMap());
  }

  static Future<List<Task>> getTasks() async {
    final db = await initDB();
    final maps = await db.query('tasks');

    return List.generate(maps.length, (i) {
      return Task(
        id: maps[i]['id'] as int,
        name: maps[i]['name'] as String,
        location: maps[i]['location'] as String,
        time: maps[i]['time'] as String,
        done: maps[i]['done'] as int,
      );
    });
  }

  static Future<void> delete(int id) async {
    final db = await initDB();
    await db.delete('tasks', where: "id = ?", whereArgs: [id]);
  }

  static Future<void> update(Task task) async {
    final db = await initDB();
    await db.update('tasks', task.toMap(),
        where: "id = ?", whereArgs: [task.id]);
  }
}

// ================= NOTIFICATION =================
Future scheduleNotification(DateTime time, String title) async {
  try {
    await notifications.zonedSchedule(
      DateTime.now().millisecondsSinceEpoch,
      "🔔 Nhắc việc",
      title,
      tz.TZDateTime.from(time, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'task_channel',
          'Nhắc việc',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),

      // 🔥 FIX Ở ĐÂY
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,

      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  } catch (e) {
    print("❌ Notification lỗi: $e");
  }
}

// ================= APP =================
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Home(),
    );
  }
}

// ================= HOME =================
class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Task> tasks = [];
  List<Task> filtered = [];
  TextEditingController search = TextEditingController();

  @override
  void initState() {
    super.initState();
    load();
  }

  // 🔥 FIX LAG
  Future load() async {
    await Future.delayed(Duration(milliseconds: 100));
    tasks = await DBHelper.getTasks();
    filtered = tasks;

    if (mounted) setState(() {});
  }

  void searchTask(String keyword) {
    filtered = tasks
        .where((t) =>
    t.name.toLowerCase().contains(keyword.toLowerCase()) ||
        t.location.toLowerCase().contains(keyword.toLowerCase()))
        .toList();
    setState(() {});
  }

  void toggle(Task t) async {
    t.done = t.done == 1 ? 0 : 1;
    await DBHelper.update(t);
    load();
  }

  void deleteTask(int id) async {
    await DBHelper.delete(id);
    load();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("📋 Lịch nhắc")),
      body: Column(
        children: [
          // 🔍 SEARCH
          Padding(
            padding: EdgeInsets.all(10),
            child: TextField(
              controller: search,
              onChanged: searchTask,
              decoration: InputDecoration(
                hintText: "Tìm kiếm...",
                prefixIcon: Icon(Icons.search),
                border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          Expanded(
            child: filtered.isEmpty
                ? Center(child: Text("Không có dữ liệu"))
                : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                var t = filtered[i];
                return Card(
                  margin: EdgeInsets.all(10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: Icon(
                      t.done == 1
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: Colors.green,
                    ),
                    title: Text(t.name),
                    subtitle: Text(
                      "${t.location}\n${DateFormat("dd/MM/yyyy HH:mm").format(DateTime.parse(t.time))}",
                    ),
                    isThreeLine: true,
                    onTap: () => toggle(t),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => deleteTask(t.id!),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () async {
          var result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddTask()),
          );

          if (result == true) load();
        },
      ),
    );
  }
}

// ================= ADD =================
class AddTask extends StatefulWidget {
  @override
  _AddTaskState createState() => _AddTaskState();
}

class _AddTaskState extends State<AddTask> {
  final name = TextEditingController();
  final location = TextEditingController();

  DateTime date = DateTime.now();
  TimeOfDay time = TimeOfDay.now();

  Future pickDate() async {
    var d = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => date = d);
  }

  Future pickTime() async {
    var t = await showTimePicker(context: context, initialTime: time);
    if (t != null) setState(() => time = t);
  }

  void save() async {
    if (name.text.isEmpty) return;

    DateTime full = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    // ❗ check lỗi thời gian
    if (full.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Thời gian không hợp lệ")),
      );
      return;
    }

    Task t = Task(
      name: name.text,
      location: location.text,
      time: full.toString(),
    );

    await DBHelper.insert(t);
    await scheduleNotification(full, name.text);

    Navigator.pop(context, true);
  }

  @override
  void dispose() {
    name.dispose();
    location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("➕ Thêm lịch")),
      body: Padding(
        padding: EdgeInsets.all(15),
        child: Column(
          children: [
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: "Công việc"),
            ),
            TextField(
              controller: location,
              decoration: InputDecoration(labelText: "Địa điểm"),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Text(DateFormat("dd/MM/yyyy").format(date)),
                IconButton(
                  icon: Icon(Icons.calendar_month),
                  onPressed: pickDate,
                )
              ],
            ),
            Row(
              children: [
                Text(time.format(context)),
                IconButton(
                  icon: Icon(Icons.access_time),
                  onPressed: pickTime,
                )
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: save,
              child: Text("Lưu"),
            )
          ],
        ),
      ),
    );
  }
}
