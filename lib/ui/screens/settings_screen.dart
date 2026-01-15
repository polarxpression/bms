import 'package:flutter/material.dart';
import 'package:bms/state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        children: [
          const ListTile(
            leading: Icon(Icons.palette, color: Color(0xFFEC4899)),
            title: Text('Tema'),
            subtitle: Text('Midnight Pink (Fixo)'),
          ),
          const Divider(color: Colors.white10),
          ListTile(
            leading: const Icon(Icons.shelves, color: Colors.orangeAccent),
            title: const Text('Capacidade Padrão da Gôndola'),
            subtitle: Text(
              'Atualmente: ${state.defaultGondolaCapacity} unidades',
            ),
            trailing: const Icon(Icons.edit, color: Colors.grey),
            onTap: () {
              _showCapacityDialog(context, state);
            },
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart, color: Colors.blueAccent),
            title: const Text('Estoque Mínimo Padrão'),
            subtitle: Text(
              'Atualmente: ${state.defaultMinStockThreshold} unidades',
            ),
            trailing: const Icon(Icons.edit, color: Colors.grey),
            onTap: () {
              _showMinStockDialog(context, state);
            },
          ),
          const Divider(color: Colors.white10),
          const ListTile(
            leading: Icon(Icons.storage),
            title: Text('Estrutura de Dados'),
            subtitle: Text('Firebase v3 (Gôndola Separada)'),
          ),
          const Divider(color: Colors.white10),
          const ListTile(
            leading: Icon(Icons.search),
            title: Text('Motor de Busca'),
            subtitle: Text('Tag-Based (Booru Style) v1.1'),
          ),
          const Divider(color: Colors.white10),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Versão'),
            subtitle: Text('3.1.0 - External Buy Feature'),
          ),
        ],
      ),
    );
  }

  void _showCapacityDialog(BuildContext context, AppState state) {
    final controller = TextEditingController(
      text: state.defaultGondolaCapacity.toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text(
          'Definir Capacidade Padrão',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Quantidade',
            helperText: 'Usado quando o limite do item é 0',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) {
                state.updateDefaultCapacity(val);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showMinStockDialog(BuildContext context, AppState state) {
    final controller = TextEditingController(
      text: state.defaultMinStockThreshold.toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text(
          'Definir Estoque Mínimo Padrão',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Quantidade Mínima',
            helperText: 'Alerta para compra quando estoque cair abaixo',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) {
                state.updateDefaultMinStockThreshold(val);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
