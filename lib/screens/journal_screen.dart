import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../models/journal_entry.dart';
import '../models/app_user.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();
  String _selectedMood = '😊';
  List<JournalEntry> _entries = [];
  bool _isLoading = true;
  late StorageService _storageService;
  AppUser? _currentUser;

  @override
  void initState() {
    super.initState();
    _storageService = Provider.of<StorageService>(context, listen: false);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final currentUser = await _storageService.getCurrentUser();
      if (currentUser == null) {
        throw Exception('No user logged in');
      }

      setState(() {
        _currentUser = currentUser;
      });

      final entries = await _storageService.getJournalEntries(currentUser.id);
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading journal entries: $e')),
        );
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addEntry() async {
    if (!_formKey.currentState!.validate() || _currentUser == null) return;

    try {
      final entry = JournalEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: _currentUser!.id,
        content: _contentController.text.trim(),
        timestamp: DateTime.now(),
        mood: _selectedMood,
      );

      await _storageService.createJournalEntry(entry);
      _contentController.clear();
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journal entry added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding journal entry: $e')),
        );
      }
    }
  }

  Future<void> _deleteEntry(JournalEntry entry) async {
    try {
      await _storageService.deleteJournalEntry(entry.id);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Journal entry deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting journal entry: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal'),
      ),
      body: Column(
        children: [
          // Add Entry Form
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: 'How are you feeling today?',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your thoughts';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Mood Selection
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildMoodButton('😊'),
                      _buildMoodButton('😐'),
                      _buildMoodButton('😢'),
                      _buildMoodButton('😡'),
                      _buildMoodButton('😴'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _addEntry,
                    child: const Text('Add Entry'),
                  ),
                ],
              ),
            ),
          ),
          // Journal Entries List
          Expanded(
            child: _entries.isEmpty
                ? const Center(
                    child: Text('No journal entries yet. Start by adding one!'),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    entry.mood,
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  Text(
                                    _formatDate(entry.timestamp),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(entry.content),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () => _deleteEntry(entry),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodButton(String mood) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedMood = mood;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _selectedMood == mood ? Colors.blue.shade100 : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            mood,
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }
}
