using eBiblioteka.Api.Dtos;
using eBiblioteka.Api.Exceptions;

namespace eBiblioteka.Api.Middleware;

public class ExceptionHandlingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<ExceptionHandlingMiddleware> _logger;

    public ExceptionHandlingMiddleware(RequestDelegate next, ILogger<ExceptionHandlingMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await _next(context);
        }
        catch (Exception ex)
        {
            await HandleExceptionAsync(context, ex);
        }
    }

    private async Task HandleExceptionAsync(HttpContext context, Exception ex)
    {
        var (status, message) = ex switch
        {
            UnauthorizedException => (StatusCodes.Status401Unauthorized, ex.Message),
            ForbiddenException => (StatusCodes.Status403Forbidden, ex.Message),
            _ => (StatusCodes.Status500InternalServerError, "Došlo je do greške na serveru.")
        };

        if (status == StatusCodes.Status500InternalServerError)
        {
            _logger.LogError(ex, "Neobrađena greška pri obradi zahtjeva {Method} {Path}",
                context.Request.Method, context.Request.Path);
        }

        context.Response.StatusCode = status;
        await context.Response.WriteAsJsonAsync(new ErrorResponseDto
        {
            Status = status,
            Message = message
        });
    }
}
