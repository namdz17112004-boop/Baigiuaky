import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin notificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();

  const android = AndroidInitializationSettings('@mipmap/ic_launcher');

  await notificationsPlugin.initialize(
    const InitializationSettings(android: android),
  );

  runApp(MyApp());
}

// MODEL
class Task {
  int? id;
  String name;
  String location;
  String time;
  int remind;
  int done;

  Task({
    this.id,
    required this.name,
    required this.location,
    required this.time,
    required this.remind,
    this.done = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'location': location,
    'time': time,
    'remind': remind,
    'done': done,
  };
}

// DATABASE
class DBHelper {
  static Future<Database> initDB() async {
    return openDatabase(
      p.join(await getDatabasesPath(), 'tasks.db'),
      onCreate: (db, version) {
        return db.execute(
          "CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, location TEXT, time TEXT, remind INTEGER, done INTEGER)",
        );
      },
      version: 1,
    );
  }

  static Future insert(Task task) async {
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
        remind: maps[i]['remind'] as int,
        done: maps[i]['done'] as int,
      );
    });
  }

  static Future delete(int id) async {
    final db = await initDB();
    await db.delete('tasks', where: "id = ?", whereArgs: [id]);
  }

  static Future update(Task task) async {
    final db = await initDB();
    await db.update('tasks', task.toMap(),
        where: "id = ?", whereArgs: [task.id]);
  }
}

// NOTIFICATION
Future scheduleNotification(String title, DateTime time) async {
  final scheduledDate = tz.TZDateTime.from(time, tz.local);

  const androidDetails = AndroidNotificationDetails(
    'channel_id',
    'channel_name',
    importance: Importance.max,
    priority: Priority.high,
  );

  const details = NotificationDetails(android: androidDetails);

  await notificationsPlugin.zonedSchedule(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    'Đã đến giờ!',
    scheduledDate,
    details,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.absoluteTime,
  );
}

// UI
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Home(),
    );
  }
}

class Home extends StatefulWidget {
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Task> tasks = [];

  final name = TextEditingController();
  final location = TextEditingController();

  DateTime selected = DateTime.now();
  bool remind = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  void load() async {
    tasks = await DBHelper.getTasks();
    setState(() {});
  }

  void add() async {
    if (name.text.isEmpty) return;

    Task t = Task(
      name: name.text,
      location: location.text,
      time: selected.toIso8601String(),
      remind: remind ? 1 : 0,
    );

    await DBHelper.insert(t);

    if (remind) {
      await scheduleNotification(name.text, selected);
    }

    name.clear();
    location.clear();
    load();
  }

  void toggleDone(Task t) async {
    t.done = t.done == 1 ? 0 : 1;
    await DBHelper.update(t);
    load();
  }

  void deleteTask(int id) async {
    await DBHelper.delete(id);
    load();
  }

  Future pickDate() async {
    DateTime? d = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => selected = d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("🔥 Nhắc việc PRO")),
      body: Padding(
        padding: EdgeInsets.all(10),
        child: Column(
          children: [
            // FORM
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              elevation: 5,
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Column(
                  children: [
                    TextField(
                      controller: name,
                      decoration: InputDecoration(labelText: "Tên công việc"),
                    ),
                    TextField(
                      controller: location,
                      decoration: InputDecoration(labelText: "Địa điểm"),
                    ),
                    Row(
                      children: [
                        Text(DateFormat("dd/MM/yyyy").format(selected)),
                        IconButton(
                          icon: Icon(Icons.calendar_month),
                          onPressed: pickDate,
                        )
                      ],
                    ),
                    SwitchListTile(
                      title: Text("Nhắc việc"),
                      value: remind,
                      onChanged: (v) => setState(() => remind = v),
                    ),
                    ElevatedButton(
                      onPressed: add,
                      child: Text("Thêm"),
                    )
                  ],
                ),
              ),
            ),

            // LIST
            Expanded(
              child: ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (_, i) {
                  var t = tasks[i];
                  return Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                    elevation: 4,
                    child: ListTile(
                      leading: Icon(
                        t.done == 1
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: Colors.green,
                      ),
                      title: Text(
                        t.name,
                        style: TextStyle(
                          decoration: t.done == 1
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        "${t.location}\n${DateFormat("dd/MM/yyyy").format(DateTime.parse(t.time))}",
                      ),
                      isThreeLine: true,
                      onTap: () => toggleDone(t),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.red),
                        onPressed: () => deleteTask(t.id!),
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}