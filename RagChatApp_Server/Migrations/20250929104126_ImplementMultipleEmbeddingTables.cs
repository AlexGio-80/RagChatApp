using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RagChatApp_Server.Migrations
{
    /// <inheritdoc />
    public partial class ImplementMultipleEmbeddingTables : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Embedding",
                table: "DocumentChunks");

            migrationBuilder.AddColumn<string>(
                name: "Path",
                table: "Documents",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Details",
                table: "DocumentChunks",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Notes",
                table: "DocumentChunks",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "UpdatedAt",
                table: "DocumentChunks",
                type: "datetime2",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.CreateTable(
                name: "DocumentChunkContentEmbeddings",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    DocumentChunkId = table.Column<int>(type: "int", nullable: false),
                    Embedding = table.Column<byte[]>(type: "VARBINARY(MAX)", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DocumentChunkContentEmbeddings", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DocumentChunkContentEmbeddings_DocumentChunks_DocumentChunkId",
                        column: x => x.DocumentChunkId,
                        principalTable: "DocumentChunks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "DocumentChunkDetailsEmbeddings",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    DocumentChunkId = table.Column<int>(type: "int", nullable: false),
                    Embedding = table.Column<byte[]>(type: "VARBINARY(MAX)", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DocumentChunkDetailsEmbeddings", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DocumentChunkDetailsEmbeddings_DocumentChunks_DocumentChunkId",
                        column: x => x.DocumentChunkId,
                        principalTable: "DocumentChunks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "DocumentChunkHeaderContextEmbeddings",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    DocumentChunkId = table.Column<int>(type: "int", nullable: false),
                    Embedding = table.Column<byte[]>(type: "VARBINARY(MAX)", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DocumentChunkHeaderContextEmbeddings", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DocumentChunkHeaderContextEmbeddings_DocumentChunks_DocumentChunkId",
                        column: x => x.DocumentChunkId,
                        principalTable: "DocumentChunks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "DocumentChunkNotesEmbeddings",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    DocumentChunkId = table.Column<int>(type: "int", nullable: false),
                    Embedding = table.Column<byte[]>(type: "VARBINARY(MAX)", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_DocumentChunkNotesEmbeddings", x => x.Id);
                    table.ForeignKey(
                        name: "FK_DocumentChunkNotesEmbeddings_DocumentChunks_DocumentChunkId",
                        column: x => x.DocumentChunkId,
                        principalTable: "DocumentChunks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "SemanticCache",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    SearchQuery = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: false),
                    ResultContent = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    ResultEmbedding = table.Column<byte[]>(type: "VARBINARY(MAX)", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SemanticCache", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_DocumentChunkContentEmbeddings_DocumentChunkId",
                table: "DocumentChunkContentEmbeddings",
                column: "DocumentChunkId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DocumentChunkDetailsEmbeddings_DocumentChunkId",
                table: "DocumentChunkDetailsEmbeddings",
                column: "DocumentChunkId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DocumentChunkHeaderContextEmbeddings_DocumentChunkId",
                table: "DocumentChunkHeaderContextEmbeddings",
                column: "DocumentChunkId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_DocumentChunkNotesEmbeddings_DocumentChunkId",
                table: "DocumentChunkNotesEmbeddings",
                column: "DocumentChunkId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_SemanticCache_CreatedAt",
                table: "SemanticCache",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_SemanticCache_SearchQuery",
                table: "SemanticCache",
                column: "SearchQuery");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "DocumentChunkContentEmbeddings");

            migrationBuilder.DropTable(
                name: "DocumentChunkDetailsEmbeddings");

            migrationBuilder.DropTable(
                name: "DocumentChunkHeaderContextEmbeddings");

            migrationBuilder.DropTable(
                name: "DocumentChunkNotesEmbeddings");

            migrationBuilder.DropTable(
                name: "SemanticCache");

            migrationBuilder.DropColumn(
                name: "Path",
                table: "Documents");

            migrationBuilder.DropColumn(
                name: "Details",
                table: "DocumentChunks");

            migrationBuilder.DropColumn(
                name: "Notes",
                table: "DocumentChunks");

            migrationBuilder.DropColumn(
                name: "UpdatedAt",
                table: "DocumentChunks");

            migrationBuilder.AddColumn<byte[]>(
                name: "Embedding",
                table: "DocumentChunks",
                type: "VARBINARY(MAX)",
                nullable: true);
        }
    }
}
