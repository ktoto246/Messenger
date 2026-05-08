using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using System.Text;
using Microsoft.EntityFrameworkCore;
using WebApplication1.Data;
using WebApplication1.Hubs;
using System.Security.Claims;
using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;
using WebApplication1.Services;
using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

// 🔔 Инициализация Firebase Admin SDK
var firebaseSettings = builder.Configuration.GetSection("Firebase");
var firebaseKeyPath = Path.Combine(builder.Environment.ContentRootPath, firebaseSettings["KeyPath"] ?? "firebase-key.json");
if (File.Exists(firebaseKeyPath))
{
    FirebaseApp.Create(new AppOptions()
    {
        Credential = GoogleCredential.FromFile(firebaseKeyPath)
    });
}

builder.Services.AddSingleton<PushNotificationService>();
builder.Services.AddSingleton<FileService>();
builder.Services.AddSingleton<IAIService, AIServiceStub>();
builder.Services.AddSingleton<IUserIdProvider, UserIdProvider>();
builder.Services.AddHostedService<ScheduledMessageWorker>();
builder.Services.AddHostedService<OnlineStatusWorker>();

// --- Rate Limiting ---
builder.Services.AddRateLimiter(options =>
{
    options.AddFixedWindowLimiter("login", opt =>
    {
        opt.Window = TimeSpan.FromMinutes(1);
        opt.PermitLimit = 5;
        opt.QueueLimit = 0;
    });
    // 🛡️ Ограничение на регистрацию
    options.AddFixedWindowLimiter("register", opt =>
    {
        opt.Window = TimeSpan.FromHours(1);
        opt.PermitLimit = 3; // Максимум 3 регистрации в час с одного IP
        opt.QueueLimit = 0;
    });
});

// --- JWT Authentication ---
var jwtSettings = builder.Configuration.GetSection("Jwt");
var key = Encoding.ASCII.GetBytes(jwtSettings["Key"]!);

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true,
        ValidateAudience = true,
        ValidateLifetime = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer = jwtSettings["Issuer"],
        ValidAudience = jwtSettings["Audience"],
        IssuerSigningKey = new SymmetricSecurityKey(key)
    };

    // Support for SignalR JWT
    options.Events = new JwtBearerEvents
    {
        OnMessageReceived = context =>
        {
            var accessToken = context.Request.Query["access_token"];
            var path = context.HttpContext.Request.Path;
            if (!string.IsNullOrEmpty(accessToken) && 
                (path.StartsWithSegments("/chatHub") || path.StartsWithSegments("/callHub")))
            {
                context.Token = accessToken;
            }
            return Task.CompletedTask;
        }
    };
});

// --- CORS ---
builder.Services.AddCors(options =>
{
    options.AddPolicy("FlutterDevPolicy", policy =>
    {
        // 🛡️ Для разработки разрешаем любые источники, чтобы Flutter Web/Desktop могли подключаться
        policy.SetIsOriginAllowed(origin => true) 
              .AllowAnyHeader()
              .AllowAnyMethod()
              .AllowCredentials();           
    });
});

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "Messenger API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "JWT Authorization header using the Bearer scheme. Example: \"Authorization: Bearer {token}\"",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" }
            },
            new string[] { }
        }
    });
});
builder.Services.AddSignalR();

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors("FlutterDevPolicy");

app.UseHttpsRedirection();
app.UseAuthentication();
app.UseRateLimiter();
app.UseAuthorization();
app.UseStaticFiles();

app.MapControllers();
app.MapHub<ChatHub>("/chatHub");
app.MapHub<CallHub>("/callHub");

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    // 👈 ФИКС: Теперь применяем нормальные миграции вместо тупого создания
    db.Database.Migrate(); 
}

app.Run();