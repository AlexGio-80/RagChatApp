using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace RagChatApp_Server.Migrations
{
    /// <inheritdoc />
    public partial class AddMultiProviderSupport : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "Notes",
                table: "Documents",
                type: "nvarchar(max)",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "UploadedBy",
                table: "Documents",
                type: "nvarchar(255)",
                maxLength: 255,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Model",
                table: "DocumentChunkNotesEmbeddings",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Model",
                table: "DocumentChunkHeaderContextEmbeddings",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Model",
                table: "DocumentChunkDetailsEmbeddings",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Model",
                table: "DocumentChunkContentEmbeddings",
                type: "nvarchar(100)",
                maxLength: 100,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "Notes",
                table: "Documents");

            migrationBuilder.DropColumn(
                name: "UploadedBy",
                table: "Documents");

            migrationBuilder.DropColumn(
                name: "Model",
                table: "DocumentChunkNotesEmbeddings");

            migrationBuilder.DropColumn(
                name: "Model",
                table: "DocumentChunkHeaderContextEmbeddings");

            migrationBuilder.DropColumn(
                name: "Model",
                table: "DocumentChunkDetailsEmbeddings");

            migrationBuilder.DropColumn(
                name: "Model",
                table: "DocumentChunkContentEmbeddings");
        }
    }
}
