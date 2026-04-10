import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(MyApp());
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
          "CREATE TABLE tasks(id INTEGER PRIMARY KEY, name TEXT, location TEXT, time TEXT, done INTEGER)",
        );
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
    await db.update(
      'tasks',
      task.toMap(),
      where: "id = ?",
      whereArgs: [task.id],
    );
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

// ================= HOME (DANH SÁCH) =================
class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Task> tasks = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    tasks = await DBHelper.getTasks();
    setState(() {});
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("📋 Lịch nhắc")),
      body: tasks.isEmpty
          ? Center(child: Text("Chưa có lịch nào"))
          : ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (_, i) {
          var t = tasks[i];
          return Card(
            margin: EdgeInsets.all(10),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
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

      // 🔥 NÚT THÊM
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddTaskScreen()),
          );

          if (result == true) {
            load(); // reload list
          }
        },
      ),
    );
  }
}

// ================= ADD SCREEN =================
class AddTaskScreen extends StatefulWidget {
  @override
  _AddTaskScreenState createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final name = TextEditingController();
  final location = TextEditingController();
  DateTime selected = DateTime.now();

  Future pickDate() async {
    DateTime? d = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => selected = d);
  }

  void save() async {
    if (name.text.isEmpty) return;

    Task t = Task(
      name: name.text,
      location: location.text,
      time: selected.toString(),
    );

    await DBHelper.insert(t);

    Navigator.pop(context, true); // 🔥 quay lại + reload
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
              decoration: InputDecoration(labelText: "Tên công việc"),
            ),
            TextField(
              controller: location,
              decoration: InputDecoration(labelText: "Địa điểm"),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Text(DateFormat("dd/MM/yyyy").format(selected)),
                IconButton(
                  icon: Icon(Icons.calendar_month),
                  onPressed: pickDate,
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
