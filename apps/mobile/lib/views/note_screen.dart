import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/note_viewmodel.dart';

// Gunakan ConsumerWidget!
class NoteScreen extends ConsumerWidget {
  const NoteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A. MENGAMBIL DATA (LISTEN)
    // ref.watch() bikin widget ini otomatis re-build kalau data noteProvider berubah
    final notes = ref.watch(noteProvider);

    final controller = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Catatan MVVM Riverpod')),
      body: Column(
        children: [
          // Input Field & Tombol Tambah
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'Tulis catatan baru...'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    // B. MEMANGGIL FUNGSI LOGIKA (READ)
                    // Pakai ref.read() + .notifier kalau mau panggil fungsi di ViewModel
                    ref.read(noteProvider.notifier).addNote(controller.text);
                    controller.clear();
                  },
                )
              ],
            ),
          ),

          // List Catatan
          Expanded(
            child: ListView.builder(
              itemCount: notes.length,
              itemBuilder: (context, index) {
                final note = notes[index];
                return ListTile(
                  title: Text(note.title),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      // Panggil fungsi hapus
                      ref.read(noteProvider.notifier).removeNote(note.id);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}