class Board {
  final String id;
  final String userId;
  final String name;
  final String description;
  final String color;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Board({
    required this.id,
    required this.userId,
    required this.name,
    required this.description,
    required this.color,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      description: json['description'] ?? '',
      color: json['color'] ?? '#3B82F6',
      isActive: json['is_active'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Board copyWith({
    String? name,
    String? description,
    String? color,
    bool? isActive,
  }) {
    return Board(
      id: id,
      userId: userId,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'description': description,
      'color': color,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class BoardCard {
  final String id;
  final String columnId;
  final String title;
  final String description;
  final int position;
  final String color;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  BoardCard({
    required this.id,
    required this.columnId,
    required this.title,
    required this.description,
    required this.position,
    required this.color,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BoardCard.fromJson(Map<String, dynamic> json) {
    return BoardCard(
      id: json['id'],
      columnId: json['column_id'],
      title: json['title'],
      description: json['description'] ?? '',
      position: json['position'],
      color: json['color'] ?? '#FFFFFF',
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  BoardCard copyWith({
    String? title,
    String? description,
    int? position,
    String? color,
    DateTime? dueDate,
  }) {
    return BoardCard(
      id: id,
      columnId: columnId,
      title: title ?? this.title,
      description: description ?? this.description,
      position: position ?? this.position,
      color: color ?? this.color,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'column_id': columnId,
      'title': title,
      'description': description,
      'position': position,
      'color': color,
      'due_date': dueDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class BoardColumn {
  final String id;
  final String boardId;
  final String name;
  final int position;
  final String color;
  final DateTime createdAt;
  final DateTime updatedAt;

  BoardColumn({
    required this.id,
    required this.boardId,
    required this.name,
    required this.position,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BoardColumn.fromJson(Map<String, dynamic> json) {
    return BoardColumn(
      id: json['id'],
      boardId: json['board_id'],
      name: json['name'],
      position: json['position'],
      color: json['color'] ?? '#6B7280',
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  BoardColumn copyWith({
    String? name,
    int? position,
    String? color,
  }) {
    return BoardColumn(
      id: id,
      boardId: boardId,
      name: name ?? this.name,
      position: position ?? this.position,
      color: color ?? this.color,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'board_id': boardId,
      'name': name,
      'position': position,
      'color': color,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class BoardCreate {
  final String name;
  final String description;
  final String color;

  BoardCreate({
    required this.name,
    this.description = '',
    this.color = '#3B82F6',
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'color': color,
    };
  }
}

class CardCreate {
  final String title;
  final String description;
  final int position;
  final String color;
  final DateTime? dueDate;

  CardCreate({
    required this.title,
    this.description = '',
    this.position = 0,
    this.color = '#FFFFFF',
    this.dueDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'position': position,
      'color': color,
      'due_date': dueDate?.toIso8601String(),
    };
  }
}

class CardMove {
  final String columnId;
  final int position;

  CardMove({
    required this.columnId,
    required this.position,
  });

  Map<String, dynamic> toJson() {
    return {
      'column_id': columnId,
      'position': position,
    };
  }
}

class ColumnCreate {
  final String name;
  final int position;
  final String color;

  ColumnCreate({
    required this.name,
    this.position = 0,
    this.color = '#6B7280',
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'position': position,
      'color': color,
    };
  }
}
