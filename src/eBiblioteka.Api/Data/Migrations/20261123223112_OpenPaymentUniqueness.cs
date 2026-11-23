using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace eBiblioteka.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class OpenPaymentUniqueness : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Payments_FineId",
                table: "Payments");

            migrationBuilder.CreateIndex(
                name: "IX_Payments_FineId",
                table: "Payments",
                column: "FineId",
                unique: true,
                filter: "[Status] IN (1, 2)");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Payments_FineId",
                table: "Payments");

            migrationBuilder.CreateIndex(
                name: "IX_Payments_FineId",
                table: "Payments",
                column: "FineId");
        }
    }
}
