using eBiblioteka.Api.Data;
using Microsoft.EntityFrameworkCore;

DotNetEnv.Env.TraversePath().Load();

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddOpenApi();

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(BuildConnectionString()));

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

app.Run();

static string BuildConnectionString()
{
    var host = Required("DB_HOST");
    var port = Required("DB_PORT");
    var name = Required("DB_NAME");
    var user = Required("DB_USER");
    var password = Required("DB_PASSWORD");

    return $"Server={host},{port};Database={name};User Id={user};Password={password};TrustServerCertificate=True";
}

static string Required(string key) =>
    Environment.GetEnvironmentVariable(key)
    ?? throw new InvalidOperationException($"Nedostaje varijabla okruženja: {key}");