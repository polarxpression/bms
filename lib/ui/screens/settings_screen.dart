import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:bms/state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppStateProvider.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
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
          ListTile(
            leading: const Icon(Icons.cloud_upload, color: Colors.purpleAccent),
            title: const Text('Configuração de Imagens (ImgBB)'),
            subtitle: Text(
              state.imgbbApiKey.isEmpty
                  ? 'Não configurado'
                  : 'Chave API Configurada',
            ),
            trailing: const Icon(Icons.edit, color: Colors.grey),
            onTap: () {
              _showImgbbDialog(context, state);
            },
          ),
          const Divider(color: Colors.white10),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'GERENCIAMENTO DE DADOS',
              style: TextStyle(
                color: Color(0xFFEC4899),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.branding_watermark, color: Colors.cyanAccent),
            title: const Text('Gerenciar Marcas'),
            subtitle: Text('${state.brands.length} marcas cadastradas'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _showMetadataManager(
              context,
              state,
              'Marcas',
              state.brands,
              state.addBrand,
              state.deleteBrand,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.model_training, color: Colors.lightGreenAccent),
            title: const Text('Gerenciar Modelos'),
            subtitle: Text('${state.models.length} modelos cadastrados'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _showMetadataManager(
              context,
              state,
              'Modelos',
              state.models,
              state.addModel,
              state.deleteModel,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.category, color: Colors.yellowAccent),
            title: const Text('Gerenciar Tipos'),
            subtitle: Text('${state.types.length} tipos cadastrados'),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => _showMetadataManager(
              context,
              state,
              'Tipos',
              state.types,
              state.addType,
              state.deleteType,
            ),
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
            subtitle: Text('3.2.0 - Metadata CRUD & Barcode Search'),
          ),
          const SizedBox(height: 32),
          Center(
            child: Opacity(
              opacity: 0.5,
              child: SvgPicture.asset(
                'assets/icons/logo-white.svg',
                height: 40,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showMetadataManager(
    BuildContext context,
    AppState state,
    String title,
    List<String> items,
    Future<void> Function(String) onAdd,
    Future<void> Function(String) onDelete,
  ) {
    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              MediaQuery.of(context).viewInsets.bottom + 32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gerenciar $title',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Novo(a) $title...',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () async {
                        final val = controller.text.trim();
                        if (val.isNotEmpty) {
                          await onAdd(val);
                          controller.clear();
                        }
                      },
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4,
                  ),
                  child: ListenableBuilder(
                    listenable: state,
                    builder: (context, _) {
                      List<String> currentItems = [];
                      if (title == 'Marcas') currentItems = state.brands;
                      if (title == 'Modelos') currentItems = state.models;
                      if (title == 'Tipos') currentItems = state.types;

                      if (currentItems.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text(
                              'Nenhum item cadastrado.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: currentItems.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white10, height: 1),
                        itemBuilder: (context, index) {
                          final item = currentItems[index];
                          return ListTile(
                            title: Text(
                              item,
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.redAccent,
                                size: 20,
                              ),
                              onPressed: () => onDelete(item),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
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

  void _showImgbbDialog(BuildContext context, AppState state) {
    final controller = TextEditingController(text: state.imgbbApiKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text(
          'Configurar ImgBB API',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Insira sua chave de API do ImgBB para permitir o upload de imagens.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              state.updateImgbbApiKey(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
