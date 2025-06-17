import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/storage_service.dart';
import '../models/app_user.dart';
import '../models/planet_model.dart';
import 'dart:math' as math;
import '../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  _GoalsScreenState createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  AppUser? _user;
  final _goalController = TextEditingController();
  List<Goal> _goals = [];
  bool _isLoading = true;
  late AnimationController _celebrationController;
  late Animation<double> _celebrationAnimation;
  bool _isCelebrating = false;
  bool _isEditing = false;
  int? _editingIndex;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _celebrationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _celebrationAnimation = CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUser();
  }

  @override
  void dispose() {
    _goalController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final storageService = Provider.of<StorageService>(context, listen: false);
      final user = await storageService.getCurrentUser();
      if (user != null) {
        setState(() {
          _user = user;
          _goals = user.goals;
        });
      }
    } catch (e) {
      print('Error loading user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _levelUpPlanet() async {
    if (_user == null) return;

    final storageService = Provider.of<StorageService>(context, listen: false);
    final planet = await storageService.getPlanet(_user!.id);

    if (planet != null) {
      final updatedPlanet = Planet(
        id: planet.id,
        userId: planet.userId,
        name: planet.name,
        level: planet.level + 1,
        experience: planet.experience + 100,
        evolutionStage: _getNextEvolutionStage(planet.evolutionStage),
      );

      await storageService.updatePlanet(updatedPlanet);

      setState(() {
        _isCelebrating = true;
      });

      _celebrationController.forward().then((_) {
        setState(() {
          _isCelebrating = false;
        });
        _celebrationController.reset();
      });

      // Show level up dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('🎉 Level Up! 🎉'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Your planet has reached level ${updatedPlanet.level}!'),
                  const SizedBox(height: 16),
                  Text('New Evolution Stage: ${updatedPlanet.evolutionStage}'),
                  const SizedBox(height: 16),
                  const Icon(
                    Icons.auto_awesome,
                    size: 48,
                    color: Colors.amber,
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Awesome!'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      }
    }
  }

  String _getNextEvolutionStage(String currentStage) {
    switch (currentStage) {
      case 'seed':
        return 'sprout';
      case 'sprout':
        return 'sapling';
      case 'sapling':
        return 'tree';
      case 'tree':
        return 'forest';
      default:
        return currentStage;
    }
  }

  Future<List<Goal>> _fetchGoalsFromFirebase(String userId) async {
    final firebaseService = FirebaseService();
    final doc = await firebaseService.firestore.collection('users').doc(userId).get();
    final data = doc.data();
    if (data != null && data['goals'] != null) {
      return (data['goals'] as List)
          .map((g) => Goal.fromMap(Map<String, dynamic>.from(g)))
          .toList();
    }
    return [];
  }

  Future<void> _saveGoal() async {
    if (_user == null || _goalController.text.trim().isEmpty) return;
    setState(() { _isLoading = true; });
    try {
      final storageService = Provider.of<StorageService>(context, listen: false);
      final firebaseService = FirebaseService();
      final updatedGoals = List<Goal>.from(_goals);
      if (_isEditing && _editingIndex != null) {
        updatedGoals[_editingIndex!] = Goal(
          id: updatedGoals[_editingIndex!].id,
          text: _goalController.text.trim(),
          isCompleted: updatedGoals[_editingIndex!].isCompleted,
          createdAt: updatedGoals[_editingIndex!].createdAt,
          completionStatusByDate: updatedGoals[_editingIndex!].completionStatusByDate,
        );
      } else {
        updatedGoals.add(Goal(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: _goalController.text.trim(),
          createdAt: DateTime.now(),
          completionStatusByDate: {},
        ));
      }
      await storageService.updateUserGoals(_user!.id, updatedGoals);
      // Upload to Firebase
      await firebaseService.firestore.collection('users').doc(_user!.id).set({
        'goals': updatedGoals.map((g) => g.toMap()).toList(),
      }, SetOptions(merge: true));
      // Reload goals from Firebase to ensure UI is up to date
      final freshGoals = await _fetchGoalsFromFirebase(_user!.id);
      setState(() { _goals = freshGoals; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Goal updated successfully' : 'Goal added successfully')),
        );
      }
      _goalController.clear();
      setState(() { _isEditing = false; _editingIndex = null; });
    } catch (e) {
      print('Error saving goal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving goal: $e')),
        );
      }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  Future<void> _toggleGoalCompletion(int index) async {
    if (_user == null) return;
    setState(() { _isLoading = true; });
    try {
      final storageService = Provider.of<StorageService>(context, listen: false);
      final firebaseService = FirebaseService();
      final updatedGoals = List<Goal>.from(_goals);
      final goal = updatedGoals[index];
      final todayKey = '${DateTime.now().toIso8601String().substring(0, 10)}_${_user!.id}';
      final newStatus = !(goal.completionStatusByDate?[todayKey] ?? false);
      final newCompletionStatus = Map<String, bool>.from(goal.completionStatusByDate ?? {});
      newCompletionStatus[todayKey] = newStatus;
      updatedGoals[index] = goal.copyWith(completionStatusByDate: newCompletionStatus);
      await storageService.updateUserGoals(_user!.id, updatedGoals);
      // Upload to Firebase
      await firebaseService.firestore.collection('users').doc(_user!.id).set({
        'goals': updatedGoals.map((g) => g.toMap()).toList(),
      }, SetOptions(merge: true));
      await _loadUser();
      // Check if all goals are completed for today
      if (updatedGoals.every((g) => g.completionStatusByDate?[todayKey] ?? false)) {
        await _levelUpPlanet();
      }
    } catch (e) {
      print('Error toggling goal completion: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating goal: $e')),
        );
      }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  Future<void> _deleteGoal(int index) async {
    if (_user == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final storageService = Provider.of<StorageService>(context, listen: false);
      final updatedGoals = List<Goal>.from(_goals);
      updatedGoals.removeAt(index);
      await storageService.updateUserGoals(_user!.id, updatedGoals);
      await _loadUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goal deleted successfully')),
        );
      }
    } catch (e) {
      print('Error deleting goal: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting goal: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _editGoal(int index) {
    setState(() {
      _isEditing = true;
      _editingIndex = index;
      _goalController.text = _goals[index].text;
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _editingIndex = null;
      _goalController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _isEditing ? 'Edit Goal' : 'Add New Goal',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _goalController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Enter your goal...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveGoal,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(_isEditing ? 'Update Goal' : 'Add Goal'),
                      ),
                    ),
                    if (_isEditing) ...[
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _cancelEdit,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.grey,
                        ),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _goals.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flag_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No goals yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add your first goal above',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _goals.length,
              itemBuilder: (context, index) {
                final goal = _goals[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: Checkbox(
                      value: goal.completionStatusByDate?['${DateTime.now().toIso8601String().substring(0, 10)}_${_user!.id}'] ?? false,
                      onChanged: (value) => _toggleGoalCompletion(index),
                      activeColor: Colors.green,
                    ),
                    title: Text(
                      goal.text,
                      style: TextStyle(
                        decoration: goal.completionStatusByDate?['${DateTime.now().toIso8601String().substring(0, 10)}_${_user!.id}'] ?? false
                            ? TextDecoration.lineThrough
                            : null,
                        color: goal.completionStatusByDate?['${DateTime.now().toIso8601String().substring(0, 10)}_${_user!.id}'] ?? false
                            ? Colors.grey
                            : null,
                      ),
                    ),
                    subtitle: Text(
                      'Created: ${_formatDate(goal.createdAt)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editGoal(index),
                          tooltip: 'Edit Goal',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteGoal(index),
                          tooltip: 'Delete Goal',
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
