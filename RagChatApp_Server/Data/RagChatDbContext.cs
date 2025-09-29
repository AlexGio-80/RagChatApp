using Microsoft.EntityFrameworkCore;
using RagChatApp_Server.Models;

namespace RagChatApp_Server.Data;

/// <summary>
/// Entity Framework DbContext for RAG Chat Application
/// </summary>
public class RagChatDbContext : DbContext
{
    public RagChatDbContext(DbContextOptions<RagChatDbContext> options) : base(options)
    {
    }

    /// <summary>
    /// Documents table
    /// </summary>
    public DbSet<Document> Documents { get; set; }

    /// <summary>
    /// Document chunks table with embeddings
    /// </summary>
    public DbSet<DocumentChunk> DocumentChunks { get; set; }

    /// <summary>
    /// Document chunk content embeddings table
    /// </summary>
    public DbSet<DocumentChunkContentEmbedding> DocumentChunkContentEmbeddings { get; set; }

    /// <summary>
    /// Document chunk header context embeddings table
    /// </summary>
    public DbSet<DocumentChunkHeaderContextEmbedding> DocumentChunkHeaderContextEmbeddings { get; set; }

    /// <summary>
    /// Document chunk notes embeddings table
    /// </summary>
    public DbSet<DocumentChunkNotesEmbedding> DocumentChunkNotesEmbeddings { get; set; }

    /// <summary>
    /// Document chunk details embeddings table
    /// </summary>
    public DbSet<DocumentChunkDetailsEmbedding> DocumentChunkDetailsEmbeddings { get; set; }

    /// <summary>
    /// Semantic cache for recent searches
    /// </summary>
    public DbSet<SemanticCache> SemanticCache { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Configure Document entity
        modelBuilder.Entity<Document>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.FileName).IsRequired().HasMaxLength(255);
            entity.Property(e => e.ContentType).IsRequired().HasMaxLength(100);
            entity.Property(e => e.Content).IsRequired();
            entity.Property(e => e.Path).HasMaxLength(500);
            entity.Property(e => e.Status).IsRequired().HasMaxLength(50);
            entity.Property(e => e.UploadedAt).IsRequired();

            // Configure indexes for better performance
            entity.HasIndex(e => e.FileName);
            entity.HasIndex(e => e.Status);
            entity.HasIndex(e => e.UploadedAt);
        });

        // Configure DocumentChunk entity
        modelBuilder.Entity<DocumentChunk>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.DocumentId).IsRequired();
            entity.Property(e => e.ChunkIndex).IsRequired();
            entity.Property(e => e.Content).IsRequired();
            entity.Property(e => e.CreatedAt).IsRequired();
            entity.Property(e => e.UpdatedAt).IsRequired();

            // Configure relationship with cascade delete
            entity.HasOne(e => e.Document)
                .WithMany(d => d.Chunks)
                .HasForeignKey(e => e.DocumentId)
                .OnDelete(DeleteBehavior.Cascade);

            // Configure indexes for better performance
            entity.HasIndex(e => e.DocumentId);
            entity.HasIndex(e => new { e.DocumentId, e.ChunkIndex }).IsUnique();
        });

        // Configure DocumentChunkContentEmbedding entity
        modelBuilder.Entity<DocumentChunkContentEmbedding>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.DocumentChunkId).IsRequired();
            entity.Property(e => e.Embedding)
                .HasColumnType("VARBINARY(MAX)")
                .IsRequired();
            entity.Property(e => e.CreatedAt).IsRequired();
            entity.Property(e => e.UpdatedAt).IsRequired();

            // Configure relationship with cascade delete
            entity.HasOne(e => e.DocumentChunk)
                .WithOne(dc => dc.ContentEmbedding)
                .HasForeignKey<DocumentChunkContentEmbedding>(e => e.DocumentChunkId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(e => e.DocumentChunkId).IsUnique();
        });

        // Configure DocumentChunkHeaderContextEmbedding entity
        modelBuilder.Entity<DocumentChunkHeaderContextEmbedding>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.DocumentChunkId).IsRequired();
            entity.Property(e => e.Embedding)
                .HasColumnType("VARBINARY(MAX)")
                .IsRequired();
            entity.Property(e => e.CreatedAt).IsRequired();
            entity.Property(e => e.UpdatedAt).IsRequired();

            // Configure relationship with cascade delete
            entity.HasOne(e => e.DocumentChunk)
                .WithOne(dc => dc.HeaderContextEmbedding)
                .HasForeignKey<DocumentChunkHeaderContextEmbedding>(e => e.DocumentChunkId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(e => e.DocumentChunkId).IsUnique();
        });

        // Configure DocumentChunkNotesEmbedding entity
        modelBuilder.Entity<DocumentChunkNotesEmbedding>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.DocumentChunkId).IsRequired();
            entity.Property(e => e.Embedding)
                .HasColumnType("VARBINARY(MAX)")
                .IsRequired();
            entity.Property(e => e.CreatedAt).IsRequired();
            entity.Property(e => e.UpdatedAt).IsRequired();

            // Configure relationship with cascade delete
            entity.HasOne(e => e.DocumentChunk)
                .WithOne(dc => dc.NotesEmbedding)
                .HasForeignKey<DocumentChunkNotesEmbedding>(e => e.DocumentChunkId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(e => e.DocumentChunkId).IsUnique();
        });

        // Configure DocumentChunkDetailsEmbedding entity
        modelBuilder.Entity<DocumentChunkDetailsEmbedding>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.DocumentChunkId).IsRequired();
            entity.Property(e => e.Embedding)
                .HasColumnType("VARBINARY(MAX)")
                .IsRequired();
            entity.Property(e => e.CreatedAt).IsRequired();
            entity.Property(e => e.UpdatedAt).IsRequired();

            // Configure relationship with cascade delete
            entity.HasOne(e => e.DocumentChunk)
                .WithOne(dc => dc.DetailsEmbedding)
                .HasForeignKey<DocumentChunkDetailsEmbedding>(e => e.DocumentChunkId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(e => e.DocumentChunkId).IsUnique();
        });

        // Configure SemanticCache entity
        modelBuilder.Entity<SemanticCache>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.SearchQuery).IsRequired().HasMaxLength(1000);
            entity.Property(e => e.ResultContent).IsRequired();
            entity.Property(e => e.ResultEmbedding)
                .HasColumnType("VARBINARY(MAX)")
                .IsRequired();
            entity.Property(e => e.CreatedAt).IsRequired();

            // Configure indexes for better performance
            entity.HasIndex(e => e.SearchQuery);
            entity.HasIndex(e => e.CreatedAt);
        });
    }
}