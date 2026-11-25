using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace eBiblioteka.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class LinkAllTablesAndLongerNotifications : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "UserId",
                table: "RevokedTokens",
                type: "int",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AlterColumn<string>(
                name: "Text",
                table: "Notifications",
                type: "nvarchar(1000)",
                maxLength: 1000,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(500)",
                oldMaxLength: 500);

            migrationBuilder.AddColumn<int>(
                name: "CreatedByUserId",
                table: "News",
                type: "int",
                nullable: false,
                defaultValue: 0);

            // Postojeći zapisi u već kreiranoj bazi: obavijestima se dodjeljuje bibliotekar (prvi korisnik
            // administratorske uloge), a stari poništeni tokeni se brišu jer im vlasnik nije poznat.
            migrationBuilder.Sql(
                "UPDATE News SET CreatedByUserId = (SELECT MIN(ur.UserId) FROM AspNetUserRoles ur " +
                "JOIN AspNetRoles r ON r.Id = ur.RoleId WHERE r.Name = 'Administrator');");
            migrationBuilder.Sql("DELETE FROM RevokedTokens;");

            migrationBuilder.CreateIndex(
                name: "IX_RevokedTokens_UserId",
                table: "RevokedTokens",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_News_CreatedByUserId",
                table: "News",
                column: "CreatedByUserId");

            migrationBuilder.AddForeignKey(
                name: "FK_News_AspNetUsers_CreatedByUserId",
                table: "News",
                column: "CreatedByUserId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_RevokedTokens_AspNetUsers_UserId",
                table: "RevokedTokens",
                column: "UserId",
                principalTable: "AspNetUsers",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_News_AspNetUsers_CreatedByUserId",
                table: "News");

            migrationBuilder.DropForeignKey(
                name: "FK_RevokedTokens_AspNetUsers_UserId",
                table: "RevokedTokens");

            migrationBuilder.DropIndex(
                name: "IX_RevokedTokens_UserId",
                table: "RevokedTokens");

            migrationBuilder.DropIndex(
                name: "IX_News_CreatedByUserId",
                table: "News");

            migrationBuilder.DropColumn(
                name: "UserId",
                table: "RevokedTokens");

            migrationBuilder.DropColumn(
                name: "CreatedByUserId",
                table: "News");

            migrationBuilder.AlterColumn<string>(
                name: "Text",
                table: "Notifications",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: false,
                oldClrType: typeof(string),
                oldType: "nvarchar(1000)",
                oldMaxLength: 1000);
        }
    }
}
