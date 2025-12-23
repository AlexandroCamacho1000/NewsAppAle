import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/remote/remote_article_bloc.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/remote/remote_article_event.dart';
import 'package:news_app_clean_architecture/features/daily_news/presentation/bloc/article/remote/remote_article_state.dart';

import '../../../domain/entities/article.dart';
import '../../widgets/article_tile.dart';
import '../create_article/create_article.dart';

class DailyNews extends StatefulWidget {
  const DailyNews({Key? key}) : super(key: key);

  @override
  _DailyNewsState createState() => _DailyNewsState();
}

class _DailyNewsState extends State<DailyNews> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    print('🏠 DailyNews: initState()');
    
    // Cargar artículos
    Future.microtask(() {
      context.read<RemoteArticlesBloc>().add(const GetArticles());
    });
  }

  Future<void> _refreshArticles() async {
    print('🔄 Refrescando artículos...');
    context.read<RemoteArticlesBloc>().add(const GetArticles());
  }

  Future<void> _deleteArticle(ArticleEntity article) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar artículo'),
        content: Text('¿Estás seguro de eliminar "${article.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Eliminar de Firestore
        await _firestore.collection('articles').doc(article.id).delete();
        
        print('🗑️ Artículo eliminado: ${article.title}');
        
        // ✅✅✅ ESTA ES LA LÍNEA QUE HACE EL REFRESH ✅✅✅
        context.read<RemoteArticlesBloc>().add(const GetArticles());
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Artículo eliminado exitosamente'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
      } catch (e) {
        print('❌ Error al eliminar artículo: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RemoteArticlesBloc, RemoteArticlesState>(
      builder: (context, state) {
        print('📱 Estado del Bloc: $state');
        
        if (state is RemoteArticlesLoading) {
          return Scaffold(
            appBar: _buildAppbar(context),
            body: const Center(child: CupertinoActivityIndicator()),
          );
        }
        
        if (state is RemoteArticlesError) {
          return Scaffold(
            appBar: _buildAppbar(context),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 50, color: Colors.red),
                  const SizedBox(height: 10),
                  Text('Error: ${state.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      context.read<RemoteArticlesBloc>().add(const GetArticles());
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }
        
        if (state is RemoteArticlesDone) {
          return _buildArticlesPage(context, state.articles ?? []);
        }
        
        return Scaffold(
          appBar: _buildAppbar(context),
          body: const Center(child: CupertinoActivityIndicator()),
        );
      },
    );
  }

  AppBar _buildAppbar(BuildContext context) {
    return AppBar(
      title: const Text('Daily News', style: TextStyle(color: Colors.black)),
      backgroundColor: Colors.white,
      elevation: 1,
      actions: [
        // Botón para refrescar manualmente
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.black),
          onPressed: _refreshArticles,
          tooltip: 'Refrescar',
        ),
        // Botón para artículos guardados
        IconButton(
          icon: const Icon(Icons.bookmark, color: Colors.black),
          onPressed: () => _onShowSavedArticlesViewTapped(context),
          tooltip: 'Artículos guardados',
        ),
      ],
    );
  }

  Widget _buildArticlesPage(BuildContext context, List<ArticleEntity> articles) {
    print('📊 Total artículos: ${articles.length}');
    
    if (articles.isEmpty) {
      return Scaffold(
        appBar: _buildAppbar(context),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.newspaper, size: 60, color: Colors.grey),
              SizedBox(height: 20),
              Text('No hay artículos disponibles',
                  style: TextStyle(fontSize: 18, color: Colors.grey)),
              SizedBox(height: 10),
              Text('¡Crea tu primer artículo!',
                  style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _navigateToCreateArticle(context),
          child: const Icon(Icons.add),
        ),
      );
    }
    
    return Scaffold(
      appBar: _buildAppbar(context),
      body: RefreshIndicator(
        onRefresh: _refreshArticles,
        child: ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: articles.length,
          itemBuilder: (context, index) {
            return ArticleWidget(
              article: articles[index],
              onArticlePressed: (article) => _onArticlePressed(context, article),
              isRemovable: true,
              onRemove: (article) => _deleteArticle(article), // ✅ CORREGIDO
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToCreateArticle(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _navigateToCreateArticle(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateArticlePage(),
      ),
    ).then((value) {
      // Si se creó un artículo nuevo, refrescar
      if (value == true) {
        _refreshArticles();
      }
    });
  }

  void _onArticlePressed(BuildContext context, ArticleEntity article) {
    Navigator.pushNamed(context, '/ArticleDetails', arguments: article);
  }

  void _onShowSavedArticlesViewTapped(BuildContext context) {
    Navigator.pushNamed(context, '/SavedArticles');
  }

  @override
  void dispose() {
    super.dispose();
  }
}