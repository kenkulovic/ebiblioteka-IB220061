using eBiblioteka.Api.Data;
using eBiblioteka.Api.Data.Entities;
using eBiblioteka.Api.BackgroundJobs;
using eBiblioteka.Api.Middleware;
using System.Text.Json.Serialization;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using System.Text;
using eBiblioteka.Api.Services;
using eBiblioteka.Api.Services.Email;
using eBiblioteka.Api.Services.PayPal;
using eBiblioteka.Api.Services.Recommender;
using eBiblioteka.Shared.Messaging;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
// NoClobber: prave varijable okruženja (npr. iz Dockera) imaju prednost nad .env fajlom.
DotNetEnv.Env.NoClobber().TraversePath().Load();

const string CorsPolicy = "Clients";

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers()
    .AddJsonOptions(options =>
        options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter()));
builder.Services.AddOpenApi();

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(BuildConnectionString()));

builder.Services
    .AddIdentityCore<ApplicationUser>(options =>
    {
        options.Password.RequiredLength = 4;
        options.Password.RequireDigit = false;
        options.Password.RequireLowercase = false;
        options.Password.RequireUppercase = false;
        options.Password.RequireNonAlphanumeric = false;
        options.User.RequireUniqueEmail = true;

        // Reset lozinke koristi kratak numerički kod (lako se prepisuje iz e-maila u aplikaciju).
        options.Tokens.PasswordResetTokenProvider = TokenOptions.DefaultEmailProvider;
    })
    .AddRoles<IdentityRole<int>>()
    .AddEntityFrameworkStores<AppDbContext>()
    .AddDefaultTokenProviders();

builder.Services.AddScoped<IJwtService, JwtService>();
builder.Services.AddScoped<ITokenRevocationService, TokenRevocationService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<ICountryService, CountryService>();
builder.Services.AddScoped<ICityService, CityService>();
builder.Services.AddScoped<ICategoryService, CategoryService>();
builder.Services.AddScoped<IPublisherService, PublisherService>();
builder.Services.AddScoped<IAuthorService, AuthorService>();
builder.Services.AddScoped<IBookService, BookService>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddScoped<IMemberEligibilityService, MemberEligibilityService>();
builder.Services.AddScoped<IReservationService, ReservationService>();
builder.Services.AddScoped<ILoanService, LoanService>();
builder.Services.AddScoped<IFineService, FineService>();
builder.Services.AddSingleton(RabbitMqSettings.FromEnvironment());
builder.Services.AddSingleton<IEmailQueue, RabbitMqEmailQueue>();
builder.Services.AddSingleton(PayPalOptions.FromEnvironment());
builder.Services.AddHttpClient<IPayPalClient, PayPalClient>(client =>
    client.Timeout = TimeSpan.FromSeconds(30));
builder.Services.AddScoped<IPaymentService, PaymentService>();
builder.Services.AddScoped<IReviewService, ReviewService>();
builder.Services.AddScoped<IMemberService, MemberService>();
builder.Services.AddScoped<IRecommendationService, RecommendationService>();
builder.Services.AddScoped<INewsService, NewsService>();
builder.Services.AddScoped<IReportService, ReportService>();
builder.Services.AddSingleton<RecalculationTrigger>();
builder.Services.AddSingleton<IRecalculationTrigger>(sp => sp.GetRequiredService<RecalculationTrigger>());
builder.Services.AddHostedService<ReservationExpirationJob>();
builder.Services.AddHostedService<LoanReminderJob>();
builder.Services.AddHostedService<SimilarityRecalculationJob>();

builder.Services
    .AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidIssuer = Required("JWT_ISSUER"),
            ValidateAudience = true,
            ValidAudience = Required("JWT_AUDIENCE"),
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(Required("JWT_KEY"))),
            ValidateLifetime = true,
            ClockSkew = TimeSpan.Zero
        };

        // Pored potpisa i roka, provjerava se da token nije poništen odjavom.
        options.Events = new JwtBearerEvents
        {
            OnTokenValidated = async context =>
            {
                var revocation = context.HttpContext.RequestServices.GetRequiredService<ITokenRevocationService>();

                if (!await revocation.IsTokenValidAsync(context.SecurityToken.Id))
                {
                    context.Fail("Token je poništen odjavom.");
                }
            }
        };
    });

builder.Services.AddAuthorization();

// CORS se definiše jednom, s izričito navedenim dozvoljenim originima (iz .env).
var corsOrigins = Required("CORS_ORIGINS").Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
builder.Services.AddCors(options => options.AddPolicy(CorsPolicy, policy =>
    policy.WithOrigins(corsOrigins).AllowAnyHeader().AllowAnyMethod()));

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    await DbSeeder.SeedAsync(scope.ServiceProvider);
}

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseMiddleware<ExceptionHandlingMiddleware>();
app.UseHttpsRedirection();
app.UseCors(CorsPolicy);
app.UseAuthentication();
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