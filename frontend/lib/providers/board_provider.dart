import 'package:flutter_riverpod/legacy.dart';
import 'package:jira_copycat/providers/auth_provider.dart';

import '../models/board.dart';
import '../services/api_service.dart';
import '../utils/logger.dart';

final boardStateProvider = StateNotifierProvider<BoardNotifier, BoardState>((ref) {
  return BoardNotifier(ref.read(apiServiceProvider));
});

class BoardNotifier extends StateNotifier<BoardState> {
  final ApiService _apiService;

  BoardNotifier(this._apiService) : super(BoardState());

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> createBoard(BoardCreate boardCreate) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      Logger.logInfo('Creating board: ${boardCreate.name}', context: 'BOARD_PROVIDER');
      final board = await _apiService.createBoard(boardCreate);
      state = state.copyWith(
        boards: [...state.boards, board],
        isLoading: false,
      );
      Logger.logInfo('Board created successfully: ${board.id}', context: 'BOARD_PROVIDER');
    } catch (e, stackTrace) {
      Logger.logError('Failed to create board: ${boardCreate.name}', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'BOARD_PROVIDER');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> createCard(String columnId, CardCreate cardCreate) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final card = await _apiService.createCard(columnId, cardCreate);
      final updatedCardsByColumn = Map<String, List<BoardCard>>.from(state.cardsByColumn);
      updatedCardsByColumn[columnId] = [...(updatedCardsByColumn[columnId] ?? []), card];

      state = state.copyWith(
        cardsByColumn: updatedCardsByColumn,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> createColumn(ColumnCreate columnCreate) async {
    if (state.currentBoard == null) return;
    
    state = state.copyWith(isLoading: true, error: null);
    try {
      final column = await _apiService.createColumn(state.currentBoard!.id, columnCreate);
      state = state.copyWith(
        columns: [...state.columns, column],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> deleteBoard(String boardId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _apiService.deleteBoard(boardId);
      final updatedBoards = state.boards.where((board) => board.id != boardId).toList();
      
      state = state.copyWith(
        boards: updatedBoards,
        currentBoard: state.currentBoard?.id == boardId ? null : state.currentBoard,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> deleteCard(String cardId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _apiService.deleteCard(cardId);
      final updatedCardsByColumn = Map<String, List<BoardCard>>.from(state.cardsByColumn);
      
      // Remove card from all columns
      for (final columnId in updatedCardsByColumn.keys) {
        updatedCardsByColumn[columnId] = updatedCardsByColumn[columnId]!
            .where((card) => card.id != cardId)
            .toList();
      }

      state = state.copyWith(
        cardsByColumn: updatedCardsByColumn,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> deleteColumn(String columnId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _apiService.deleteColumn(columnId);
      final updatedColumns = state.columns.where((column) => column.id != columnId).toList();
      final updatedCardsByColumn = Map<String, List<BoardCard>>.from(state.cardsByColumn);
      updatedCardsByColumn.remove(columnId);

      state = state.copyWith(
        columns: updatedColumns,
        cardsByColumn: updatedCardsByColumn,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadBoards() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      Logger.logInfo('Loading boards', context: 'BOARD_PROVIDER');
      final boards = await _apiService.getBoards();
      state = state.copyWith(
        boards: boards,
        isLoading: false,
      );
      Logger.logInfo('Boards loaded successfully: ${boards.length} boards found', context: 'BOARD_PROVIDER');
    } catch (e, stackTrace) {
      Logger.logError('Failed to load boards', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'BOARD_PROVIDER');
      
      // Check if it's an authentication error
      String errorMessage = e.toString();
      if (e.toString().contains('401')) {
        errorMessage = 'Authentication required. Please log in again.';
        Logger.logWarning('Authentication error detected in loadBoards', context: 'BOARD_PROVIDER');
      }
      
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
    }
  }

  Future<void> moveCard(String cardId, String newColumnId, int newPosition) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedCard = await _apiService.moveCard(cardId, CardMove(
        columnId: newColumnId,
        position: newPosition,
      ));
      
      final updatedCardsByColumn = Map<String, List<BoardCard>>.from(state.cardsByColumn);
      
      // Remove card from old column
      for (final columnId in updatedCardsByColumn.keys) {
        updatedCardsByColumn[columnId] = updatedCardsByColumn[columnId]!
            .where((card) => card.id != cardId)
            .toList();
      }
      
      // Add card to new column
      final newColumnCards = updatedCardsByColumn[newColumnId] ?? [];
      newColumnCards.insert(newPosition, updatedCard);
      updatedCardsByColumn[newColumnId] = newColumnCards;

      state = state.copyWith(
        cardsByColumn: updatedCardsByColumn,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> selectBoard(String boardId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      Logger.logInfo('Selecting board: $boardId', context: 'BOARD_PROVIDER');
      final board = await _apiService.getBoard(boardId);
      final columns = await _apiService.getColumns(boardId);
      
      // Load cards for each column
      final Map<String, List<BoardCard>> cardsByColumn = {};
      for (final column in columns) {
        final cards = await _apiService.getCards(column.id);
        cardsByColumn[column.id] = cards;
      }

      state = state.copyWith(
        currentBoard: board,
        columns: columns,
        cardsByColumn: cardsByColumn,
        isLoading: false,
      );
      Logger.logInfo('Board selected successfully: ${board.name} with ${columns.length} columns', context: 'BOARD_PROVIDER');
    } catch (e, stackTrace) {
      Logger.logError('Failed to select board: $boardId', 
        error: e, 
        stackTrace: stackTrace, 
        context: 'BOARD_PROVIDER');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> updateBoard(String boardId, Map<String, dynamic> updates) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedBoard = await _apiService.updateBoard(boardId, updates);
      final updatedBoards = state.boards.map((board) {
        return board.id == boardId ? updatedBoard : board;
      }).toList();

      state = state.copyWith(
        boards: updatedBoards,
        currentBoard: state.currentBoard?.id == boardId ? updatedBoard : state.currentBoard,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> updateCard(String cardId, Map<String, dynamic> updates) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedCard = await _apiService.updateCard(cardId, updates);
      final updatedCardsByColumn = Map<String, List<BoardCard>>.from(state.cardsByColumn);
      
      // Find and update the card in the appropriate column
      for (final columnId in updatedCardsByColumn.keys) {
        final cards = updatedCardsByColumn[columnId]!;
        final cardIndex = cards.indexWhere((card) => card.id == cardId);
        if (cardIndex != -1) {
          cards[cardIndex] = updatedCard;
          break;
        }
      }

      state = state.copyWith(
        cardsByColumn: updatedCardsByColumn,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> updateColumn(String columnId, Map<String, dynamic> updates) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final updatedColumn = await _apiService.updateColumn(columnId, updates);
      final updatedColumns = state.columns.map((column) {
        return column.id == columnId ? updatedColumn : column;
      }).toList();

      state = state.copyWith(
        columns: updatedColumns,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

class BoardState {
  final List<Board> boards;
  final Board? currentBoard;
  final List<BoardColumn> columns;
  final Map<String, List<BoardCard>> cardsByColumn;
  final bool isLoading;
  final String? error;

  BoardState({
    this.boards = const [],
    this.currentBoard,
    this.columns = const [],
    this.cardsByColumn = const {},
    this.isLoading = false,
    this.error,
  });

  BoardState copyWith({
    List<Board>? boards,
    Board? currentBoard,
    List<BoardColumn>? columns,
    Map<String, List<BoardCard>>? cardsByColumn,
    bool? isLoading,
    String? error,
  }) {
    return BoardState(
      boards: boards ?? this.boards,
      currentBoard: currentBoard ?? this.currentBoard,
      columns: columns ?? this.columns,
      cardsByColumn: cardsByColumn ?? this.cardsByColumn,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}