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

            // Configure the embedding as VARBINARY for SQL Server
            entity.Property(e => e.Embedding)
                .HasColumnType("VARBINARY(MAX)")
                .IsRequired(false);

            // Configure relationship with cascade delete
            entity.HasOne(e => e.Document)
                .WithMany(d => d.Chunks)
                .HasForeignKey(e => e.DocumentId)
                .OnDelete(DeleteBehavior.Cascade);

            // Configure indexes for better performance
            entity.HasIndex(e => e.DocumentId);
            entity.HasIndex(e => new { e.DocumentId, e.ChunkIndex }).IsUnique();
        });
    }
}