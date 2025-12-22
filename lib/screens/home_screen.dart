import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class ServiceCategory {
  final String id;
  final String name;
  final String? description;
  final String icon;

  ServiceCategory({
    required this.id,
    required this.name,
    this.description,
    required this.icon,
  });

  factory ServiceCategory.fromMap(Map<String, dynamic> map) {
    return ServiceCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      icon: (map['icon'] as String?) ?? 'misc',
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool loading = true;
  List<ServiceCategory> categories = [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final res = await supabase
          .from('service_categories')
          .select()
          .order('sort_order');

      setState(() {
        categories = (res as List)
            .map((e) => ServiceCategory.fromMap(e as Map<String, dynamic>))
            .toList();
        loading = false;
      });
    } catch (e) {
      setState(() => loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar categorias: $e')),
        );
      }
    }
  }

  IconData _mapCategoryIcon(String icon) {
    switch (icon) {
      case 'car':
        return Icons.directions_car;
      case 'ac_unit':
        return Icons.ac_unit;
      case 'cleaning_services':
        return Icons.cleaning_services;
      case 'yard':
        return Icons.yard;
      case 'plumbing':
        return Icons.plumbing;
      case 'more_horiz':
        return Icons.more_horiz;
      case 'handyman':
        return Icons.handyman;
      case 'spa':
        return Icons.spa;
      case 'construction':
        return Icons.construction;
      case 'event':
        return Icons.event;
      default:
        // 👇 importante pra resolver o erro “non-null value must be returned”
        return Icons.miscellaneous_services;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Renthus Service'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCategories,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Icon(_mapCategoryIcon(cat.icon)),
                      title: Text(cat.name),
                      subtitle: cat.description != null
                          ? Text(cat.description!)
                          : null,
                      onTap: () {
                        // aqui depois você abre a tela de subcategorias / serviços
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
