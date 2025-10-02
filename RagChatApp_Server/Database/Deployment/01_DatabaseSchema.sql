IF OBJECT_ID(N'[__EFMigrationsHistory]') IS NULL
BEGIN
    CREATE TABLE [__EFMigrationsHistory] (
        [MigrationId] nvarchar(150) NOT NULL,
        [ProductVersion] nvarchar(32) NOT NULL,
        CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
    );
END;
GO

BEGIN TRANSACTION;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250916082934_InitialCreate'
)
BEGIN
    CREATE TABLE [Documents] (
        [Id] int NOT NULL IDENTITY,
        [FileName] nvarchar(255) NOT NULL,
        [ContentType] nvarchar(100) NOT NULL,
        [Size] bigint NOT NULL,
        [Content] nvarchar(max) NOT NULL,
        [UploadedAt] datetime2 NOT NULL,
        [ProcessedAt] datetime2 NULL,
        [Status] nvarchar(50) NOT NULL,
        CONSTRAINT [PK_Documents] PRIMARY KEY ([Id])
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250916082934_InitialCreate'
)
BEGIN
    CREATE TABLE [DocumentChunks] (
        [Id] int NOT NULL IDENTITY,
        [DocumentId] int NOT NULL,
        [ChunkIndex] int NOT NULL,
        [Content] nvarchar(max) NOT NULL,
        [HeaderContext] nvarchar(max) NULL,
        [Embedding] VARBINARY(MAX) NULL,
        [CreatedAt] datetime2 NOT NULL,
        CONSTRAINT [PK_DocumentChunks] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_DocumentChunks_Documents_DocumentId] FOREIGN KEY ([DocumentId]) REFERENCES [Documents] ([Id]) ON DELETE CASCADE
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250916082934_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_DocumentChunks_DocumentId] ON [DocumentChunks] ([DocumentId]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250916082934_InitialCreate'
)
BEGIN
    CREATE UNIQUE INDEX [IX_DocumentChunks_DocumentId_ChunkIndex] ON [DocumentChunks] ([DocumentId], [ChunkIndex]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250916082934_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_Documents_FileName] ON [Documents] ([FileName]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250916082934_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_Documents_Status] ON [Documents] ([Status]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250916082934_InitialCreate'
)
BEGIN
    CREATE INDEX [IX_Documents_UploadedAt] ON [Documents] ([UploadedAt]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250916082934_InitialCreate'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20250916082934_InitialCreate', N'8.0.4');
END;
GO

COMMIT;
GO

BEGIN TRANSACTION;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250929104126_ImplementMultipleEmbeddingTables'
)
BEGIN
    DECLARE @var0 sysname;
    SELECT @var0 = [d].[name]
    FROM [sys].[default_constraints] [d]
    INNER JOIN [sys].[columns] [c] ON [d].[parent_column_id] = [c].[column_id] AND [d].[parent_object_id] = [c].[object_id]
    WHERE ([d].[parent_object_id] = OBJECT_ID(N'[DocumentChunks]') AND [c].[name] = N'Embedding');
    IF @var0 IS NOT NULL EXEC(N'ALTER TABLE [DocumentChunks] DROP CONSTRAINT [' + @var0 + '];');
    ALTER TABLE [DocumentChunks] DROP COLUMN [Embedding];
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250929104126_ImplementMultipleEmbeddingTables'
)
BEGIN
    ALTER TABLE [Documents] ADD [Path] nvarchar(500) NULL;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250929104126_ImplementMultipleEmbeddingTables'
)
BEGIN
    ALTER TABLE [DocumentChunks] ADD [Details] nvarchar(max) NULL;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250929104126_ImplementMultipleEmbeddingTables'
)
BEGIN
    ALTER TABLE [DocumentChunks] ADD [Notes] nvarchar(max) NULL;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250929104126_ImplementMultipleEmbeddingTables'
)
BEGIN
    ALTER TABLE [DocumentChunks] ADD [UpdatedAt] datetime2 NOT NULL DEFAULT '0001-01-01T00:00:00.0000000';
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250929104126_ImplementMultipleEmbeddingTables'
)
BEGIN
    CREATE TABLE [DocumentChunkContentEmbeddings] (
        [Id] int NOT NULL IDENTITY,
        [DocumentChunkId] int NOT NULL,
        [Embedding] VARBINARY(MAX) NOT NULL,
        [CreatedAt] datetime2 NOT NULL,
        [UpdatedAt] datetime2 NOT NULL,
        CONSTRAINT [PK_DocumentChunkContentEmbeddings] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_DocumentChunkContentEmbeddings_DocumentChunks_DocumentChunkId] FOREIGN KEY ([DocumentChunkId]) REFERENCES [DocumentChunks] ([Id]) ON DELETE CASCADE
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250929104126_ImplementMultipleEmbeddingTables'
)
BEGIN
    CREATE TABLE [DocumentChunkDetailsEmbeddings] (
        [Id] int NOT NULL IDENTITY,
        [DocumentChunkId] int NOT NULL,
        [Embedding] VARBINARY(MAX) NOT NULL,
        [CreatedAt] datetime2 NOT NULL,
        [UpdatedAt] datetime2 NOT NULL,
        CONSTRAINT [PK_DocumentChunkDetailsEmbeddings] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_DocumentChunkDetailsEmbeddings_DocumentChunks_DocumentChunkId] FOREIGN KEY ([DocumentChunkId]) REFERENCES [DocumentChunks] ([Id]) ON DELETE CASCADE
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250929104126_ImplementMultipleEmbeddingTables'
)
BEGIN
    CREATE TABLE [DocumentChunkHeaderContextEmbeddings] (
        [Id] int NOT NULL IDENTITY,
        [DocumentChunkId] int NOT NULL,
        [Embedding] VARBINARY(MAX) NOT NULL,
        [CreatedAt] datetime2 NOT NULL,
        [UpdatedAt] datetime2 NOT NULL,
        CONSTRAINT [PK_DocumentChunkHeaderContextEmbeddings] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_DocumentChunkHeaderContextEmbeddings_DocumentChunks_DocumentChunkId] FOREIGN KEY ([DocumentChunkId]) REFERENCES [DocumentChunks] ([Id]) ON DELETE CASCADE
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250929104126_ImplementMultipleEmbeddingTables'
)
BEGIN
    CREATE TABLE [DocumentChunkNotesEmbeddings] (
        [Id] int NOT NULL IDENTITY,
        [DocumentChunkId] int NOT NULL,
        [Embedding] VARBINARY(MAX) NOT NULL,
        [CreatedAt] datetime2 NOT NULL,
        [UpdatedAt] datetime2 NOT NULL,
        CONSTRAINT [PK_DocumentChunkNotesEmbeddings] PRIMARY KEY ([Id]),
        CONSTRAINT [FK_DocumentChunkNotesEmbeddings_DocumentChunks_DocumentChunkId] FOREIGN KEY ([DocumentChunkId]) REFERENCES [DocumentChunks] ([Id]) ON DELETE CASCADE
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250929104126_ImplementMultipleEmbeddingTables'
)
BEGIN
    CREATE TABLE [SemanticCache] (
        [Id] int NOT NULL IDENTITY,
        [SearchQuery] nvarchar(1000) NOT NULL,
        [ResultContent] nvarchar(max) NOT NULL,
        [ResultEmbedding] VARBINARY(MAX) NOT NULL,
        [CreatedAt] datetime2 NOT NULL,
        CONSTRAINT [PK_SemanticCache] PRIMARY KEY ([Id])
    );
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250929104126_ImplementMultipleEmbeddingTables'
)
BEGIN
    CREATE UNIQUE INDEX [IX_DocumentChunkContentEmbeddings_DocumentChunkId] ON [DocumentChunkContentEmbeddings] ([DocumentChunkId]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250929104126_ImplementMultipleEmbeddingTables'
)
BEGIN
    CREATE UNIQUE INDEX [IX_DocumentChunkDetailsEmbeddings_DocumentChunkId] ON [DocumentChunkDetailsEmbeddings] ([DocumentChunkId]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250929104126_ImplementMultipleEmbeddingTables'
)
BEGIN
    CREATE UNIQUE INDEX [IX_DocumentChunkHeaderContextEmbeddings_DocumentChunkId] ON [DocumentChunkHeaderContextEmbeddings] ([DocumentChunkId]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250929104126_ImplementMultipleEmbeddingTables'
)
BEGIN
    CREATE UNIQUE INDEX [IX_DocumentChunkNotesEmbeddings_DocumentChunkId] ON [DocumentChunkNotesEmbeddings] ([DocumentChunkId]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250929104126_ImplementMultipleEmbeddingTables'
)
BEGIN
    CREATE INDEX [IX_SemanticCache_CreatedAt] ON [SemanticCache] ([CreatedAt]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250929104126_ImplementMultipleEmbeddingTables'
)
BEGIN
    CREATE INDEX [IX_SemanticCache_SearchQuery] ON [SemanticCache] ([SearchQuery]);
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250929104126_ImplementMultipleEmbeddingTables'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20250929104126_ImplementMultipleEmbeddingTables', N'8.0.4');
END;
GO

COMMIT;
GO

BEGIN TRANSACTION;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250930065546_AddMultiProviderSupport'
)
BEGIN
    ALTER TABLE [Documents] ADD [Notes] nvarchar(max) NULL;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250930065546_AddMultiProviderSupport'
)
BEGIN
    ALTER TABLE [Documents] ADD [UploadedBy] nvarchar(255) NULL;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250930065546_AddMultiProviderSupport'
)
BEGIN
    ALTER TABLE [DocumentChunkNotesEmbeddings] ADD [Model] nvarchar(100) NULL;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250930065546_AddMultiProviderSupport'
)
BEGIN
    ALTER TABLE [DocumentChunkHeaderContextEmbeddings] ADD [Model] nvarchar(100) NULL;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250930065546_AddMultiProviderSupport'
)
BEGIN
    ALTER TABLE [DocumentChunkDetailsEmbeddings] ADD [Model] nvarchar(100) NULL;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250930065546_AddMultiProviderSupport'
)
BEGIN
    ALTER TABLE [DocumentChunkContentEmbeddings] ADD [Model] nvarchar(100) NULL;
END;
GO

IF NOT EXISTS (
    SELECT * FROM [__EFMigrationsHistory]
    WHERE [MigrationId] = N'20250930065546_AddMultiProviderSupport'
)
BEGIN
    INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
    VALUES (N'20250930065546_AddMultiProviderSupport', N'8.0.4');
END;
GO

COMMIT;
GO

