using eBiblioteka.Shared.Messaging;
using eBiblioteka.Worker;

// NoClobber: prave varijable okruženja (npr. iz Dockera) imaju prednost nad .env fajlom.
DotNetEnv.Env.NoClobber().TraversePath().Load();

var builder = Host.CreateApplicationBuilder(args);

builder.Services.AddSingleton(RabbitMqSettings.FromEnvironment());
builder.Services.AddSingleton(SmtpSettings.FromEnvironment());
builder.Services.AddSingleton<IEmailSender, SmtpEmailSender>();
builder.Services.AddHostedService<EmailConsumer>();

var host = builder.Build();
host.Run();
