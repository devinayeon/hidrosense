import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note_model.dart';

// 1. Buat class ViewModel yang meng-extend Notifier<T>
// T di sini adalah tipe data State yang dipegang (yaitu List<Note>)
class NoteViewModel extends Notifier<List<Note>> {
  
  // build() adalah nilai awal (initial state)
  @override
  List<Note> build() {
    return [
      Note(id: '1', title: 'Testing Riverpod'),
      Note(id: '2', title: 'Riverpod asik'),
    ];
  }

  // Fungsi Tambah Note
  void addNote(String title) {
    if (title.isEmpty) return;
    
    final newNote = Note(
      id: DateTime.now().toString(),
      title: title,
    );

    // Di Riverpod, kita tidak pakai .add(), tapi mengganti objek 'state'
    state = [...state, newNote]; 
  }

  // Fungsi Hapus Note
  void removeNote(String id) {
    state = state.where((note) => note.id != id).toList();
  }
}

// 2. Buat Provider-nya secara Global agar bisa diakses oleh View
final noteProvider = NotifierProvider<NoteViewModel, List<Note>>(() {
  return NoteViewModel();
});